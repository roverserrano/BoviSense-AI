/*
  BoviSense-AI - ESP32 BLE <-> LoRa bridge

  Rol del ESP32:
  - Anunciarse por BLE como "BoviSense-Bridge".
  - Recibir comandos de la app movil por una characteristic RX.
  - Reenviar esos comandos por LoRa 433 MHz.
  - Escuchar respuestas o eventos LoRa y notificarlos a la app por BLE TX.

  Protocolo autenticado C1/R1. BLE usa ~<trama>\n y LoRa la trama completa.
  La clave solo reside en el backend y Jetson, nunca en este puente.
*/

#if !defined(ARDUINO_ARCH_ESP32)
#error "Este sketch usa BLE nativo de ESP32. En Arduino IDE selecciona una placa ESP32, por ejemplo 'ESP32 Dev Module' o 'DOIT ESP32 DEVKIT V1'."
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
#include "soc/rtc_cntl_reg.h"
#include "soc/soc.h"

static const char *BLE_DEVICE_NAME = "BoviSense-Bridge";
static const char *BLE_SERVICE_UUID = "7d2f0001-1f3b-4a9b-8f2a-b05e00000001";
static const char *BLE_RX_CHAR_UUID = "7d2f0002-1f3b-4a9b-8f2a-b05e00000001";
static const char *BLE_TX_CHAR_UUID = "7d2f0003-1f3b-4a9b-8f2a-b05e00000001";

static const int LORA_SS_PIN = 5;
static const int LORA_RST_PIN = 14;
static const int LORA_DIO0_PIN = 4;
static const long LORA_FREQUENCY_HZ = 433E6;
static const byte LORA_SYNC_WORD = 0xF3;
static const int LORA_SPREADING_FACTOR = 7;
static const long LORA_SIGNAL_BANDWIDTH_HZ = 125E3;
static const int LORA_CODING_RATE_DENOMINATOR = 5;

static const size_t MAX_BLE_COMMAND_LENGTH = 180;
static const size_t MAX_LORA_PAYLOAD_LENGTH = 220;
static const uint32_t LORA_RESPONSE_TIMEOUT_MS = 22000;
static const uint32_t BLE_ADVERTISING_CHECK_INTERVAL_MS = 15000;
static const uint16_t BLE_ADV_MIN_INTERVAL = 0x20;  // 20 ms
static const uint16_t BLE_ADV_MAX_INTERVAL = 0x40;  // 40 ms
static const uint32_t LORA_INIT_DELAY_MS = 8000;
static const uint32_t LORA_INIT_RETRY_MS = 15000;
static const uint32_t BOOT_STABILIZE_MS = 1500;
static const uint32_t CPU_FREQUENCY_MHZ = 80;
static const esp_power_level_t BLE_TX_POWER_LEVEL = ESP_PWR_LVL_N12;
static const bool DISABLE_BROWNOUT_DETECTOR = true;
static const char *LORA_TEST_PREFIX = "TEST";

BLEServer *bleServer = nullptr;
BLECharacteristic *txCharacteristic = nullptr;

bool bleClientConnected = false;
bool loraReady = false;
bool waitingForResponse = false;
bool bleAdvertisingStarted = false;
bool loraHeldInReset = false;

uint32_t nextMsgId = 1;
String pendingMsgId;
uint32_t pendingSentAt = 0;
uint32_t txCounter = 0;
uint32_t rxCounter = 0;
uint32_t testCounter = 1;
int lastRxRssi = 0;
float lastRxSnr = 0.0;

struct CommandFrame { char text[181]; };
QueueHandle_t commandQueue = nullptr;
uint32_t lastBleAdvertisingCheck = 0;
uint32_t nextLoRaInitAttemptAt = 0;

void startBleAdvertising();
void trySetupLoRaIfDue();
void holdLoRaInReset();
void releaseLoRaReset();
void stabilizePowerBeforeRadios();
bool validRequestId(const String &id);

