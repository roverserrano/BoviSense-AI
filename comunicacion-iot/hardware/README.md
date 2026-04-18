# Hardware

## Jetson Orin Nano <-> LoRa-02 SX1278

Cableado fisico confirmado:

| Funcion | Pin fisico Jetson |
| --- | --- |
| SPI0_MOSI | 19 |
| SPI0_MISO | 21 |
| SPI0_SCK | 23 |
| SPI0_CS0 | 24 |
| GND | 25 |
| 3.3V | 17 |
| RST | 22 |
| DIO0 | 13 |

No usar 5V con el SX1278.

## Verificacion no destructiva

```bash
ls -l /dev/spidev*
```

Si no aparece `/dev/spidev0.0`, habilitar SPI manualmente con Jetson-IO desde el
entorno del operador. Este proyecto no modifica Jetson-IO automaticamente.

