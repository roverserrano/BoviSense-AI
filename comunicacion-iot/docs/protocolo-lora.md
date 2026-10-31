# Protocolo LoRa (vigente)

## Configuracion de radio

| Parametro | Valor |
| --- | --- |
| Frecuencia | 433 MHz |
| Spreading factor | SF7 |
| Ancho de banda | 125 kHz |
| Coding rate | 4/5 |
| CRC | activado |
| SyncWord | `0xF3` |
| TX en la Jetson | 17 dBm |
| TX en ESP32 | 17 dBm |

El SX1278 de la Jetson se controla por `/dev/spidev0.0` a 10 kHz. Su VCC y su
RST van puenteados a 3.3 V (pin 17) de forma permanente, asi que el receptor no
reclama ningun GPIO: el pin 29 queda libre y DIO0 (pin 31) no se lee porque el
estado se consulta por `REG_IRQ_FLAGS`. El ESP32 usa SS 5, RST 14 y DIO0 4.

## Que viaja por el aire

Las tramas `C1` y `R1` descritas en `flujo-comandos.md` viajan **completas y en
texto plano** por LoRa. No hay encabezado de direcciones `0xBB`/`0xCC`, ni JSON,
ni checksum propio: la autenticidad la aporta el HMAC del protocolo C1/R1.

El ESP32 filtra ASCII imprimible, cantidad de campos, IDs, nombres de comando
y estados; correlaciona request-id **y sesion**. No comprueba firmas ni la
hora de expiracion y no modifica, recorta ni vuelve a firmar la trama. La clave
compartida vive unicamente en el backend y en la Jetson.

## Fragmentacion

- LoRa: una trama completa por paquete; C1 hasta 180 bytes, R1 hasta 200.
- BLE: la app escribe `~<trama>\n` en fragmentos; el ESP32 espera hasta 22 s
  la respuesta por LoRa y la app hasta 25 s la R1 **recibida**, despues de
  terminar la escritura BLE (hasta 5 s). La verificacion HTTP tiene su propio
  timeout de 30 s; no esta incluida en esos 25 s.
- Fragmentos de 18 bytes en ambos sentidos, compatibles con MTU ATT minimo.
  Un fragmento incompleto vence tras 5 s sin bytes o al cambiar de conexion.
- El puente envia una notificacion cada 15 ms desde `loop()`, con colas de
  cuatro elementos; el callback BLE no transmite por SPI ni espera la radio.

## Esperas, reintentos y recuperacion

- TX asincrona, vigilancia explicita de `REG_IRQ_FLAGS.TxDone` con limite de
  3 s. Se usa SPI exclusivamente desde `loop()`; no hay ISR de radio.
- Si TX falla o vence, B0 `lora_send_failed` / `lora_tx_timeout`; el puente
  cierra el radio y reintenta inicializarlo despues de 15 s.
- Sin R1 se repite exactamente el mismo C1 hasta tres intentos (0/6/12 s),
  siempre dentro de 22 s. Ningun reintento renueva el ticket.
- Una R1 con otro ID/sesion no termina la espera. Se admiten las dos copias
  de Jetson mientras siga vigente la correlacion. La app usa la primera trama
  completa y el backend la autentica; las copias restantes se ignoran en la app.
- B0 `bridge_busy_waiting_lora` y `bridge_queue_full` no alteran el conteo.
  B0 nunca es una confirmacion de Jetson.
- Los temporizadores soportan el desbordamiento de `millis()`.
- BLE arranca primero; LoRa se inicializa 8 s despues. Durante ese intervalo
  puede responder `lora_not_ready`. Se conserva la proteccion brownout:
  una fuente inestable debe corregirse fisicamente, no ocultando el fallo.

## Confirmacion de transmision

`TxDone` del SX1278 confirma que la radio transmitio, no que el otro extremo
recibio. La unica evidencia de recepcion de extremo a extremo es que la app
muestre `R1 recibido` y el backend la autentique.

Compilacion, pruebas de contrato y ensayo en dispositivos:
[Validacion de la integracion](validacion-integracion.md). API de referencia:
[Arduino LoRa 0.8.0](https://github.com/sandeepmistry/arduino-LoRa/blob/0.8.0/API.md).

## Referencias historicas

El diseño con `recipient`/`sender`, JSON y `checksum` SHA-256 corresponde a los
sketches de referencia ESP8266 y ya no describe este sistema. Se conserva solo
en `analisis-codigos-referencia.md` como contexto academico.
