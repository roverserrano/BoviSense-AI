/*
  BoviSense-AI: ESP32 BLE <-> SX1278 (C1/R1, sin claves en el puente).
  BLE: ~<trama>\n, fragmentos de 18 bytes. LoRa: trama completa sin modificar.
  Solo loop() usa SPI, envia notificaciones y administra la transaccion.
  Callbacks BLE entregan comandos acotados con la generacion de su conexion.
*/
#if !defined(ARDUINO_ARCH_ESP32)
#error "Selecciona ESP32 Dev Module / ESP32-WROOM-32 con BLE."
#endif
#include <SPI.h>
#include <LoRa.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <esp_bt.h>
#include <esp_gap_ble_api.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <atomic>
#include "bridge_protocol.h"

static const char *FIRMWARE_VERSION = "bovisense-c1r1-2.0";
static const char *BLE_DEVICE_NAME = "BoviSense-Bridge";
static const char *BLE_SERVICE_UUID = "7d2f0001-1f3b-4a9b-8f2a-b05e00000001";
static const char *BLE_RX_CHAR_UUID = "7d2f0002-1f3b-4a9b-8f2a-b05e00000001";
static const char *BLE_TX_CHAR_UUID = "7d2f0003-1f3b-4a9b-8f2a-b05e00000001";
static const int LORA_SS_PIN = 5;
static const int LORA_RST_PIN = 14;  // Solo RST terrestre, NO el de Jetson.
static const int LORA_DIO0_PIN = 4;
static const long LORA_FREQUENCY_HZ = 433000000;
static const byte LORA_SYNC_WORD = 0xF3;
static const int LORA_SPREADING_FACTOR = 7;
static const long LORA_SIGNAL_BANDWIDTH_HZ = 125000;
static const int LORA_CODING_RATE_DENOMINATOR = 5;
static const uint32_t LORA_INIT_DELAY_MS = 8000;
static const uint32_t LORA_INIT_RETRY_MS = 15000;
static const uint32_t BLE_ADVERTISING_CHECK_INTERVAL_MS = 1000;
static const uint16_t BLE_ADV_MIN_INTERVAL = 0x20;
static const uint16_t BLE_ADV_MAX_INTERVAL = 0x40;
static const uint32_t CPU_FREQUENCY_MHZ = 80;
static const esp_power_level_t BLE_TX_POWER_LEVEL = ESP_PWR_LVL_N12;
static const uint32_t LORA_SPI_HZ = 8000000;  // Mismo bus/settings de LoRa 0.8.0.
static const uint8_t REG_IRQ_FLAGS = 0x12;
static const uint8_t IRQ_TX_DONE = 0x08;

struct CommandFrame { uint32_t epoch; char text[bridge::COMMAND_LIMIT + 1]; };
struct BleMessage { uint32_t epoch; char text[bridge::RESPONSE_LIMIT + 1]; };
struct BridgeError { uint32_t epoch; char request[33]; };
BLEServer *bleServer = nullptr;
BLECharacteristic *txCharacteristic = nullptr;
BLE2902 *txSubscription = nullptr;
QueueHandle_t commandQueue = nullptr;
QueueHandle_t notificationQueue = nullptr;
QueueHandle_t errorQueue = nullptr;
std::atomic<bool> bleClientConnected{false};
std::atomic<uint32_t> connectionEpoch{0};
uint32_t loopEpoch = 0;
bool bootReady = false;
bool bleAdvertisingStarted = false;
bool loraReady = false;
bool transmitting = false;
uint32_t transmitStartedAt = 0;
uint32_t lastAdvertisingAttempt = 0;
uint32_t lastLoRaInitAttempt = 0;
uint32_t loRaInitDelay = LORA_INIT_DELAY_MS;
uint32_t txCounter = 0;
uint32_t rxCounter = 0;
bridge::Transaction pending;
char bleOutput[bridge::RESPONSE_LIMIT + 3] = {};
size_t bleOutputLength = 0;
size_t bleOutputOffset = 0;
uint32_t bleOutputEpoch = 0;
uint32_t bleOutputStartedAt = 0;
uint32_t lastNotificationAt = 0;

