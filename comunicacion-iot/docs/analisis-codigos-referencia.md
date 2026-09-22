# Analisis Comparativo de Codigos de Referencia (historico)

> **Estado: historico.** Este documento analiza los sketches ESP8266/NodeMCU que
> sirvieron de referencia al inicio del proyecto. No describe el sistema
> vigente: hoy el puente es un ESP32 BLE que retransmite tramas opacas `C1`/`R1`
> y el firmware ESP8266 ya no forma parte del repositorio. Para el
> comportamiento actual vea `arquitectura-comunicacion.md`,
> `flujo-comandos.md` y `protocolo-lora.md`.

## Similitudes utiles

Person 1 y Person 2 tienen la misma estructura:

- Inicializan LoRa a `433E6`.
- Usan encabezado simple de dos bytes: destinatario y origen.
- Mantienen direcciones locales opuestas: `0xBB` y `0xCC`.
- Permiten comunicacion bidireccional.
- Reenvian mensajes recibidos hacia WebSocket.

## Diferencias relevantes

- Person 1 usa `localAddress = 0xBB` y `destination = 0xCC`.
- Person 2 usa `localAddress = 0xCC` y `destination = 0xBB`.
- Para BoviSense-AI, Person 1 representa mejor el ESP32 puente.
- Person 2 representa mejor el nodo remoto, ahora implementado en Jetson Python.

## Riesgos detectados

- Son sketches ESP8266/NodeMCU, no Jetson ni ESP32.
- `ESP8266WiFi.h`, `ESPAsyncTCP.h` y `LittleFS` no aplican al Jetson.
- `data[len] = 0` puede escribir fuera del buffer recibido por WebSocket.
- No hay autenticacion ni validacion fuerte de comandos.
- Se acepta texto libre desde WebSocket o Serial.
- No hay checksum ni protocolo JSON validado.
- El filtro `recipient != localAddress && recipient != destination` es debil; broadcast debe ser explicito.
- No hay manejo robusto de errores LoRa.
- No separan radio, protocolo y acciones.

## Elementos reutilizados

- Frecuencia `433 MHz`.
- Encabezado LoRa simple: destino/origen.
- Modelo bidireccional.
- Direcciones `0xBB` para ESP32 y `0xCC` para Jetson.
- Idea de puente WebSocket hacia app movil.

## Elementos reemplazados

- NodeMCU/ESP8266 se reemplaza por ESP32 en
  `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/`.
- La logica del receptor remoto se reemplaza por Python en Jetson.
- Texto libre y JSON se reemplazan por tramas autenticadas `C1`/`R1`.
- Callbacks inseguros se reemplazan por manejo defensivo.