String valueAfterPrefix(const String &value, const String &prefix) {
  if (!value.startsWith(prefix)) {
    return "";
  }

  String content = value.substring(prefix.length());
  content.trim();
  return content;
}

String protocolField(const String &payload, int fieldIndex) {
  int start = 0;

  for (int i = 0; i < fieldIndex; i++) {
    start = payload.indexOf('|', start);
    if (start < 0) {
      return "";
    }
    start++;
  }

  int end = payload.indexOf('|', start);
  if (end < 0) {
    end = payload.length();
  }

  return payload.substring(start, end);
}

String protocolRemainder(const String &payload, int firstFieldIndex) {
  int start = 0;

  for (int i = 0; i < firstFieldIndex; i++) {
    start = payload.indexOf('|', start);
    if (start < 0) {
      return "";
    }
    start++;
  }

  return payload.substring(start);
}

void notifyApp(const String &message) {
  if (!bleClientConnected || txCharacteristic == nullptr ||
      !(message.startsWith("R1|") || message.startsWith("B0|"))) return;
  const String framed = String("~") + message + "\n";
  for (size_t offset = 0; offset < framed.length(); offset += 18) {
    const String chunk = framed.substring(offset, offset + 18);
    txCharacteristic->setValue(chunk.c_str());
    txCharacteristic->notify();
    delay(15);
  }
}

String cleanBridgeReason(const String &reason) {
  String safe;
  safe.reserve(reason.length());
  for (size_t i = 0; i < reason.length() && safe.length() < 48; i++) {
    const char value = reason.charAt(i);
    if ((value >= 'a' && value <= 'z') || (value >= 'A' && value <= 'Z') ||
        (value >= '0' && value <= '9') || value == '_' || value == '-') {
      safe += value;
    } else {
      safe += '_';
    }
  }
  return safe.length() > 0 ? safe : "bridge_error";
}

void notifyBridgeError(const String &requestId, const String &reason) {
  if (!validRequestId(requestId)) return;
  notifyApp(String("B0|") + requestId + "|ERROR|" + cleanBridgeReason(reason));
}

bool isSafeTextPayload(const String &payload) {
  for (size_t i = 0; i < payload.length(); i++) {
    const char value = payload.charAt(i);
    if (value < 32 || value > 126) {
      return false;
    }
  }
  return true;
}

bool sendLoRaMessage(const String &payload) {
  const String requestId = protocolField(payload, 1);
  if (!loraReady) {
    Serial.println(F("[LoRa] ERROR: modulo no iniciado"));
    notifyBridgeError(requestId, F("lora_not_ready"));
    return false;
  }

  if (payload.length() == 0) {
    Serial.println(F("[LoRa] ERROR: payload vacio"));
    notifyBridgeError(requestId, F("empty_lora_payload"));
    return false;
  }

  if (payload.length() > MAX_LORA_PAYLOAD_LENGTH) {
    Serial.println(F("[LoRa] ERROR: payload demasiado largo"));
    notifyBridgeError(requestId, F("lora_payload_too_long"));
    return false;
  }

  LoRa.idle();
  LoRa.beginPacket();
  LoRa.print(payload);
  const int result = LoRa.endPacket();
  LoRa.receive();

  if (result == 0) {
    Serial.println(F("[LoRa] ERROR: fallo al finalizar paquete"));
    notifyBridgeError(requestId, F("lora_send_failed"));
    return false;
  }

  txCounter++;
  Serial.print(F("[LoRa] Enviado: "));
  Serial.println(F("[authenticated frame]"));
  return true;
}

String buildTestPayload(const String &content) {
  String payload = LORA_TEST_PREFIX;
  payload += F("|");
  payload += String(testCounter++);
  payload += F("|uptime=");
  payload += String(millis());
  payload += F("|msg=");
  payload += content;
  return payload;
}

