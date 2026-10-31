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
| `test_secure_protocol.py` | Pruebas del protocolo y del control de radio. |
| `test_tracking_logic.py` | Pruebas de la logica de tracking del worker. |
| `test_runtime_reliability.py` | Regresiones de camara, supervision, modelo y persistencia sin hardware. |
| `tracking.md` | Especificacion del seguimiento MOT de `run_bovino.py` (trabajo propuesto). |
| `systemd/unbuffered.conf` | Drop-in que fija `PYTHONUNBUFFERED=1`. |

## Rutas reales en el equipo

- Directorio de trabajo: `/home/cow/Documents/Script/`
  (`lora_jetson_rx.py` y el worker).
- Entorno Python del detector: `/home/cow/Documents/Script/env_detection`.
- Modelo TensorRT: `/home/cow/Documents/proyecto/modelos/model_fp32.engine`.
- Log del worker: `/home/cow/Documents/Script/run_bovino_lora.log`.
- Estado del protocolo: `~/.local/state/bovisense/protocol.sqlite3`
  (configurable con `BOVISENSE_STATE_DIR`). El bloqueo exclusivo del SPI vive
  en el mismo directorio por defecto (`BOVISENSE_SPI_LOCK_DIRECTORY` permite
  cambiarlo). Debe ser escribible por el usuario del servicio; no usar `/run`
  cuando el servicio corre como `cow`. No borrar el estado: es la proteccion
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

Desplegar **ambos scripts juntos**. El receptor solo acepta un final cuando el
worker sale con codigo 0 y entrega un resultado valido con al menos un frame
procesado. Un proceso terminado sin resultado se informa como `ERROR` con
conteo desconocido. Los mensajes `C1`/`R1` y el esquema SQLite se conservan.

## Configuracion del detector para Orin Nano / IMX219

Los valores conservados son CSI `sensor-id=0`, captura 1920x1080 a 30 FPS,
pipeline `nvarguscamerasrc` y entrada del modelo 640x640. **30 FPS es la
captura solicitada, no una medicion de inferencia.** Ubuntu 22.04 y el modelo
de placa no identifican por si solos las versiones de JetPack, CUDA o TensorRT.

