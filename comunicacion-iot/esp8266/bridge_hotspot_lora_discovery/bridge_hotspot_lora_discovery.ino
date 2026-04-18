/*
  BoviSense-AI - ESP8266 Hotspot movil <-> LoRa bridge

  Rol del ESP8266:
  - Conectarse al hotspot del celular para conservar internet en la app movil.
  - Exponer endpoints HTTP JSON para que la app movil pruebe conexion.
  - Enviar informacion por LoRa desde la app o desde Serial.
  - Recibir informacion por LoRa y dejarla disponible para la app.

  Endpoints para la app:
  - GET /ping
  - GET /status
  - GET /send?msg=texto

  Nota sobre Arduino IDE:
  Los "SyntaxWarning" de elf2bin.py pertenecen al core ESP8266/Python, no a este
  sketch. Si el IDE muestra el resumen de memoria, el codigo si compilo.
*/

#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include <LoRa.h>

static const int LORA_CS_PIN = 15;   // NodeMCU D8 / GPIO15
static const int LORA_RST_PIN = 16;  // NodeMCU D0 / GPIO16
static const int LORA_DIO0_PIN = 2;  // NodeMCU D4 / GPIO2

static const long LORA_FREQUENCY_HZ = 433E6;
static const byte LOCAL_ADDRESS = 0xBB;   // ESP8266 puente Wi-Fi <-> LoRa
static const byte REMOTE_ADDRESS = 0xCC;  // Nodo remoto LoRa
static const byte BROADCAST_ADDRESS = 0xFF;

static const char *WIFI_SSID = "HONOR X8b";
static const char *WIFI_PASSWORD = "rover123";
static const uint32_t WIFI_CONNECT_TIMEOUT_MS = 20000;
static const uint32_t WIFI_RECONNECT_INTERVAL_MS = 10000;
static const uint16_t HTTP_PORT = 80;
static const uint16_t DISCOVERY_PORT = 4210;
static const char *DEVICE_ID = "esp_lora_01";
static const char *DISCOVERY_PREFIX = "ESP_DISCOVERY";
static const char *DISCOVERY_REQUEST = "ESP_DISCOVERY_REQUEST";
static const uint32_t DISCOVERY_INTERVAL_MS = 4000;

WiFiServer httpServer(HTTP_PORT);
WiFiUDP discoveryUdp;

String pendingLoraMessage;
String lastRxMessage;
String lastRxSender = "0x00";
int lastRxRssi = 0;
float lastRxSnr = 0.0;
bool hasPendingLoraMessage = false;
bool loraReady = false;
uint32_t txCounter = 0;
uint32_t rxCounter = 0;
uint32_t lastWifiReconnectAttempt = 0;
uint32_t lastDiscoveryBroadcast = 0;

String jsonEscape(const String &value) {
  String escaped;
  escaped.reserve(value.length() + 8);
  for (size_t i = 0; i < value.length(); i++) {
    const char c = value.charAt(i);
    switch (c) {
      case '\\':
        escaped += F("\\\\");
        break;
      case '"':
        escaped += F("\\\"");
        break;
      case '\n':
        escaped += F("\\n");
        break;
      case '\r':
        escaped += F("\\r");
        break;
      case '\t':
        escaped += F("\\t");
        break;
      default:
        escaped += c;
        break;
    }
  }
  return escaped;
}

String hexAddress(byte address) {
  String value = "0x";
  if (address < 0x10) {
    value += "0";
  }
  value += String(address, HEX);
  value.toUpperCase();
  return value;
}

int fromHex(char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }
  if (c >= 'a' && c <= 'f') {
    return c - 'a' + 10;
  }
  if (c >= 'A' && c <= 'F') {
    return c - 'A' + 10;
  }
  return -1;
}

String urlDecode(const String &value) {
  String decoded;
  decoded.reserve(value.length());

  for (size_t i = 0; i < value.length(); i++) {
    const char c = value.charAt(i);
    if (c == '+') {
      decoded += ' ';
    } else if (c == '%' && i + 2 < value.length()) {
      const int high = fromHex(value.charAt(i + 1));
      const int low = fromHex(value.charAt(i + 2));
      if (high >= 0 && low >= 0) {
        decoded += (char)((high << 4) | low);
        i += 2;
      } else {
        decoded += c;
      }
    } else {
      decoded += c;
    }
  }

  return decoded;
}

