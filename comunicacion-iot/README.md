# BoviSense-AI - Comunicacion IoT

Implementacion segura para comunicacion bidireccional:

```text
Firebase <--datos moviles--> App movil
App movil <--hotspot HTTP/UDP--> ESP8266 --LoRa SX1278 433 MHz--> Nodo LoRa remoto
App movil <--hotspot HTTP/UDP--> ESP8266 <--LoRa SX1278 433 MHz-- Nodo LoRa remoto
```

## Estado

- Simulacion/mock: funcional por defecto.
- ESP8266 hotspot + LoRa + descubrimiento UDP/HTTP: sketch actual para campo.
- ESP8266 Wi-Fi AP: prueba historica de conexion desde movil.
- Jetson hardware SX1278: implementado como modo explicito `--hardware`.
- ESP32: sketch de referencia para Wi-Fi movil <-> LoRa.

## Seguridad

- No usa `sudo`.
- No modifica Jetson-IO ni configuraciones criticas.
- No usa 5V.
- No acepta comandos libres.
- Solo lista blanca: `PING`, `GET_STATUS`, `GET_DEVICE_INFO`, `START_TASK`, `STOP_TASK`.
- El Jetson no ejecuta comandos del sistema.

## Ejecutar simulacion

```bash
python3 comunicacion-iot/simulacion/test_flow.py
```

## Sketch actual ESP8266 para campo

El ESP8266 se conecta al hotspot del celular y anuncia su IP por UDP:

```text
comunicacion-iot/esp8266/bridge_hotspot_lora_discovery.ino
```

Hotspot esperado:

```text
SSID: HONOR X8b
Clave: rover123
```

La app Flutter escucha `UDP 4210`, descubre el ESP8266 y luego consume:

```text
GET /ping
GET /status
GET /send?msg=texto
```

## Prueba ESP8266 Wi-Fi AP

Prueba basica anterior, sin LoRa:

```text
comunicacion-iot/esp8266/wifi_ap_test.ino
```

## Ejecutar pruebas

```bash
python3 -m pytest comunicacion-iot/tests-integracion
```

## Chequeo hardware Jetson

Primero verificar que SPI ya exista:

```bash
ls -l /dev/spidev*
```

Luego, solo en el Jetson con cableado correcto:

```bash
python3 comunicacion-iot/jetson/lora_hardware_check.py
```

Servicio real:

```bash
BOVISENSE_SIMULATION_MODE=false python3 comunicacion-iot/jetson/main.py --hardware
```
