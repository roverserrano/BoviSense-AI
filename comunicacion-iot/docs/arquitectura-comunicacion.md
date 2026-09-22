# Arquitectura de Comunicacion (vigente)

## Nodos

- App movil Flutter: BLE central. Nunca habla con la radio directamente.
- ESP32: puente BLE <-> LoRa. Retransmite tramas opacas y no conoce la clave.
- Backend Express: firma los comandos `C1` y verifica las respuestas `R1`.
- Jetson Orin Nano: receptor Python con SX1278 por SPI; autentica, ejecuta y firma.
- SX1278: radio LoRa 433 MHz en ambos extremos.

## Flujo

1. La app pide un ticket a `POST /api/ganadero/iot/comandos`.
2. El backend valida rol/sesion y devuelve una trama `C1` firmada (HMAC-SHA256).
3. La app escribe la trama por BLE (`~<trama>\n`) al ESP32.
4. El ESP32 retransmite la trama completa por LoRa.
5. La Jetson verifica firma, expiracion y antirreplay antes de ejecutar.
6. La Jetson responde `R1` firmada por LoRa; el ESP32 la reenvia por BLE.
7. La app envia la `R1` a `POST /api/ganadero/iot/respuestas` para verificarla.
8. Solo despues de esa verificacion la app muestra el estado o el conteo.

El guardado de un conteo real exige la prueba final firmada: la cantidad nunca
la inventa el cliente.

## Modos

- Sin `IOT_SHARED_SECRET` valido, el backend responde `503` y la Jetson rechaza
  las tramas `C1`. No hay modo de simulacion con JSON ni WebSocket.
- Unico propietario del SPI: `lora_jetson_rx.py` toma un `flock` en
  `/run/bovisense-spidev0.0.lock`. Una segunda instancia se niega a abrir el
  radio.

## Historia

La primera version del proyecto usaba un ESP8266 con Access Point, JSON y
WebSocket. Ese diseño fue reemplazado: hoy no hay JSON sobre LoRa, ni
validacion de comandos en el puente, ni firmware ESP8266 en el repositorio.
