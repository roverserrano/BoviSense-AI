class AppConfig {
  // En telefono fisico, usa la IP local del servidor backend.
  static const String apiBaseUrl = 'http://192.168.1.7:3000';

  // ESP8266 conectado al hotspot del celular:
  // SSID: HONOR X8b
  // Password: rover123
  static const int esp8266DiscoveryPort = 4210;
  static const String esp8266DiscoveryPrefix = 'ESP_DISCOVERY';
  static const String esp8266DiscoveryRequest = 'ESP_DISCOVERY_REQUEST';
  static const String esp8266ExpectedDevice = 'esp8266';
  static const String esp8266ExpectedId = 'esp_lora_01';
  static const String esp8266ExpectedMode = 'wifi_sta_lora_bridge';
  static const Duration esp8266DiscoveryRequestInterval = Duration(seconds: 3);
  static const Duration esp8266HttpScanInterval = Duration(seconds: 20);
  static const Duration esp8266HttpScanTimeout = Duration(milliseconds: 1200);
  static const int esp8266HttpScanBatchSize = 24;
  static const Duration esp8266PresenceTimeout = Duration(seconds: 15);
}
