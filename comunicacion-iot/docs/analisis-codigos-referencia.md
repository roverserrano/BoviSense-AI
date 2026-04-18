# Analisis Comparativo de Codigos de Referencia

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

- NodeMCU/ESP8266 se reemplaza por ESP32 en `bridge_wifi_lora.ino`.
- La logica del receptor remoto se reemplaza por Python en Jetson.
- Texto libre se reemplaza por JSON validado y lista blanca.
- Callbacks inseguros se reemplazan por manejo defensivo.

