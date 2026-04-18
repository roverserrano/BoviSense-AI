# ESP8266 - Puente Hotspot Movil <-> LoRa

Esta carpeta contiene el codigo ESP8266 para el flujo actual de campo.

## Sketch principal

- `bridge_hotspot_lora_discovery.ino`

## Que hace

- Se conecta al hotspot del celular `HONOR X8b`.
- Mantiene HTTP JSON en puerto `80`.
- Anuncia su IP por UDP en puerto `4210`.
- Responde solicitudes UDP `ESP_DISCOVERY_REQUEST`.
- Envia mensajes HTTP/Serial hacia LoRa.
- Recibe paquetes LoRa y los expone en `/status`.

## Endpoints HTTP

```text
GET /ping
GET /status
GET /send?msg=texto
```

## Descubrimiento UDP

Mensaje emitido por el ESP8266:

```text
ESP_DISCOVERY|device=esp8266|ip=<ip>|port=80|id=esp_lora_01
```

La app Flutter tambien puede enviar:

```text
ESP_DISCOVERY_REQUEST
```

y el ESP8266 responde por unicast al remitente.

## Cargar desde Arduino IDE

1. Activar hotspot del celular:
   - SSID: `HONOR X8b`
   - Password: `rover123`
2. Abrir `bridge_hotspot_lora_discovery.ino`.
3. Seleccionar placa ESP8266 correcta.
4. Cargar el sketch.
5. Abrir Monitor Serie a `115200`.

Log esperado:

```text
BoviSense ESP8266 Hotspot movil <-> LoRa
Wi-Fi conectado. IP del ESP8266: <ip>
LoRa SX1278 inicializado
UDP discovery escuchando en puerto 4210
Servidor HTTP JSON minimo iniciado en puerto 80
UDP discovery enviado: ESP_DISCOVERY|device=esp8266|ip=<ip>|port=80|id=esp_lora_01
```

## Prueba historica

- `wifi_ap_test.ino`

Solo valida Access Point Wi-Fi basico. No usa LoRa ni descubrimiento automatico.
