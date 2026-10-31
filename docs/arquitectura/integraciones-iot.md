# Integracion IoT: app, ESP32, LoRa, Jetson y backend

Estado del codigo local al 2026-10-31. Las pruebas y la compilacion no demuestran
que esta version este instalada en los dispositivos.

## Flujo implementado

```text
App --HTTP--> Backend: autenticar, reservar sesion y emitir C1 firmado
App --BLE (~C1...\n)--> ESP32 --LoRa (C1 completo)--> Jetson
Jetson: autenticar, deduplicar en SQLite y ejecutar/consultar worker
Jetson --LoRa (R1 firmada)--> ESP32 --BLE (~R1...\n)--> App
App --HTTP--> Backend: verificar firma, ticket, propietario y sesion
App: mostrar respuesta verificada; guardar conteo solo con prueba final
```

El ESP32 filtra estructura y correlacion, pero no posee la clave ni autentica.
B0 informa errores locales y nunca autoriza guardar un resultado. Los helpers
JSON/WebSocket de `comunicacion-iot/shared/` son historicos, ajenos a este flujo.

## Responsabilidades y fuentes

| Componente | Implementacion | Responsabilidad |
| --- | --- | --- |
| App | `frontend/lib/data/services/esp32_ble_bridge_service.dart`: `sendCommand`, `_sendCommand`, `_receive`, `_release` | Cola serial, sesion al encolar, ticket, BLE, verificacion y estado |
| Transporte app | `frontend/lib/core/utils/iot_ble_protocol.dart`: `IotBleFrameDecoder`, `matchesReply` | Reensamblado acotado, vencimiento y correlacion por solicitud/sesion |
| Backend | `backend/src/services/iotService.js`: `issue`, `verify` | Tickets, propietario, reserva, orden de respuestas y prueba final |
| Firmas | `backend/src/services/iotProtocol.js` | HMAC-SHA256 truncado a 16 bytes y contrato |
| ESP32 | `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino` y `bridge_protocol.h` | BLE/colas; SPI, reintentos y notificaciones desde loop |
| Seguridad Jetson | `jetson/secure_protocol.py`: `SecureProtocol.handle` | Firma, ventana temporal, antirreplay SQLite, respuesta cacheada |
| Control Jetson | `jetson/lora_jetson_rx.py`: `prepare`, `start`, `stop`, `status`, `result` | Sesiones, proceso detector y finales persistidos |
| Detector | `jetson/run_bovino.py` | Camara, TensorRT, tracking, conteo y salida estructurada |

## HTTP y persistencia

- `POST /api/ganadero/iot/comandos`: `{command, request_id, session_id?}`.
  Devuelve ticket con frame, comando, sesion e identificador de solicitud.
- `POST /api/ganadero/iot/respuestas`: `{frame}`. Devuelve status, session,
  count, device_id y proof. Conteo desconocido: `unknown`.
- `IotCommands`: vigencia 60 s. Repetir identificador y contexto devuelve el
  mismo ticket; datos diferentes se rechazan. Sincronizar relojes backend/Jetson.
- `IotDevices`: reserva 900 s; otro usuario no puede iniciar mientras esta
  vigente. S con reserva propia se convierte en Q. Una nueva sesion exige finca.
- `IotSessions`: solo STOPPED/RESULT con cantidad, firma y fecha de cierre
  valida producen prueba final. ERROR no produce prueba.
- Una R1 ya verificada se devuelve sin repetir transiciones. El ticket captura
  `lease_session_id`: un H/IDLE anterior no libera una reserva nueva.
  `issued_at_ms` y `last_response_issued_ms` evitan que consultas emitidas antes
  sobrescriban un estado posterior. Son campos internos, sin cambio de C1/R1.
  Usan reloj del backend: emisiones en el mismo milisegundo no tienen un orden
  estricto distribuido. Una prueba terminal valida conserva precedencia.
- Guardar historial exige la prueba final. Perder una respuesta no equivale
  a que la orden no se ejecutara.

## BLE, radio y recuperacion

Nombre BLE: `BoviSense-Bridge`. Servicio:
`7d2f0001-1f3b-4a9b-8f2a-b05e00000001`; RX `7d2f0002-...`, TX `7d2f0003-...`.
Los UUID completos se conservan en app y sketch.

```text
C1|request_id|expires|command|session_id|mac
R1|request_id|session_id|status|count|timestamp|completed_at|mac
B0|request_id|ERROR|reason
```

IDs de solicitud/sesion: 32 hex minusculas. H/P usan sesion `-`; cantidad y
cierre ausentes tambien se codifican `-`. El puente no modifica tramas firmadas.

