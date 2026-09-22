# Jetson LoRa controller files

Archivos desplegables del receptor LoRa y del worker de deteccion. El
repositorio es la fuente de codigo; la Jetson es una instalacion que puede
tener otra version.

## Que hay aqui

| Archivo | Rol |
| --- | --- |
| `lora_jetson_rx.py` | Receptor SX1278, autenticacion `C1`/`R1`, sesion y control del worker. |
| `run_bovino.py` | Detector de camara CSI + TensorRT; publica eventos `COUNT_*`. |
| `secure_protocol.py` | Envolventes firmadas, antirreplay y estado en SQLite. |
| `test_secure_protocol.py` | Pruebas unitarias del protocolo y del control de radio. |
| `systemd/unbuffered.conf` | Drop-in que fija `PYTHONUNBUFFERED=1`. |

## Rutas reales en el equipo

- Directorio de trabajo: `/home/cow/Documents/Script/`
  (`lora_jetson_rx.py` y el worker).
- Entorno Python del detector: `/home/cow/Documents/Script/env_detection`.
- Modelo TensorRT: `/home/cow/Documents/proyecto/modelos/model_fp32.engine`.
- Log del worker: `/home/cow/Documents/Script/run_bovino_lora.log`.
- Estado del protocolo: `~/.local/state/bovisense/protocol.sqlite3`
  (configurable con `BOVISENSE_STATE_DIR`). No borrarlo: es la proteccion
  antirreplay.
- Servicio: `bovisense-lora.service`, con
  `EnvironmentFile=/etc/bovisense/iot.env`, el `WorkingDirectory` anterior y
  `Restart=always`.

## Despliegue

1. Copiar `lora_jetson_rx.py` (y `secure_protocol.py`) al directorio de trabajo.
2. Copiar `run_bovino.py` si el worker tambien cambio.
3. Copiar el drop-in a
   `/etc/systemd/system/bovisense-lora.service.d/unbuffered.conf` y ejecutar
   `sudo systemctl daemon-reload && sudo systemctl restart bovisense-lora`.
4. Confirmar un unico propietario del SPI antes de diagnosticar:

```bash
sudo systemctl status bovisense-lora.service
sudo journalctl -u bovisense-lora.service -f
sudo fuser -v /dev/spidev0.0
```

No iniciar manualmente `sudo python3 lora_jetson_rx.py` mientras el servicio
esta activo: dos procesos sobre `/dev/spidev0.0` corrompen las escrituras del
SX1278 y producen timeouts y errores antirreplay.

`lora_jetson_rx.py` funciona aunque `run_bovino.py` no emita resultados
estructurados: mantiene estado real del proceso y reporta `count=unknown` hasta
que el worker publique un conteo confiable.

## Pruebas

```bash
cd jetson
python3 -m unittest test_secure_protocol.py
```

No requieren hardware: el SX1278 se sustituye por dobles de prueba.