String queryValue(const String &target, const String &name) {
  const int queryStart = target.indexOf('?');
  if (queryStart < 0) {
    return "";
  }

  String query = target.substring(queryStart + 1);
  const String prefix = name + "=";
  int start = 0;

  while (start < (int)query.length()) {
    int end = query.indexOf('&', start);
    if (end < 0) {
      end = query.length();
    }

    const String part = query.substring(start, end);
    if (part.startsWith(prefix)) {
      return urlDecode(part.substring(prefix.length()));
    }
    start = end + 1;
  }

  return "";
}

String pathOnly(const String &target) {
  const int queryStart = target.indexOf('?');
  if (queryStart < 0) {
    return target;
  }
  return target.substring(0, queryStart);
}

IPAddress subnetBroadcastIP() {
  const uint32_t ip = (uint32_t)WiFi.localIP();
  const uint32_t mask = (uint32_t)WiFi.subnetMask();
  return IPAddress(ip | ~mask);
}

const __FlashStringHelper *statusText(int code) {
  switch (code) {
    case 200:
      return F("OK");
    case 202:
      return F("Accepted");
    case 400:
      return F("Bad Request");
    case 404:
      return F("Not Found");
    case 405:
      return F("Method Not Allowed");
    default:
      return F("OK");
  }
}

void sendHttpJson(WiFiClient &client, int code, const String &body) {
  client.print(F("HTTP/1.1 "));
  client.print(code);
  client.print(' ');
  client.println(statusText(code));
  client.println(F("Content-Type: application/json"));
  client.println(F("Connection: close"));
  client.print(F("Content-Length: "));
  client.println(body.length());
  client.println();
  client.print(body);
}

void queueLoraMessage(const String &message) {
  String cleanMessage = message;
  cleanMessage.trim();
  if (cleanMessage.length() == 0) {
    return;
  }

  if (cleanMessage.length() > 220) {
    cleanMessage = cleanMessage.substring(0, 220);
  }

  pendingLoraMessage = cleanMessage;
  hasPendingLoraMessage = true;
}

bool sendLoraMessage(const String &message) {
  if (!loraReady) {
    Serial.println(F("LoRa TX cancelado: modulo no iniciado"));
    return false;
  }

  LoRa.beginPacket();
  LoRa.write(REMOTE_ADDRESS);
  LoRa.write(LOCAL_ADDRESS);
  LoRa.print(message);
  LoRa.endPacket();

  txCounter++;
  Serial.print(F("LoRa TX -> "));
  Serial.print(hexAddress(REMOTE_ADDRESS));
  Serial.print(F(": "));
  Serial.println(message);
  return true;
}

void handleLoraReceive(int packetSize) {
  if (packetSize == 0) {
    return;
  }

  const int recipient = LoRa.read();
  const byte sender = LoRa.read();

  String incoming;
  incoming.reserve(packetSize);
  while (LoRa.available()) {
    incoming += (char)LoRa.read();
  }

  if (recipient != LOCAL_ADDRESS && recipient != BROADCAST_ADDRESS) {
    Serial.print(F("Paquete LoRa ignorado. Destino: 0x"));
    Serial.println(recipient, HEX);
    return;
  }

  rxCounter++;
  lastRxMessage = incoming;
  lastRxSender = hexAddress(sender);
  lastRxRssi = LoRa.packetRssi();
  lastRxSnr = LoRa.packetSnr();

  Serial.print(F("LoRa RX <- "));
  Serial.print(lastRxSender);
  Serial.print(F(": "));
  Serial.println(incoming);
}

String buildStatusJson() {
  String json = "{";
  json += F("\"device\":\"esp8266\",");
  json += F("\"id\":\"");
  json += DEVICE_ID;
  json += F("\",");
  json += F("\"mode\":\"wifi_sta_lora_bridge\",");
  json += F("\"ssid\":\"");
  json += WIFI_SSID;
  json += F("\",");
  json += F("\"ip\":\"");
  json += WiFi.localIP().toString();
  json += F("\",");
  json += F("\"wifiConnected\":");
  if (WiFi.status() == WL_CONNECTED) {
    json += F("true");
  } else {
    json += F("false");
  }
  json += F(",");
  json += F("\"wifiRssi\":");
  json += String(WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : 0);
  json += F(",");
  json += F("\"loraReady\":");
  if (loraReady) {
    json += F("true");
  } else {
    json += F("false");
  }
  json += F(",");
  json += F("\"localAddress\":\"");
  json += hexAddress(LOCAL_ADDRESS);
  json += F("\",");
  json += F("\"remoteAddress\":\"");
  json += hexAddress(REMOTE_ADDRESS);
  json += F("\",");
  json += F("\"tx\":");
  json += String(txCounter);
  json += F(",");
  json += F("\"rx\":");
  json += String(rxCounter);
  json += F(",");
  json += F("\"lastRxMessage\":\"");
  json += jsonEscape(lastRxMessage);
  json += F("\",");
  json += F("\"lastRxSender\":\"");
  json += lastRxSender;
  json += F("\",");
  json += F("\"lastRxRssi\":");
  json += String(lastRxRssi);
  json += F(",");
  json += F("\"lastRxSnr\":");
  json += String(lastRxSnr, 2);
  json += F("}");
  return json;
}

