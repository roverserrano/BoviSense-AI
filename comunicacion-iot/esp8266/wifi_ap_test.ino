/*
  BoviSense-AI - ESP8266 Wi-Fi Access Point Test

  Objetivo de esta primera prueba:
  - Cargar codigo al ESP8266/NodeMCU.
  - Crear una red Wi-Fi propia.
  - Permitir conexion desde un dispositivo movil.
  - Mostrar una pagina web simple para confirmar conectividad.

  Esta prueba NO usa LoRa todavia. Primero validamos Wi-Fi y carga del firmware.
*/

#include <ESP8266WebServer.h>
#include <ESP8266WiFi.h>

static const char *AP_SSID = "BoviSense-ESP8266";
static const char *AP_PASSWORD = "123456789";

ESP8266WebServer server(80);

const char INDEX_HTML[] PROGMEM = R"HTML(
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>BoviSense ESP8266</title>
  <style>
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      background: #f4f7f2;
      color: #172015;
      display: grid;
      min-height: 100vh;
      place-items: center;
    }
    main {
      width: min(92vw, 520px);
      padding: 24px;
      border: 1px solid #cad8c5;
      border-radius: 8px;
      background: #ffffff;
      box-shadow: 0 8px 24px rgba(23, 32, 21, 0.12);
    }
    h1 {
      margin: 0 0 12px;
      font-size: 26px;
    }
    p {
      line-height: 1.5;
    }
    code {
      background: #eef4ea;
      padding: 3px 6px;
      border-radius: 4px;
    }
    button {
      width: 100%;
      min-height: 44px;
      border: 0;
      border-radius: 6px;
      background: #236b35;
      color: white;
      font-size: 16px;
    }
    #status {
      margin-top: 14px;
      min-height: 24px;
      font-weight: 700;
    }
  </style>
</head>
<body>
  <main>
    <h1>BoviSense ESP8266</h1>
    <p>Conexion Wi-Fi correcta al modulo ESP8266.</p>
    <p>Red: <code>BoviSense-ESP8266</code></p>
    <p>IP del modulo: <code>192.168.4.1</code></p>
    <button onclick="ping()">Probar conexion</button>
    <div id="status"></div>
  </main>
  <script>
    async function ping() {
      const status = document.getElementById('status');
      status.textContent = 'Probando...';
      try {
        const response = await fetch('/ping');
        const text = await response.text();
        status.textContent = text;
      } catch (error) {
        status.textContent = 'No se pudo contactar el ESP8266';
      }
    }
  </script>
</body>
</html>
)HTML";

void handleRoot() {
  server.send_P(200, "text/html", INDEX_HTML);
}

void handlePing() {
  server.send(200, "text/plain", "ESP8266 activo");
}

void handleStatus() {
  String json = "{";
  json += "\"device\":\"esp8266\",";
  json += "\"mode\":\"wifi_ap_test\",";
  json += "\"ssid\":\"";
  json += AP_SSID;
  json += "\",";
  json += "\"ip\":\"";
  json += WiFi.softAPIP().toString();
  json += "\",";
  json += "\"clients\":";
  json += WiFi.softAPgetStationNum();
  json += "}";
  server.send(200, "application/json", json);
}

void setup() {
  Serial.begin(115200);
  delay(500);

  WiFi.mode(WIFI_AP);
  bool apStarted = WiFi.softAP(AP_SSID, AP_PASSWORD);

  Serial.println();
  Serial.println("BoviSense-AI ESP8266 Wi-Fi AP Test");
  if (!apStarted) {
    Serial.println("ERROR: no se pudo iniciar el Access Point");
  } else {
    Serial.print("SSID: ");
    Serial.println(AP_SSID);
    Serial.print("Password: ");
    Serial.println(AP_PASSWORD);
    Serial.print("IP: ");
    Serial.println(WiFi.softAPIP());
  }

  server.on("/", HTTP_GET, handleRoot);
  server.on("/ping", HTTP_GET, handlePing);
  server.on("/status", HTTP_GET, handleStatus);
  server.begin();

  Serial.println("Servidor HTTP iniciado en puerto 80");
}

void loop() {
  server.handleClient();
}