| Limite | Valor / efecto |
| --- | --- |
| C1 / R1 | 180 / 200 bytes ASCII |
| BLE | `~<trama>\n`, fragmentos de 18 bytes |
| Reensamblado | Vence tras 5 s sin bytes o cambio de conexion |
| Escritura app | 5 s totales para los fragmentos |
| Espera app | R1 hasta 25 s despues de escribir; HTTP tiene timeout separado de 30 s |
| TX ESP32 | Asincrona, maximo 3 s para TxDone |
| Espera LoRa | 22 s; hasta 3 envios identicos a los 0/6/12 s |
| Colas ESP32 | 4 elementos por cola; callbacks no esperan SPI/LoRa |
| Notificaciones | Un fragmento cada 15 ms; salida pendiente vence tras 5 s |
| Inicializacion radio | 8 s despues de BLE; reintento tras 15 s si falla |
| Sondeo app | 4 s, con retroceso hasta 12 s |
| Sesion Jetson | Maximo 600 s; excederlo produce ERROR sin prueba final |
| Cierre worker | 8 s tras SIGTERM; SIGKILL si es necesario, con ERROR |

Sin R1 el puente retransmite el mismo ticket. Jetson responde la R1 cacheada sin
reejecutar. Un Q nuevo usa un request-id nuevo y consulta estado actualizado.
El puente admite las dos copias R1 de Jetson: la app usa la primera completa
que coincide en solicitud/sesion, el backend la autentica y las demas se ignoran.
No existe ACK BLE de aplicacion por fragmento.

Al desconectar se descartan elementos de la conexion anterior. La Jetson puede
seguir contando: desconectar no envia T. Al reconectar, consultar Q/R con la
sesion del backend antes de iniciar otra. La cancelacion no se presenta como
orden exitosa en la app.

B0 emitidos: `lora_not_ready`, `lora_send_failed`, `lora_tx_timeout`,
`bridge_busy_waiting_lora`, `bridge_queue_full`, `jetson_response_timeout`.
Ninguno demuestra que el detector haya parado. La app conserva traducciones
de errores antiguos por compatibilidad.

Radio: 433 MHz, SF7, BW 125 kHz, CR 4/5, CRC, SyncWord `0xF3`, TX 17 dBm.
ESP32 SS=5/RST=14/DIO0=4; SPI predeterminado de ESP32 Dev Module
SCK=18/MISO=19/MOSI=23. En Jetson RST sigue fijo a 3.3 V, sin control GPIO.
Se conserva brownout en ESP32; la fuente debe validarse fisicamente.

## Ejecucion del conteo

| Comando | Comportamiento |
| --- | --- |
| H / ESTADO | Disponibilidad sin cantidad ni prueba final de otra sesion |
| P / PREPARARCONTEO | Valida rutas/entorno; READY no demuestra captura real |
| S / INICIARCONTEO | Lanza worker; STARTED no demuestra frames ni inferencia |
| Q / ESTADOCONTEO | Progreso o final de la sesion; puede recuperar STOPPED persistido |
| T / DETENERCONTEO | STOPPED solo con salida correcta, frames procesados y final valido persistido |
| R / RESULTADOCONTEO | Recupera el final de esa sesion; IDLE si no existe y no hay otra activa |

El worker comunica COUNT_UPDATE, COUNT_FINAL, WORKER_STATUS y JSON atomico por
`BOVISENSE_STATUS_FILE` / `BOVISENSE_RESULT_FILE`. El receptor comprueba sesion,
proceso terminado y coherencia antes de persistir el final y responder. Error
de camara/inferencia, cero frames procesados, cierre forzado o fallo de
persistencia impiden exito. Una escena procesada sin bovinos admite cero valido.
Las colas de frames son acotadas.

La sesion viva no se reconstruye tras reiniciar el receptor; los finales SQLite
se conservan y Q/T/R pueden recuperarlos. H/IDLE o Q/IDLE permiten liberar la
reserva correspondiente si Jetson ya no conoce la sesion. El conteo unico con
dron en movimiento sigue requiriendo evaluacion real.

## Validacion y limites

Sketch completo compilado localmente: ESP32 Dev Module, Arduino-ESP32 3.3.8,
LoRa 0.8.0. Pruebas de transporte C++, contrato Node/Python/C++, fragmentacion
Dart, sesiones backend con Firestore en memoria y fallos del worker con dobles.
No se accionaron equipos ni servicios productivos.

PENDIENTE: firmware efectivamente cargado, recorrido telefono-historial,
Auth/Firestore real o emulado para esta revision, RF, consumo, brownout, heap
sostenido, CSI/TensorRT, error de conteo y reinicios reales. Las firmas no cifran
LoRa ni impiden interferencia; BLE sigue sin emparejamiento autenticado.

Procedimiento y criterios:
[Validacion de la integracion](../../comunicacion-iot/docs/validacion-integracion.md),
[protocolo](../../comunicacion-iot/docs/protocolo-lora.md),
[flujo](../../comunicacion-iot/docs/flujo-comandos.md) y
[Jetson](../../jetson/README.md).