void handleRoot(WiFiClient &client) {
  sendHttpJson(client, 200, F("{\"device\":\"esp8266\",\"service\":\"bovisense_wifi_lora_bridge\"}"));
}

void handlePing(WiFiClient &client) {
  sendHttpJson(client, 200, F("{\"ok\":true,\"message\":\"ESP8266 activo\"}"));
}

void handleStatus(WiFiClient &client) {
  sendHttpJson(client, 200, buildStatusJson());
}

void handleSend(WiFiClient &client, const String &target) {
  const String message = queryValue(target, "msg");
  if (message.length() == 0) {
    sendHttpJson(client, 400, F("{\"queued\":false,\"error\":\"Falta parametro msg\"}"));
    return;
  }

  queueLoraMessage(message);
  sendHttpJson(client, 202, F("{\"queued\":true}"));
}

void consumeHeaders(WiFiClient &client) {
  uint32_t startedAt = millis();
  while (client.connected() && millis() - startedAt < 150) {
    if (!client.available()) {
      delay(1);
      continue;
    }

    String line = client.readStringUntil('\n');
    line.trim();
    if (line.length() == 0) {
      return;
    }
  }
}

void handleHttpClient() {
  WiFiClient client = httpServer.available();
  if (!client) {
    return;
  }

  client.setTimeout(120);
  String requestLine = client.readStringUntil('\n');
  requestLine.trim();
  consumeHeaders(client);

  const int firstSpace = requestLine.indexOf(' ');
  const int secondSpace = requestLine.indexOf(' ', firstSpace + 1);
  if (firstSpace < 0 || secondSpace < 0) {
    sendHttpJson(client, 400, F("{\"error\":\"BAD_REQUEST\"}"));
    client.stop();
    return;
  }

  const String method = requestLine.substring(0, firstSpace);
  const String target = requestLine.substring(firstSpace + 1, secondSpace);
  const String path = pathOnly(target);

  if (method != "GET") {
    sendHttpJson(client, 405, F("{\"error\":\"METHOD_NOT_ALLOWED\"}"));
  } else if (path == "/") {
    handleRoot(client);
  } else if (path == "/ping") {
    handlePing(client);
  } else if (path == "/status") {
    handleStatus(client);
  } else if (path == "/send") {
    handleSend(client, target);
  } else {
    sendHttpJson(client, 404, F("{\"error\":\"NOT_FOUND\"}"));
  }

  delay(1);
  client.stop();
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  Serial.print(F("Conectando al hotspot: "));
  Serial.println(WIFI_SSID);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  const uint32_t startedAt = millis();
  while (WiFi.status() != WL_CONNECTED &&
         millis() - startedAt < WIFI_CONNECT_TIMEOUT_MS) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println(F("ERROR: no se pudo conectar al hotspot"));
    return;
  }

  Serial.print(F("Wi-Fi conectado. IP del ESP8266: "));
  Serial.println(WiFi.localIP());
  Serial.print(F("RSSI: "));
  Serial.print(WiFi.RSSI());
  Serial.println(F(" dBm"));
}

void ensureWiFiConnected() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }

  const uint32_t now = millis();
  if (now - lastWifiReconnectAttempt < WIFI_RECONNECT_INTERVAL_MS) {
    return;
  }

  lastWifiReconnectAttempt = now;
  Serial.println(F("Wi-Fi desconectado. Reintentando conexion..."));
  connectWiFi();
}

