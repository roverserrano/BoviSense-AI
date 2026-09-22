# Pinout (Jetson Orin Nano <-> SX1278)

Numeracion fisica del conector de 40 pines. Configuracion que ya funciono en
pruebas con el ESP32 y el LoRa.

| SX1278 | Jetson Orin Nano | Nota |
| --- | --- | --- |
| VCC | pin 17 (3.3 V) | confirmado |
| RST | pin 17 (3.3 V) | puenteado al mismo 3.3 V, permanente |
| GND | GND | confirmado |
| MOSI | pin 19 / SPI0_MOSI | confirmado |
| MISO | pin 21 / SPI0_MISO | confirmado |
| SCK | pin 23 / SPI0_SCK | confirmado |
| NSS/CS | pin 24 / SPI0_CS0 | confirmado |
| DIO0 | pin 31 | confirmado |

El receptor controla SPI con `spidev`. **No** usa `Jetson.GPIO` ni `libgpiod`:
no hay ningun GPIO reclamado por el script.

## RST

RST del SX1278 va al pin 17 (3.3 V) de forma permanente. Consecuencias:

- No reconectar RST al pin 29 ni a ningun otro GPIO.
- El **pin 29 queda libre**.
- El script no puede (ni debe) resetear el radio por software; no se aplican
  pulsos LOW. Un RST flotante o desconectado hace que el SX1278 reciba pero
  falle al transmitir, por eso el puente a 3.3 V es obligatorio.
- `--use-gpio-rst` y `--rst-gpio-*` quedaron obsoletos y se ignoran.

## DIO0

DIO0 esta en el pin 31, pero el receptor no lo lee: consulta `REG_IRQ_FLAGS` por
SPI y temporiza la transmision. La radio funciona igual si DIO0 no esta
conectado, aunque el cableado confirmado lo incluye.

## ESP32 (puente BLE <-> LoRa)

Pines del sketch `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/`:

| Senal | ESP32 |
| --- | --- |
| NSS/CS | 5 |
| RST | 14 |
| DIO0 | 4 |

El RST del ESP32 (GPIO 14) si se pulsa en el arranque por el propio sketch; el
del SX1278 en la Jetson no, porque esta fijo a 3.3 V.

Validar alimentacion, antena y continuidad antes de encender. No usar 5 V con
el SX1278.
