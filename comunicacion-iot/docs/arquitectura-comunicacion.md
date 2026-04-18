# Arquitectura de Comunicacion

## Nodos

- App movil: envia JSON por WebSocket al ESP32.
- ESP32: puente Wi-Fi <-> LoRa, direccion `0xBB`.
- Jetson Orin Nano: nodo LoRa Python, direccion logica `0xCC`.
- SX1278: radio LoRa 433 MHz.

## Flujo

1. App movil se conecta al Access Point del ESP32.
2. App envia un JSON con comando permitido.
3. ESP32 valida comando y formato minimo.
4. ESP32 envia paquete LoRa con destino `0xCC`, origen `0xBB`.
5. Jetson recibe bytes por SX1278.
6. Jetson valida JSON, checksum y lista blanca.
7. Jetson ejecuta accion segura.
8. Jetson responde ACK/NACK por LoRa.
9. ESP32 reenvia respuesta a la app por WebSocket.

## Modos

- Simulacion: no usa hardware, valor por defecto.
- Hardware: requiere `--hardware`, `/dev/spidev0.0`, `spidev` y `Jetson.GPIO`.