String buildStatusPayload(uint32_t msgId) {
  String payload = F("ESTADO|");
  payload += String(msgId);
  payload += F("|uptime=");
  payload += String(millis());
  payload += F("|tx=");
  payload += String(txCounter);
  payload += F("|rx=");
  payload += String(rxCounter);
  payload += F("|lora=");
  payload += loraReady ? F("OK") : F("NO_INICIADO");
  return payload;
}

bool validRequestId(const String &id) {
  if (id.length() != 32) return false;
  for (size_t i = 0; i < id.length(); ++i)
    if (!((id[i] >= '0' && id[i] <= '9') || (id[i] >= 'a' && id[i] <= 'f'))) return false;
  return true;
}

void handleBleCommand(const String &command) {
  if (command.length() > MAX_BLE_COMMAND_LENGTH || !command.startsWith("C1|") ||
      !isSafeTextPayload(command)) return;
  const String requestId = protocolField(command, 1);
  if (!validRequestId(requestId)) return;
  if (waitingForResponse && millis() - pendingSentAt < LORA_RESPONSE_TIMEOUT_MS) {
    notifyBridgeError(requestId, F("bridge_busy_waiting_lora"));
    return;
  }
  if (!loraReady) {
    trySetupLoRaIfDue();
  }
  if (!sendLoRaMessage(command)) return;
  pendingMsgId = requestId;
  pendingSentAt = millis();
  waitingForResponse = true;
}

void handleLoRaPayload(const String &payload) {
  if (!waitingForResponse) {
    Serial.println(F("[LoRa RX] descartado: no hay solicitud pendiente"));
    return;
  }
  if (!payload.startsWith("R1|") || payload.length() > 200 || !isSafeTextPayload(payload)) {
    Serial.println(F("[LoRa RX] descartado: formato R1 invalido"));
    return;
  }
  if (protocolField(payload, 1) != pendingMsgId) {
    Serial.println(F("[LoRa RX] descartado: id distinto de la solicitud pendiente"));
    return;
  }
  rxCounter++;
  lastRxRssi = LoRa.packetRssi();
  lastRxSnr = LoRa.packetSnr();
  Serial.print(F("[LoRa RX] R1 aceptado, RSSI="));
  Serial.print(lastRxRssi);
  Serial.print(F(" SNR="));
  Serial.println(lastRxSnr);
  notifyApp(payload);
  waitingForResponse = false;
}

void pollLoRa() {
  if (!loraReady) {
    return;
  }

  const int packetSize = LoRa.parsePacket();
  if (packetSize <= 0) {
    return;
  }

  String incoming;
  incoming.reserve(packetSize);
  while (LoRa.available()) {
    incoming += (char)LoRa.read();
  }
  incoming.trim();

  Serial.print(F("[LoRa RX] paquete len="));
  Serial.print(packetSize);
  Serial.print(F(" RSSI="));
  Serial.print(LoRa.packetRssi());
  Serial.print(F(" SNR="));
  Serial.println(LoRa.packetSnr());

  if (incoming.length() == 0) {
    Serial.println(F("[LoRa] Paquete vacio ignorado"));
    return;
  }

  handleLoRaPayload(incoming);
}

void checkLoRaTimeout() {
  if (!waitingForResponse) {
    return;
  }

  if (millis() - pendingSentAt < LORA_RESPONSE_TIMEOUT_MS) {
    return;
  }

  waitingForResponse = false;
  notifyBridgeError(pendingMsgId, F("jetson_response_timeout"));
  pendingMsgId = "";
  Serial.println(F("[Bridge] Timeout esperando respuesta autenticada"));
}

class BridgeServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) {
    bleClientConnected = true;
    bleAdvertisingStarted = false;
    Serial.println(F("[BLE] Cliente conectado"));
    notifyApp(F("STATUS:BLE conectado"));
  }

  void onDisconnect(BLEServer *server) {
    bleClientConnected = false;
    bleAdvertisingStarted = false;
    Serial.println(F("[BLE] Cliente desconectado"));
    startBleAdvertising();
  }
};