void startBleAdvertising();
void trySetupLoRaIfDue();

bool notifyApp(const char *message, uint32_t epoch) {
  if (!bleClientConnected.load() || connectionEpoch.load() != epoch ||
      strlen(message) > bridge::RESPONSE_LIMIT) return false;
  BleMessage item = {};
  item.epoch = epoch;
  strcpy(item.text, message);
  if (xQueueSend(notificationQueue, &item, 0) != pdTRUE) {
    Serial.println(F("[BLE] Cola de notificaciones llena; respuesta no confirmada"));
    return false;
  }
  return true;
}

void notifyBridgeError(const char *request, const char *reason, uint32_t epoch) {
  if (!bridge::hexId(request)) return;
  char message[bridge::RESPONSE_LIMIT + 1];
  snprintf(message, sizeof(message), "B0|%s|ERROR|%s", request, reason);
  notifyApp(message, epoch);  // B0 es diagnostico local, nunca prueba de conteo.
}

void pollBleNotifications() {
  const uint32_t epoch = connectionEpoch.load();
  if (!bleClientConnected.load()) return;
  if (bleOutputOffset >= bleOutputLength || bleOutputEpoch != epoch) {
    bleOutputLength = bleOutputOffset = 0;
    BleMessage item;
    while (xQueueReceive(notificationQueue, &item, 0) == pdTRUE) {
      if (item.epoch != epoch) continue;
      bleOutputLength = snprintf(bleOutput, sizeof(bleOutput), "~%s\n", item.text);
      bleOutputEpoch = epoch;
      bleOutputStartedAt = millis();
      break;
    }
  }
  if (bleOutputOffset >= bleOutputLength) return;
  if (bridge::elapsed(millis(), bleOutputStartedAt, bridge::ASSEMBLY_TIMEOUT_MS)) {
    bleOutputLength = bleOutputOffset = 0;
    return;
  }
  if (!txSubscription->getNotifications() || !bridge::elapsed(millis(), lastNotificationAt, 15)) return;
  const size_t remaining = bleOutputLength - bleOutputOffset;
  const size_t length = remaining < bridge::BLE_CHUNK ? remaining : bridge::BLE_CHUNK;
  txCharacteristic->setValue(reinterpret_cast<const uint8_t *>(bleOutput + bleOutputOffset), length);
  txCharacteristic->notify();
  bleOutputOffset += length;
  lastNotificationAt = millis();
}

void resetRadioAfterFailure() {
  transmitting = false;
  loraReady = false;
  LoRa.end();
  lastLoRaInitAttempt = millis();
  loRaInitDelay = LORA_INIT_RETRY_MS;
}

uint8_t radioRegister(uint8_t address, uint8_t value = 0, bool write = false) {
  // LoRa 0.8.0 no expone isTransmitting(). Consultar IRQ en loop evita
  // callbacks ISR que accederian al mismo SPI desde otro contexto.
  SPI.beginTransaction(SPISettings(LORA_SPI_HZ, MSBFIRST, SPI_MODE0));
  digitalWrite(LORA_SS_PIN, LOW);
  SPI.transfer(write ? (address | 0x80) : (address & 0x7f));
  const uint8_t result = SPI.transfer(value);
  digitalWrite(LORA_SS_PIN, HIGH);
  SPI.endTransaction();
  return result;
}