El motor debe tener una sola entrada RGB, batch 1, NHWC o NCHW, FP32/FP16/uint8,
y salidas SSD `num_detections`, `detection_boxes`, `detection_scores`,
`detection_classes` (se admiten prefijos/sufijos en esos nombres). Se rechazan
shapes incompatibles, asignaciones CUDA fallidas y buffers rechazados por TRT.
El engine debe estar construido para la Jetson y sus bibliotecas instaladas.
Referencia: [API Python de TensorRT](https://docs.nvidia.com/deeplearning/tensorrt/latest/inference-library/python-api-docs.html).

| Worker | Receptor LoRa | Significado |
| --- | --- | --- |
| `--input-layout auto` | `--count-input-layout auto` | Detectar NHWC/NCHW cuando los canales son inequívocos. Para entrada completamente dinamica especificar layout. |
| `--normalization raw` | `--count-normalization raw` | RGB 0..255, comportamiento anterior. `zero_one` o `minus_one_one` solo si lo exige el entrenamiento. |
| `--class-id N` | `--count-class-id N` | ID de bovino segun el label map. Repetible. Sin este parametro se asume modelo de una sola clase bovina; no asumir que cow siempre tiene el mismo ID. |
| `--tracker botsort` | `--count-tracker botsort` | Requiere las dependencias externas compatibles ya instaladas. |
| `--tracker simple` | `--count-tracker simple` | Tracker interno con confirmacion temporal y GMC ORB. Opcion explicita si no se dispone de BoT-SORT. |
| `--allow-tracker-fallback` | `--count-allow-tracker-fallback` | Autorizar degradacion al tracker interno; desactivado por defecto. Motor efectivo registrado en JSON/log. |

No hay cambio automatico de normalizacion ni filtro de clase inventado. Confirmar
estos valores con la exportacion del modelo antes de medir resultados. Las
cajas esperadas son las salidas postprocesadas SSD; el script no agrega NMS si
el motor exportado entrega salidas crudas de otra arquitectura.

## Contrato de fallo y recuperacion

- Sin frames de camara durante 10 s: `capture_timeout`. La supervision detecta
  tambien lecturas bloqueadas que no retornan. No se reconecta automaticamente
  dentro de la sesion: reiniciar tracking a mitad del recorrido puede duplicar
  el conteo. Recuperar la camara y comenzar una nueva sesion.
- Sin inferencias completadas durante 60 s, incluida la carga inicial:
  `inference_timeout`. Ambos limites son configurables en el worker.
- Limite independiente de sesion: 600 s. Alcanzarlo implica `ERROR` y conteo
  parcial solo de diagnostico; el usuario debe detener normalmente antes del
  limite. Para evaluar videos largos, `--max-duration 0` desactiva ese limite
  solo en ejecucion directa.
- Parada normal: se espera un plazo total de cierre, no un plazo por hilo.
  El receptor da al worker `count-stop-timeout - 2` s (6 s con los valores
  actuales) y espera 8 s antes de SIGKILL. Un hilo nativo que no termina produce
  error y salida forzada del **proceso worker**; no se liberan sus buffers GPU
  desde otro hilo. Un controlador/GPU bloqueado puede requerir recuperacion
  del sistema y debe probarse en la Jetson.
- Cero animales con frames procesados es un resultado valido. Cero frames,
  errores de captura/inferencia, cierre forzado o final ausente nunca son un
  conteo valido. Un error no se convierte en exito al recibir SIGTERM.
- Cola CSI limitada a dos frames; video exhaustivo a cuatro, con espera del
  productor. El modo exhaustivo no descarta frames por saturacion de la cola.
- JSON atomico en directorio temporal privado por lanzamiento; el receptor
  verifica la sesion. Esos directorios se conservan para diagnostico y siguen
  la politica de limpieza de `/tmp` del equipo.
- Un lock por usuario impide workers simultaneos de ese usuario. Ejecutar
  servicio y pruebas con la misma cuenta y directorio temporal; el servicio
  debe administrar todo el grupo de procesos (revisar `KillMode=control-group`).
- Resultados finales guardados en SQLite antes de anunciar exito. Si falla la
  escritura, se informa `ERROR`, se conserva el resultado en memoria, se
  reintenta y se bloquean nuevos inicios hasta guardarlo. Consultar otra vez
  con un **nuevo request-id firmado**: el antirreplay conserva la respuesta
  original de cada request-id. No borrar la base para desbloquear el equipo.
- Consultas alternadas de sesiones finalizadas recuperan sus resultados y
  fechas originales. Repetir inicio para una sesion finalizada no la ejecuta
  otra vez. Una sesion interrumpida por corte de energia antes de persistir
  su resultado no se reconstruye automaticamente.

## Validacion en el equipo para la defensa

La validacion local usa dobles; no certifica rendimiento ni conteo unico real.
Guardar versiones reales de Python/OpenCV/TensorRT/CUDA, hash del motor,
label map, comando y configuracion de cada ensayo. No instalar paquetes
genericos que sustituyan las bibliotecas CUDA/OpenCV de JetPack sin comprobar
compatibilidad.

Con el servicio detenido y sin otro propietario de la camara, un operador
puede ejecutar este ensayo local con el tracker interno, sin enviar ordenes
fisicas por LoRa:

```bash
/home/cow/Documents/Script/env_detection/bin/python3 /home/cow/Documents/Script/run_bovino.py \
  --engine /home/cow/Documents/proyecto/modelos/model_fp32.engine \
  --source csi://0 --no-display --tracker simple --max-duration 600
```

Confirmar primero layout, normalizacion e ID de clase; agregar sus opciones
segun el modelo. Detener con Ctrl+C despues de procesar frames. Repetir luego
con BoT-SORT cuando su dependencia este validada. Estos comandos son para el
operador; no se ejecutaron en el equipo durante esta mejora.

Ensayos de aceptacion antes de la defensa:

1. Escena vacia y escena con bovinos: resultados 0 / conteo anotado manualmente;
   conservar `COUNT_FINAL`, `PERF_FINAL`, `TRACK_FINAL` y video de referencia.
2. Al menos 20 ciclos iniciar/detener desde la app, incluidos comandos repetidos;
   comprobar un solo worker, ausencia de procesos retenidos y consulta posterior.
3. Interrumpir la fuente de video mediante un mecanismo seguro para la camara
   (no retirar un flex CSI energizado): error acotado, conteo desconocido y nuevo
   inicio recuperable despues de restaurarla.
4. Fallos simulados de TensorRT, worker y disco; cierre de app, perdida de LoRa
   y reinicio del receptor. Verificar que ningun parcial se guarda como final.
5. Escenas de oclusion, reaparicion y movimiento de camara con anotacion manual.
   Medir error de conteo, falsos positivos/negativos, FPS, latencia, memoria y
   temperatura durante varias sesiones completas. Documentar resultados reales.

El acumulador cuenta **identidades de tracking confirmadas**, no una identidad
biologica garantizada. Reapariciones fuera de la ventana de reidentificacion
pueden volver a contarse. La separacion espacial y temporal de los recorridos
y los videos anotados son parte de la validacion de la tesis.

## Pruebas

```bash
cd jetson
python3 -B -m unittest test_secure_protocol test_tracking_logic test_runtime_reliability
```

No requieren hardware: el SX1278, TensorRT y CUDA se sustituyen por dobles de
prueba.