class BridgeRxCallbacks : public BLECharacteristicCallbacks {
  char buffer[181] = {};
  size_t length = 0;
  bool receiving = false;
  uint32_t lastByteAt = 0;
  void onWrite(BLECharacteristic *characteristic) {
    const auto value = characteristic->getValue();
    if (millis() - lastByteAt > 5000) { receiving = false; length = 0; }
    lastByteAt = millis();
    for (size_t i = 0; i < value.length(); ++i) {
      const char c = value[i];
      if (c == '~') { receiving = true; length = 0; }
      else if (receiving && c == '\n') {
        buffer[length] = 0;
        CommandFrame command = {};
        memcpy(command.text, buffer, length + 1);
        if (commandQueue != nullptr) xQueueSend(commandQueue, &command, 0);
        receiving = false; length = 0;
      } else if (receiving && c >= 32 && c <= 126 && length < 180) {
        buffer[length++] = c;
      } else { receiving = false; length = 0; }
    }
  }
};

void startBleAdvertising() {
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  const bool started = advertising->start();
  if (!started) {
    Serial.println(F("[BLE] ERROR: no se pudo iniciar advertising"));
    return;
  }
  bleAdvertisingStarted = true;

  Serial.print(F("[BLE] Advertising activo. Nombre: "));
  Serial.print(BLE_DEVICE_NAME);
  Serial.print(F(" | Service UUID: "));
  Serial.println(BLE_SERVICE_UUID);
}

void ensureBleAdvertising() {
  if (bleClientConnected || bleAdvertisingStarted) {
    return;
  }

  const uint32_t now = millis();
  if (now - lastBleAdvertisingCheck < BLE_ADVERTISING_CHECK_INTERVAL_MS) {
    return;
  }

  lastBleAdvertisingCheck = now;
  startBleAdvertising();
}