String buildDiscoveryMessage() {
  String message = DISCOVERY_PREFIX;
  message += F("|device=esp8266|ip=");
  message += WiFi.localIP().toString();
  message += F("|port=");
  message += String(HTTP_PORT);
  message += F("|id=");
  message += DEVICE_ID;
  return message;
}

void sendDiscoveryPacket(const IPAddress &targetIp, const String &message) {
  discoveryUdp.beginPacket(targetIp, DISCOVERY_PORT);
  discoveryUdp.print(message);
  discoveryUdp.endPacket();
}

void handleDiscoveryUdp() {
  const int packetSize = discoveryUdp.parsePacket();
  if (packetSize <= 0) {
    return;
  }

  String request;
  request.reserve(packetSize);
  while (discoveryUdp.available()) {
    request += (char)discoveryUdp.read();
  }
  request.trim();

  if (request != DISCOVERY_REQUEST) {
    Serial.print(F("UDP discovery ignorado: "));
    Serial.println(request);
    return;
  }

  const String response = buildDiscoveryMessage();
  const IPAddress remoteIp = discoveryUdp.remoteIP();
  const uint16_t remotePort = discoveryUdp.remotePort();

  discoveryUdp.beginPacket(remoteIp, remotePort);
  discoveryUdp.print(response);
  discoveryUdp.endPacket();

  Serial.print(F("UDP discovery respuesta -> "));
  Serial.print(remoteIp);
  Serial.print(':');
  Serial.print(remotePort);
  Serial.print(F(" | "));
  Serial.println(response);
}

void announceDiscovery(bool force = false) {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  const uint32_t now = millis();
  if (!force && now - lastDiscoveryBroadcast < DISCOVERY_INTERVAL_MS) {
    return;
  }

  lastDiscoveryBroadcast = now;
  const String message = buildDiscoveryMessage();
  const IPAddress subnetBroadcast = subnetBroadcastIP();
  const IPAddress gateway = WiFi.gatewayIP();

  sendDiscoveryPacket(subnetBroadcast, message);
  sendDiscoveryPacket(IPAddress(255, 255, 255, 255), message);

  // En modo hotspot, el telefono suele ser el gateway. Este unicast evita
  // modelos Android que no entregan broadcast local a las apps del telefono.
  if (gateway != IPAddress(0, 0, 0, 0)) {
    sendDiscoveryPacket(gateway, message);
  }

  Serial.print(F("UDP discovery enviado: "));
  Serial.println(message);
}

void initWiFiStation() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleepMode(WIFI_NONE_SLEEP);
  WiFi.hostname("BoviSense-ESP8266");
  WiFi.persistent(false);
  WiFi.setAutoReconnect(true);

  Serial.println();
  Serial.println(F("BoviSense ESP8266 Hotspot movil <-> LoRa"));
  Serial.print(F("Hotspot SSID: "));
  Serial.println(WIFI_SSID);
  connectWiFi();
  announceDiscovery(true);
}

void initLoRa() {
  LoRa.setPins(LORA_CS_PIN, LORA_RST_PIN, LORA_DIO0_PIN);
  if (!LoRa.begin(LORA_FREQUENCY_HZ)) {
    loraReady = false;
    Serial.println(F("ERROR: no se pudo inicializar LoRa SX1278"));
    return;
  }

  LoRa.enableCrc();
  loraReady = true;
  Serial.println(F("LoRa SX1278 inicializado"));
}

void initHttpServer() {
  discoveryUdp.begin(DISCOVERY_PORT);
  Serial.print(F("UDP discovery escuchando en puerto "));
  Serial.println(DISCOVERY_PORT);

  httpServer.begin();
  httpServer.setNoDelay(true);
  Serial.println(F("Servidor HTTP JSON minimo iniciado en puerto 80"));
}

void setup() {
  Serial.begin(115200);
  Serial.setTimeout(80);
  delay(500);

  initWiFiStation();
  initLoRa();
  initHttpServer();
}

void loop() {
  ensureWiFiConnected();
  handleDiscoveryUdp();
  announceDiscovery();
  handleHttpClient();

  if (hasPendingLoraMessage) {
    const String message = pendingLoraMessage;
    pendingLoraMessage = "";
    hasPendingLoraMessage = false;
    sendLoraMessage(message);
  }

  if (Serial.available()) {
    const String serialMessage = Serial.readStringUntil('\n');
    queueLoraMessage(serialMessage);
  }

  if (loraReady) {
    handleLoraReceive(LoRa.parsePacket());
  }
}