bool startLoRaTransmission() {
  // endPacket() sin async espera TxDone indefinidamente en LoRa 0.8.0.
  LoRa.idle();
  radioRegister(REG_IRQ_FLAGS, IRQ_TX_DONE, true);
  const size_t length = strlen(pending.command);
  if (LoRa.beginPacket() != 1 ||
      LoRa.write(reinterpret_cast<const uint8_t *>(pending.command), length) != length ||
      LoRa.endPacket(true) != 1) {
    notifyBridgeError(pending.ids.request, "lora_send_failed", pending.epoch);
    pending.reset();
    resetRadioAfterFailure();
    return false;
  }
  transmitStartedAt = millis();
  pending.sent(transmitStartedAt);
  transmitting = true;
  ++txCounter;
  Serial.printf("[LoRa TX] intento=%u id=%.8s total=%lu\n", pending.attempts, pending.ids.request, static_cast<unsigned long>(txCounter));
  return true;
}

void pollTransmission() {
  if (!transmitting) return;
  if (radioRegister(REG_IRQ_FLAGS) & IRQ_TX_DONE) {
    radioRegister(REG_IRQ_FLAGS, IRQ_TX_DONE, true);
    transmitting = false;
    LoRa.receive();
    // La finalizacion local NO demuestra recepcion/autenticacion en Jetson.
  } else if (bridge::elapsed(millis(), transmitStartedAt, bridge::TX_TIMEOUT_MS)) {
    notifyBridgeError(pending.ids.request, "lora_tx_timeout", pending.epoch);
    pending.reset();
    resetRadioAfterFailure();
    Serial.println(F("[LoRa] Timeout TX; radio se reinicializara"));
  }
}

void handleCommand(const CommandFrame &command) {
  if (command.epoch != connectionEpoch.load()) return;
  bridge::Envelope envelope;
  if (!bridge::commandEnvelope(command.text, envelope)) {
    Serial.println(F("[Bridge] C1 malformado descartado"));
    return;
  }
  if (pending.sameCommand(command.text)) return;  // Reintenta el temporizador, sin renovar el plazo.
  if (transmitting || (pending.active && !pending.received && !pending.expired(millis()))) {
    notifyBridgeError(envelope.request, "bridge_busy_waiting_lora", command.epoch);
    return;
  }
  if (!loraReady) {
    trySetupLoRaIfDue();
    if (!loraReady) {
      notifyBridgeError(envelope.request, "lora_not_ready", command.epoch);
      return;
    }
  }
  pending.start(command.text, envelope, millis(), command.epoch);
  startLoRaTransmission();
}

void pollLoRa() {
  if (!loraReady || transmitting) return;
  const int packetSize = LoRa.parsePacket();
  if (packetSize <= 0) return;
  char incoming[bridge::RESPONSE_LIMIT + 1] = {};
  size_t length = 0;
  bool validBytes = packetSize <= static_cast<int>(bridge::RESPONSE_LIMIT);
  while (LoRa.available()) {
    const int value = LoRa.read();
    if (value < 32 || value > 126) validBytes = false;
    if (length < bridge::RESPONSE_LIMIT) incoming[length++] = static_cast<char>(value);
  }
  const int rssi = LoRa.packetRssi();
  const float snr = LoRa.packetSnr();
  LoRa.receive();
  bridge::Envelope envelope;
  if (!validBytes || length != static_cast<size_t>(packetSize) ||
      !bridge::responseEnvelope(incoming, envelope) || !pending.matches(envelope) ||
      pending.epoch != connectionEpoch.load() || pending.expired(millis())) return;
  ++rxCounter;
  Serial.printf("[LoRa RX] R1 candidato id=%.8s RSSI=%d SNR=%.1f\n", envelope.request, rssi, snr);
  if (notifyApp(incoming, pending.epoch)) pending.received = true;
  // La segunda copia de Jetson puede reconstruir una notificacion incompleta.
  // Conservar correlacion hasta otro comando o el plazo; no es un ACK.
}

void servicePendingCommand() {
  if (!pending.active) return;
  if (pending.expired(millis())) {
    if (!pending.received) notifyBridgeError(pending.ids.request, "jetson_response_timeout", pending.epoch);
    pending.reset();
  } else if (!transmitting && loraReady && pending.retryDue(millis())) {
    startLoRaTransmission();  // Mismo C1, request-id, sesion, expiracion y HMAC.
  }
}

class BridgeServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *) override {
    connectionEpoch.fetch_add(1);
    bleClientConnected.store(true);
  }
  void onDisconnect(BLEServer *) override {
    bleClientConnected.store(false);
    connectionEpoch.fetch_add(1);
  }
};

class BridgeRxCallbacks : public BLECharacteristicCallbacks {
  bridge::LineAssembler<bridge::COMMAND_LIMIT> assembler;
  uint32_t epoch = 0;
  void onWrite(BLECharacteristic *characteristic) override {
    const uint32_t current = connectionEpoch.load();
    if (current != epoch) { assembler.reset(); epoch = current; }
    if (!bleClientConnected.load()) return;
    const auto value = characteristic->getValue();
    for (size_t i = 0; i < value.length(); ++i) {
      if (!assembler.feed(value[i], millis())) continue;
      bridge::Envelope envelope;
      if (!bridge::commandEnvelope(assembler.frame(), envelope)) continue;
      CommandFrame command = {};
      command.epoch = current;
      strcpy(command.text, assembler.frame());
      if (xQueueSend(commandQueue, &command, 0) != pdTRUE) {
        BridgeError error = {};
        error.epoch = current;
        strcpy(error.request, envelope.request);
        xQueueSend(errorQueue, &error, 0);
      }
    }
  }
};

void serviceConnectionChange() {
  const uint32_t current = connectionEpoch.load();
  if (current == loopEpoch) return;
  loopEpoch = current;
  pending.reset();
  bleOutputLength = bleOutputOffset = 0;
  // No xQueueReset: podria borrar un comando nuevo encolado simultaneamente.
  // Cada item lleva epoch y se descarta si ya es obsoleto.
  if (transmitting) {
    LoRa.idle();
    LoRa.receive();
    transmitting = false;
  }
  bleAdvertisingStarted = false;
  lastAdvertisingAttempt = millis() - BLE_ADVERTISING_CHECK_INTERVAL_MS;
  Serial.println(bleClientConnected.load() ? F("[BLE] Cliente conectado") : F("[BLE] Cliente desconectado; consultar estado al reconectar"));
}

void startBleAdvertising() {
  if (bleClientConnected.load()) return;
  bleAdvertisingStarted = BLEDevice::getAdvertising()->start();
  Serial.println(bleAdvertisingStarted ? F("[BLE] Advertising activo") : F("[BLE] Error iniciando advertising"));
}

void ensureBleAdvertising() {
  if (bleClientConnected.load() || bleAdvertisingStarted) return;
  if (!bridge::elapsed(millis(), lastAdvertisingAttempt, BLE_ADVERTISING_CHECK_INTERVAL_MS)) return;
  lastAdvertisingAttempt = millis();
  startBleAdvertising();
}

