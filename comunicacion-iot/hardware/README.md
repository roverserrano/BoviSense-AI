# Hardware

## Jetson Orin Nano <-> LoRa-02 SX1278

Cableado fisico confirmado y probado con el ESP32 (numeracion del conector de
40 pines):

| Funcion | Pin fisico Jetson |
| --- | --- |
| 3.3V | 17 (alimenta VCC **y** RST) |
| GND | GND |
| SPI0_MOSI | 19 |
| SPI0_MISO | 21 |
| SPI0_SCK | 23 |
| SPI0_CS0 | 24 |
| DIO0 | 31 |

El **RST va puenteado a 3.3 V (pin 17)** de forma permanente: no reconectar RST
al pin 29 y no aplicar pulsos LOW. El pin 29 queda libre. El script
`jetson/lora_jetson_rx.py` ya no controla RST por GPIO.

Versiones anteriores de este documento indicaban RST 22 o RST 29 con
`libgpiod` y DIO0 sin confirmar; ninguna de las dos es la configuracion
vigente. DIO0 quedo en el pin 31, pero el receptor no lo lee porque consulta
`REG_IRQ_FLAGS` por SPI.

No usar 5V con el SX1278.

## ESP32 puente BLE <-> LoRa

Sketch: `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/`.

| Senal | GPIO ESP32 |
| --- | --- |
| NSS/CS | 5 |
| RST | 14 |
| DIO0 | 4 |

## Verificacion no destructiva

```bash
ls -l /dev/spidev*
```

Si no aparece `/dev/spidev0.0`, habilitar SPI manualmente con Jetson-IO desde el
entorno del operador. Este proyecto no modifica Jetson-IO automaticamente.

Antes de diagnosticar fallos de radio, confirmar que existe un unico
propietario del SPI:

```bash
sudo fuser -v /dev/spidev0.0
sudo systemctl status bovisense-lora.service
```