void setupBLE() {
  Serial.println(F("[BLE] Liberando memoria de Bluetooth clasico"));
  esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT);

  Serial.println(F("[BLE] BLEDevice::init..."));
  BLEDevice::init(BLE_DEVICE_NAME);
  Serial.println(F("[BLE] BLEDevice::init OK"));

  esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_DEFAULT, BLE_TX_POWER_LEVEL);
  esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_ADV, BLE_TX_POWER_LEVEL);

  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new BridgeServerCallbacks());

  BLEService *service = bleServer->createService(BLE_SERVICE_UUID);

  BLECharacteristic *rxCharacteristic = service->createCharacteristic(
    BLE_RX_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  rxCharacteristic->setCallbacks(new BridgeRxCallbacks());

  txCharacteristic = service->createCharacteristic(
    BLE_TX_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  txCharacteristic->addDescriptor(new BLE2902());
  txCharacteristic->setValue("STATUS:bridge listo");

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->reset();
  // Keep advertising config simple and robust: device name comes from BLEDevice::init().
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  advertising->setMinInterval(BLE_ADV_MIN_INTERVAL);
  advertising->setMaxInterval(BLE_ADV_MAX_INTERVAL);
  startBleAdvertising();

  Serial.print(F("[BLE] Servidor iniciado como "));
  Serial.println(BLE_DEVICE_NAME);
  Serial.print(F("[BLE] Service UUID: "));
  Serial.println(BLE_SERVICE_UUID);
  Serial.print(F("[BLE] RX UUID: "));
  Serial.println(BLE_RX_CHAR_UUID);
  Serial.print(F("[BLE] TX UUID: "));
  Serial.println(BLE_TX_CHAR_UUID);
  Serial.print(F("[BLE] TX power level: "));
  Serial.println((int)BLE_TX_POWER_LEVEL);
}

void setupLoRa() {
  releaseLoRaReset();
  LoRa.setPins(LORA_SS_PIN, LORA_RST_PIN, LORA_DIO0_PIN);

  if (!LoRa.begin(LORA_FREQUENCY_HZ)) {
    loraReady = false;
    Serial.println(F("[LoRa] ERROR: no se pudo inicializar LoRa SX1278"));
    notifyApp(F("ERROR:LoRa no iniciado"));
    return;
  }

  LoRa.setSpreadingFactor(LORA_SPREADING_FACTOR);
  LoRa.setSignalBandwidth(LORA_SIGNAL_BANDWIDTH_HZ);
  LoRa.setCodingRate4(LORA_CODING_RATE_DENOMINATOR);
  LoRa.setSyncWord(LORA_SYNC_WORD);
  LoRa.enableCrc();
  LoRa.receive();

  loraReady = true;
  Serial.println(F("[LoRa] SX1278 inicializado"));
  Serial.println(F("[LoRa] Frecuencia: 433 MHz"));
  Serial.println(F("[LoRa] Pines: SS=5 RST=14 DIO0=4"));
  Serial.println(F("[LoRa] Sync word: 0xF3"));
  Serial.println(F("[LoRa] SF=7 BW=125kHz CR=4/5 CRC=ON"));
  notifyApp(F("STATUS:LoRa iniciado"));
}

void holdLoRaInReset() {
  pinMode(LORA_RST_PIN, OUTPUT);
  digitalWrite(LORA_RST_PIN, LOW);
  loraHeldInReset = true;
  Serial.println(F("[LoRa] RST en LOW para reducir consumo durante arranque"));
}

void releaseLoRaReset() {
  if (!loraHeldInReset) {
    return;
  }

  digitalWrite(LORA_RST_PIN, HIGH);
  delay(20);
  loraHeldInReset = false;
  Serial.println(F("[LoRa] RST liberado (HIGH)"));
}

void stabilizePowerBeforeRadios() {
  setCpuFrequencyMhz(CPU_FREQUENCY_MHZ);
  Serial.print(F("[Boot] CPU MHz: "));
  Serial.println(getCpuFrequencyMhz());

  if (DISABLE_BROWNOUT_DETECTOR) {
    WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
    Serial.println(F("[Boot] Brownout detector desactivado por baja alimentacion"));
  }

  delay(BOOT_STABILIZE_MS);
}

void trySetupLoRaIfDue() {
  if (loraReady) {
    return;
  }

  const uint32_t now = millis();
  if (now < nextLoRaInitAttemptAt) {
    return;
  }

  Serial.println(F("[LoRa] Intentando inicializar modulo..."));
  setupLoRa();

  if (!loraReady) {
    nextLoRaInitAttemptAt = now + LORA_INIT_RETRY_MS;
    Serial.print(F("[LoRa] Reintento programado en ms: "));
    Serial.println(LORA_INIT_RETRY_MS);
  }
}

void setup() {
  Serial.begin(115200);
  Serial.setTimeout(80);
  delay(500);

  Serial.println();
  Serial.println(F("BoviSense ESP32 BLE <-> LoRa bridge"));

  holdLoRaInReset();
  stabilizePowerBeforeRadios();
  Serial.println(F("[Boot] Inicializando BLE..."));
  commandQueue = xQueueCreate(4, sizeof(CommandFrame));
  if (commandQueue == nullptr) { Serial.println(F("Command queue allocation failed")); return; }
  setupBLE();
  Serial.print(F("[Boot] LoRa diferido. Primer intento en ms: "));
  Serial.println(LORA_INIT_DELAY_MS);
  nextLoRaInitAttemptAt = millis() + LORA_INIT_DELAY_MS;
}

void loop() {
  CommandFrame command;
  if (commandQueue != nullptr && xQueueReceive(commandQueue, &command, 0) == pdTRUE) {
    handleBleCommand(String(command.text));
  }

  if (Serial.available()) {
    const String serialCommand = Serial.readStringUntil('\n');
    handleBleCommand(serialCommand);
  }

  pollLoRa();
  checkLoRaTimeout();
  ensureBleAdvertising();
  trySetupLoRaIfDue();
}