void setupBLE() {
  esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT);
  BLEDevice::init(BLE_DEVICE_NAME);
  esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_DEFAULT, BLE_TX_POWER_LEVEL);
  esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_ADV, BLE_TX_POWER_LEVEL);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new BridgeServerCallbacks());
  BLEService *service = bleServer->createService(BLE_SERVICE_UUID);
  BLECharacteristic *rx = service->createCharacteristic(
      BLE_RX_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  rx->setCallbacks(new BridgeRxCallbacks());
  txCharacteristic = service->createCharacteristic(
      BLE_TX_CHAR_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  txSubscription = new BLE2902();
  txCharacteristic->addDescriptor(txSubscription);
  txCharacteristic->setValue(FIRMWARE_VERSION);
  service->start();
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->reset();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  advertising->setMinInterval(BLE_ADV_MIN_INTERVAL);
  advertising->setMaxInterval(BLE_ADV_MAX_INTERVAL);
  startBleAdvertising();
}

void trySetupLoRaIfDue() {
  if (loraReady || !bridge::elapsed(millis(), lastLoRaInitAttempt, loRaInitDelay)) return;
  lastLoRaInitAttempt = millis();
  loRaInitDelay = LORA_INIT_RETRY_MS;
  digitalWrite(LORA_RST_PIN, HIGH);
  LoRa.setPins(LORA_SS_PIN, LORA_RST_PIN, LORA_DIO0_PIN);
  LoRa.setSPIFrequency(LORA_SPI_HZ);
  if (!LoRa.begin(LORA_FREQUENCY_HZ)) {
    Serial.println(F("[LoRa] SX1278 no disponible; reintento en 15 s"));
    return;
  }
  LoRa.setSpreadingFactor(LORA_SPREADING_FACTOR);
  LoRa.setSignalBandwidth(LORA_SIGNAL_BANDWIDTH_HZ);
  LoRa.setCodingRate4(LORA_CODING_RATE_DENOMINATOR);
  LoRa.setSyncWord(LORA_SYNC_WORD);
  LoRa.setTxPower(17);
  LoRa.enableCrc();
  LoRa.receive();
  loraReady = true;
  Serial.println(F("[LoRa] 433MHz SF=7 BW=125kHz CR=4/5 CRC=ON Sync=0xF3 TX=17dBm"));
  Serial.println(F("[LoRa] Pines: SS=5 RST=14 DIO0=4 (SPI predeterminado ESP32)"));
}

void pollSerial() {
  // Diagnostico local: C1 firmado, con o sin '~'. Nunca comandos de texto legado.
  static bridge::LineAssembler<bridge::COMMAND_LIMIT> assembler;
  static bool started = false;
  static uint32_t lastByte = 0;
  for (unsigned i = 0; i < 32 && Serial.available(); ++i) {
    const char value = static_cast<char>(Serial.read());
    if (bridge::elapsed(millis(), lastByte, bridge::ASSEMBLY_TIMEOUT_MS)) started = false;
    lastByte = millis();
    if (!started) { assembler.feed('~', millis()); started = true; }
    if (value == '\r') continue;
    if (assembler.feed(value, millis())) {
      CommandFrame command = {};
      command.epoch = connectionEpoch.load();
      strcpy(command.text, assembler.frame());
      handleCommand(command);
      started = false;
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(LORA_RST_PIN, OUTPUT);
  digitalWrite(LORA_RST_PIN, LOW);
  setCpuFrequencyMhz(CPU_FREQUENCY_MHZ);
  // Mantener brownout: una fuente inestable no se arregla ocultando la caida
  // de tension. BLE y LoRa siguen arrancando de forma escalonada.
  delay(1500);
  Serial.printf("\nBoviSense ESP32 %s\n", FIRMWARE_VERSION);
  commandQueue = xQueueCreate(4, sizeof(CommandFrame));
  notificationQueue = xQueueCreate(4, sizeof(BleMessage));
  errorQueue = xQueueCreate(4, sizeof(BridgeError));
  if (!commandQueue || !notificationQueue || !errorQueue) {
    Serial.println(F("[Boot] No hay memoria para colas; puente inactivo"));
    return;
  }
  setupBLE();
  lastLoRaInitAttempt = millis();
  bootReady = true;
}

void loop() {
  if (!bootReady) { delay(100); return; }
  serviceConnectionChange();
  pollTransmission();
  pollLoRa();
  servicePendingCommand();
  CommandFrame command;
  if (xQueueReceive(commandQueue, &command, 0) == pdTRUE) handleCommand(command);
  BridgeError error;
  if (xQueueReceive(errorQueue, &error, 0) == pdTRUE) notifyBridgeError(error.request, "bridge_queue_full", error.epoch);
  pollSerial();
  pollBleNotifications();
  ensureBleAdvertising();
  trySetupLoRaIfDue();
  delay(1);  // Cede CPU al stack BLE/FreeRTOS y al watchdog.
}
