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

El SX1278 de la Jetson se controla por `/dev/spidev0.0` a 10 kHz. Su VCC y su
RST van puenteados a 3.3 V (pin 17) de forma permanente, asi que el receptor no
reclama ningun GPIO: el pin 29 queda libre y DIO0 (pin 31) no se lee porque el
estado se consulta por `REG_IRQ_FLAGS`. El ESP32 usa SS 5, RST 14 y DIO0 4.

## Que viaja por el aire

Las tramas `C1` y `R1` descritas en `flujo-comandos.md` viajan **completas y en
texto plano** por LoRa. No hay encabezado de direcciones `0xBB`/`0xCC`, ni JSON,
ni checksum propio: la autenticidad la aporta el HMAC del protocolo C1/R1.

El ESP32 no valida ni interpreta el contenido; solo retransmite bytes. Por eso
la clave compartida vive unicamente en el backend y en la Jetson.

## Fragmentacion

- LoRa: una trama completa por paquete.
- BLE: la app escribe `~<trama>\n` en fragmentos; el ESP32 espera hasta 22 s
  la respuesta por LoRa y la app hasta 25 s la `R1` verificada.

## Confirmacion de transmision

`TxDone` del SX1278 confirma que la radio transmitio, no que el otro extremo
recibio. La unica evidencia de recepcion de extremo a extremo es que la app
muestre `R1 recibido` y el backend la autentique.

## Referencias historicas

El diseño con `recipient`/`sender`, JSON y `checksum` SHA-256 corresponde a los
sketches de referencia ESP8266 y ya no describe este sistema. Se conserva solo
en `analisis-codigos-referencia.md` como contexto academico.
