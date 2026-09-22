# BoviSense-AI: contexto para continuar el desarrollo

Actualizado: 2026-09-22 (sesion de continuacion: conteo, pruebas y documentacion; ver seccion 10). Este documento resume el estado observado en el repositorio y las pruebas locales anteriores. No sustituye una nueva verificacion en el hardware. **Trabajar solo en local:** el usuario no autoriza hospedaje ni despliegue hasta completar pruebas, QA y validacion de campo.

## 1. Objetivo y arquitectura

BoviSense registra conteos de bovinos en una finca mediante una app Android, un puente ESP32 BLE/LoRa y una Jetson con camara y detector. El backend gestiona identidad, configuracion, sesiones, pruebas criptograficas, historial y alertas.

Flujo vigente:

```text
App Flutter --HTTP local--> Backend Express --Firebase Admin--> Auth/Firestore
     |                          |
     | BLE                      | emite C1 / verifica R1 / guarda sesion
     v                          |
ESP32 (puente opaco) <--LoRa--> Jetson SX1278 --> run_bovino.py --> camara CSI/TensorRT
```

La app pide al backend una trama de comando firmada, la envia por BLE al ESP32 y este la retransmite por LoRa. La Jetson autentica y ejecuta el comando, responde con una trama firmada que vuelve por el mismo camino. La app presenta la respuesta **solo despues** de verificarla con el backend. El ESP32 no conoce `IOT_SHARED_SECRET`.

## 2. Componentes y funciones

| Componente | Archivo(s) principal(es) | Responsabilidad |
| --- | --- | --- |
| Backend | `backend/src/app.js`, `backend/src/routes/`, `backend/src/services/` | API Express, Firebase Admin, autenticacion, roles, limites de solicitudes, comandos IoT, conteos y alertas. Node.js 22-24. |
| App Android | `frontend/lib/main.dart`, `frontend/lib/views/`, `frontend/lib/data/` | Login Firebase, vistas de administrador/ganadero, configuracion de finca, BLE, conteo, historial y alertas. Flutter/Dart. |
| Puente ESP32 | `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino` | BLE `BoviSense-Bridge` y retransmision LoRa 433 MHz; no valida firmas. |
| Receptor Jetson | `jetson/lora_jetson_rx.py`, `jetson/secure_protocol.py` | Acceso exclusivo a SPI, radio SX1278, autenticacion C1/R1, proteccion antirreplay, control de sesion/worker. |
| Detector | `jetson/run_bovino.py` | Camara CSI, inferencia TensorRT, seguimiento y eventos `COUNT_FINAL`. |
| Reglas | `firestore.rules`, `firebase.json` | Seguridad y pruebas con emuladores Firebase; no se han desplegado. |

Funciones de ganadero implementadas en rutas: `GET /api/ganadero/dashboard`, `GET/PUT /configuracion`, `GET /dispositivo`, `POST/GET /conteos`, `GET /conteos/:id`, `GET /alertas`, `PUT /alertas/:id/leer`, `POST /iot/comandos` y `POST /iot/respuestas` (todas bajo `/api/ganadero`). El backend exige token Firebase y rol `usuario`/`ganadero`. Administracion de usuarios: `GET/POST/PUT/DELETE /api/admin/usuarios`, con control de rol. El guardado de un conteo real exige prueba final firmada; no se acepta una cantidad inventada por el cliente.

La app usa Firebase Auth/Firestore, Provider, HTTP, `flutter_blue_plus` y `permission_handler`. El flujo de conteo esta en `frontend/lib/views/ganadero/estado_dispositivo_page.dart` y `frontend/lib/data/services/esp32_ble_bridge_service.dart`: conectar BLE, revisar estado, iniciar, consultar durante la sesion, detener/recuperar resultado. Consultas de estado de conteo cada 4 s mientras corre; espera de respuesta BLE de 25 s. La UI conserva un error visible en lugar de saltar silenciosamente a la primera pantalla. Esto es implementacion, no certificacion de UX en campo.

## 3. Protocolo actual y seguridad

- Comando `C1|request_id|expires|command|session_id|mac`; respuesta `R1|request_id|session_id|status|count|timestamp|completed_at|mac`.
- HMAC-SHA256 truncado a 16 bytes (32 caracteres hexadecimales). La clave compartida es una cadena de 64 hexadecimales y debe coincidir en backend y Jetson. Nunca ponerla en Git, tickets, capturas o este archivo.
- Comandos: `H` estado, `P` preparar, `S` iniciar, `T` detener, `Q` consultar conteo, `R` resultado. Estados posibles: `READY`, `STARTED`, `RUNNING`, `STOPPED`, `RESULT`, `ERROR`, `BUSY`, `IDLE`.
- Los tickets se almacenan en `IotCommands`; sesiones en `IotSessions`; lease/dispositivo en `IotDevices` (`backend/src/services/iotService.js`). Expiracion nominal del comando: 60 s. Sincronizar relojes backend/Jetson. La sesion viva **solo existe en memoria de la Jetson**: un reinicio del receptor la pierde, y entonces responde `IDLE detail=no_active_session`; al ver ese `IDLE` el backend libera el dispositivo (`lease_until=0` y borra `session_id`) para que se pueda iniciar un conteo nuevo. Ver seccion 12.
- La Jetson guarda solicitudes/resultados en SQLite, por defecto `~/.local/state/bovisense/protocol.sqlite3` del usuario que ejecuta el servicio; `BOVISENSE_STATE_DIR` permite cambiarlo. No borrar ese estado para "arreglar" errores: forma parte de la proteccion antirreplay.
- ESP32 transmite tramas completas por LoRa; BLE usa fragmentos `~<trama>\n`. UUID BLE: servicio `7d2f0001-1f3b-4a9b-8f2a-b05e00000001`, RX `...0002`, TX `...0003`. El firmware actual espera hasta 22 s por la respuesta LoRa.

## 4. Hardware y configuracion local confirmada

Jetson SX1278: SPI0 CS0 (`/dev/spidev0.0`), 10 kHz en el script; `REG_VERSION 0x42 = 0x12` leido correctamente. **Cableado vigente confirmado por el usuario el 2026-09-22 (es la configuracion que ya funciono con el ESP32 y el LoRa):** pin 17 (3.3 V) -> VCC **y RST** (puenteado al mismo 3.3 V, permanente), GND -> GND, 19 -> MOSI, 21 -> MISO, 23 -> SCK, 24 -> NSS/CS, **31 -> DIO0**. El **pin 29 queda libre**: no volver a conectar RST al 29 ni a ningun GPIO. Como RST es fijo a 3.3 V, el receptor no controla reset por software (se elimino el manejo por `libgpiod`/`Jetson.GPIO` y no se aplican pulsos LOW); `--use-gpio-rst` y `--rst-gpio-*` quedaron obsoletos y se ignoran. DIO0 esta en el pin 31 pero el receptor no lo lee: consulta `REG_IRQ_FLAGS` por SPI y temporiza TX, asi que funciona aunque DIO0 no este conectado.

Radio: 433 MHz, SF7, ancho 125 kHz, CR 4/5, CRC activado, SyncWord `0xF3`; TX Jetson configurado a 17 dBm. Pines del firmware ESP32: SS 5, RST 14, DIO0 4. Antena y alimentacion reales deben revisarse en la prueba de campo.

La Jetson observada tenia SSH `cow@192.168.1.9` (IP local, puede cambiar). Ruta de trabajo: `/home/cow/Documents/Script/`; script de radio y worker alli, entorno Python del detector `env_detection`, modelo TensorRT en `/home/cow/Documents/proyecto/modelos/model_fp32.engine`, log del worker `/home/cow/Documents/Script/run_bovino_lora.log`. El receptor se ejecuta como `bovisense-lora.service` con `EnvironmentFile=/etc/bovisense/iot.env`, `WorkingDirectory=/home/cow/Documents/Script` y `Restart=always`. Hay un drop-in local en `jetson/systemd/unbuffered.conf` para `PYTHONUNBUFFERED=1`; se instalo en `/etc/systemd/system/bovisense-lora.service.d/unbuffered.conf` durante la sesion anterior. No guardar ni reutilizar contrasenas proporcionadas en el chat.

## 5. Estado verificado y causa del incidente principal

**Verificado en una prueba local anterior (2026-09-21, no garantia de estado actual):** se envio `H` desde la app Android, el servicio Jetson recibio `C1`, proceso `ESTADO`, produjo dos respuestas `R1` con `payload_len=90` y la app mostro `R1 recibido` / `Respuesta verificada: IDLE`; quedo disponible `Iniciar`. Asi se comprobo ese recorrido de estado hasta el telefono y backend, no el conteo completo.

La causa **comprobada** de los errores intermitentes anteriores fue la doble apertura de `/dev/spidev0.0`: un receptor iniciado por systemd y otro iniciado manualmente con `sudo python3 lora_jetson_rx.py`. `fuser` mostro ambos procesos simultaneos. Sus escrituras SPI y respuestas competian: `OP_MODE`/`FIFO_ADDR_PTR` no conservaban el valor, `PAYLOAD_LENGTH` llegaba a cero, aparecian `ERROR` antirreplay y `jetson_response_timeout` en la app. No fue provocado por el valor de `IOT_SHARED_SECRET`: la Jetson autenticaba y recibia los C1.

Correcciones ya presentes:

- `jetson/lora_jetson_rx.py` toma un bloqueo exclusivo `fcntl.flock` en `/run/bovisense-spidev0.0.lock` antes de abrir SPI. Un segundo receptor sale con mensaje explicito sin tocar el radio. Prueba unitaria incluida.
- Secuencia LoRa corregida: cambio de `LongRangeMode` solo en sleep; transicion RX -> standby -> TX sin reinicializar LoRa en cada respuesta; verificaciones de FIFO, longitud, IRQ y TxDone; retorno a RX. `TxDone` confirma **transmision del SX1278**, no recepcion por ESP32.
- RST: en la sesion anterior se controlaba por `libgpiod` en `PAA.01` (pin 29). **Eso ya no aplica:** el cableado vigente puentea RST a 3.3 V (pin 17) y el script ya no reclama ningun GPIO (ver seccion 4 y seccion 10). Logs del servicio sin buffer.
- La segunda instancia manual fue detenida y quedo un solo propietario SPI bajo `bovisense-lora.service`. Confirmar de nuevo antes de diagnosticar fallos nuevos.

No se debe iniciar manualmente otro receptor mientras el servicio esta activo. Para diagnosticar: `sudo systemctl status bovisense-lora.service`, `sudo journalctl -u bovisense-lora.service -f` y `sudo fuser -v /dev/spidev0.0`. El lock no reemplaza verificar que solo hay un servicio o proceso que controle el SX1278; un programa externo que no respete el lock aun podria competir.

## 6. Fallas y riesgos aun abiertos

1. **Conteo/camara CSI sin validacion de extremo a extremo.** Logs previos del worker mostraron errores Argus/GStreamer: `Failed to create CaptureSession`, `Failed to start capture request`, `Stream failed to connect`, `NvBufSurfaceFromFd Failed`, `capture_open_failed`. Diagnosticar camara, `nvargus-daemon`, sensor, permisos y pipeline con el hardware. `COUNT_FINAL|reason=signal` en una prueba previa ocurrio porque el usuario termino el proceso con Ctrl+C; no atribuirlo automaticamente a un bug.
2. **Flujo completo pendiente:** iniciar `S`, worker realmente activo, recuento y `Q`, detener `T`/resultado `R`, prueba final, guardado, historial, alertas, reconexion y reinicio. El `H` exitoso no certifica estas fases ni latencia de campo.
3. **Firmware real del ESP32:** existe un sketch actualizado en el repositorio, pero no esta demostrado que esa misma version este grabada en el puente fisico. Comparar su version/log serie antes de concluir que cambios de software ya estan desplegados.
4. **Calidad y tiempo de respuesta:** medir tiempos por tramo app->backend, BLE, LoRa, Jetson, retorno y verificacion bajo repeticion, interferencia/perdida, distancia real y bateria. La espera de 22/25 s es un limite, no una meta de experiencia. No prometer fiabilidad de produccion sin estas mediciones.
5. **Android/seguridad:** en debug/profile se permite HTTP local; en release no. El proyecto Android aun usa `applicationId` de ejemplo y firma debug de release (`frontend/android/app/build.gradle.kts`), pendiente antes de publicar. Se observaron mensajes `GoogleApiManager SecurityException`, pero no hay evidencia de que causaran la falla SPI/LoRa.
6. **Configuracion/documentacion obsoleta (atendido el 2026-09-22, ver seccion 10):** se corrigio el pinout al cableado vigente (VCC y RST a 3.3 V en el pin 17, DIO0 en el pin 31, pin 29 libre), `jetson/README.md` (rutas reales y uso del servicio), el README raiz, `comunicacion-iot/docs/*`, `comunicacion-iot/hardware/*` y `docs/seguridad-y-despliegue.md` (HTTP local de depuracion vs HTTPS de release). `frontend/lib/core/config/app_config.dart` quedo solo con `API_BASE_URL` y se retiraron los servicios ESP8266 de la app. `comunicacion-iot/docs/analisis-codigos-referencia.md` quedo marcado como historico. Pese a ello, contrastar siempre documento, codigo y cableado: `frontend/frontend.zip` (5.6 MB) y `firestore-debug.log` siguen sin seguimiento y no deben commitearse.
7. **Secretos y datos en repo:** revisar con cuidado comentarios heredados, ficheros de configuracion y archivos no seguidos antes de compartir o crear commits. No copiar el secreto IoT ni credenciales de SSH/Firebase/SMTP a la documentacion. Rotar credenciales expuestas por canales inseguros antes de cualquier produccion.

## 7. Como reproducir en local

Backend (necesita `backend/.env` privado con credenciales Firebase, IoT y, si se usa, SMTP):

```bash
cd backend
npm ci
npm run dev
curl http://127.0.0.1:3000/health
```

`/health` devuelve 200 cuando Firebase Auth/Firestore responden y 503 cuando no. `0.0.0.0:3000` es bind del servidor, no la URL que debe usar el telefono. Para un Android fisico conectado por USB, usar `adb reverse tcp:3000 tcp:3000`; la app trae por defecto `http://127.0.0.1:3000` en `frontend/lib/core/config/app_config.dart`. Una conexion fisica sin `adb reverse` no llegara al backend del PC mediante ese loopback. Puede cambiarse la URL con `--dart-define=API_BASE_URL=...` segun entorno, sin activar hosting.

App (telefono fisico por USB, el caso normal de este proyecto):

```bash
cd frontend
flutter pub get
bash run_usb.sh      # hace `adb reverse tcp:3000 tcp:3000` y luego `flutter run`
```

`frontend/run_usb.sh` existe justamente para no olvidar el `adb reverse`. Si se
ejecuta `flutter run` a mano, la app arranca pero todas las llamadas al backend
fallan con "No se pudo conectar con el backend...", porque `127.0.0.1` dentro
del telefono es el telefono. `adb reverse` se pierde al desconectar el cable o
reiniciar el telefono. Para WiFi, usar `--dart-define=API_BASE_URL=http://<ip-de-la-laptop>:3000`.

Jetson: cargar `IOT_SHARED_SECRET` desde `/etc/bovisense/iot.env` mediante el servicio existente y comprobar solo un propietario del SPI. No ejecutar en paralelo el comando manual `sudo ... python3 lora_jetson_rx.py`; para observar, usar `journalctl`. El servicio activo se comprobo anteriormente, pero siempre consultar su estado actual. La app requiere Firebase configurado en el dispositivo; no incluir sus ficheros privados en este documento.

## 8. Pruebas y QA pendientes

Pruebas automatizadas disponibles:

```bash
cd backend && npm test
cd frontend && flutter analyze && flutter test
cd jetson && python3 -m unittest test_secure_protocol.py
```

Las integraciones backend requieren **emuladores** de Firebase Auth y Firestore; el propio test rechaza ejecutarse sin `FIRESTORE_EMULATOR_HOST` y `FIREBASE_AUTH_EMULATOR_HOST`. Ejemplo documentado: `firebase emulators:exec --only auth,firestore --project demo-bovisense "npm --prefix backend run test:integration"`. No ejecutarlas contra Firebase productivo. En turnos anteriores pasaron pruebas backend, analisis/tests Flutter y 17 pruebas Jetson tras el lock; no se han vuelto a ejecutar para crear este documento, ni equivalen a QA de campo.

Nota de entorno: `firebase-tools` exige Java 21 o superior y esta maquina tiene Java 17 como `java` por defecto, asi que hay que forzar el JDK 21 instalado:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 PATH=/usr/lib/jvm/java-21-openjdk-amd64/bin:$PATH \
  firebase emulators:exec --only auth,firestore --project demo-bovisense "npm --prefix backend run test:integration"
```

Resultado de la ultima ejecucion (2026-09-22): `backend npm test` en verde, 5/5 integraciones backend contra emuladores, `flutter analyze` sin hallazgos, 13/13 tests Flutter y 17/17 tests Jetson. Siguen sin ser QA de campo.

Secuencia recomendada antes de hospedar: (1) probar camara CSI y detector independientemente; (2) probar `H`, `S`, `Q`, `T`, `R` y persistencia de resultado en una sesion real; (3) repetir ante perdida de paquetes, reconexion BLE, reinicio Jetson/ESP32, usuario distinto y agotamiento de bateria; (4) medir latencias y porcentaje de exito; (5) validar datos en Firestore, historial/alertas y permisos; (6) completar tests y QA Android/release; (7) solo entonces decidir despliegue. Conservar trazas correlacionadas por `request_id` sin imprimir secretos.

## 9. Reglas de trabajo para el siguiente agente

- Primero inspeccionar `git status --short`: el arbol estaba **sucio** al crear este traspaso, con muchos cambios modificados y archivos sin seguimiento (`comunicacion-iot/esp32/`, `jetson/secure_protocol.py`, `jetson/test_secure_protocol.py`, `docs/`, `firestore.rules`, entre otros). No hacer reset, checkout destructivo ni sobrescribir trabajo ajeno.
- Tratar el repositorio como fuente de codigo y la Jetson/ESP32 como instalaciones que pueden tener versiones distintas. Un archivo copiado por `scp` no prueba que el proceso activo haya reiniciado ni que el ESP32 se haya reflasheado.
- No tocar cableado ni forzar RST LOW sin acordarlo con el usuario. El RST del SX1278 va puenteado a 3.3 V (pin 17) y el pin 29 queda libre: nunca volver a cablear RST al 29. Confirmar una sola instancia del receptor antes de experimentar con radio.
- Separar observacion de inferencia: mensajes `TxDone` solo son locales al SX1278; `R1 recibido` + verificacion backend en la app si evidencia recepcion y autenticacion. Registrar fechas y versiones en cada prueba.
- Mantener alcance local hasta que pruebas automatizadas, QA de hardware y validacion de campo esten completos. No publicar servicios, reglas, app ni secretos por iniciativa propia.

## 10. Registro de la sesion 2026-09-22 (continuacion)

### Cambios realizados

1. **Sondeo del conteo en la app (defecto real corregido).** La cadena de consultas `Q` cada 4 s solo se reprogramaba si la respuesta llegaba a tiempo: si el equipo tardaba, respondia `BUSY` o fallaba la verificacion, el temporizador moria y la pantalla de conteo quedaba congelada en el ultimo conteo conocido, sin forma de refrescar (en la vista "en marcha" solo habia "Detener"). Ahora existe `_scheduleCountPoll()` / `_runCountPoll()` en `Esp32BleBridgeService`, que reprograma siempre el siguiente intento con espera creciente (4 s, 5 s, 8 s, 12 s), no lanza consultas superpuestas y se detiene solo cuando la sesion deja de estar en curso o se desconecta el puente. `resumePolling()` tambien reprograma en vez de quedarse sin temporizador si habia una peticion en vuelo.
2. **Accion manual "Actualizar conteo"** en la vista de conteo en marcha, con los botones deshabilitados mientras hay una peticion en vuelo (el sondeo periodico o una accion del usuario).
3. **Prueba de integracion del ciclo completo de conteo** (`H -> S -> Q -> T -> guardado`), que era la parte del flujo de la seccion 6.2 sin cobertura: valida `IDLE` sin sesion, creacion de sesion y lease en `IotDevices`, rechazo `403` de una sesion ajena, conteo parcial sin `proof`, rechazo `400` al intentar guardar un conteo parcial, cierre con prueba firmada, liberacion del lease, guardado del conteo, historial, alerta por faltante (`nivel=alta`) y dashboard.
4. **Cobertura unitaria del protocolo** ampliada en `backend/test/security.test.js`: expiracion, comando desconocido, identificador en mayusculas, estados invalidos, conteo negativo, trama incompleta, firma no hexadecimal, trama demasiado larga y caracteres no imprimibles.
5. **Limpieza de codigo muerto de la etapa ESP8266** en la app: se eliminaron `esp8266_bridge_service.dart` y `esp8266_discovery_service.dart` (sin ninguna referencia desde `main.dart`, vistas ni viewmodels, y sin firmware equivalente en el repositorio) y `AppConfig` quedo solo con `apiBaseUrl`. Con ellos desaparecio del codigo fuente la contrasena en claro del hotspot heredado.
6. **Documentacion puesta al dia** segun la seccion 6.6: `comunicacion-iot/hardware/{pinout-sugerido,README}.md` (cableado vigente; ver el punto 7), `comunicacion-iot/docs/{arquitectura-comunicacion,flujo-comandos,protocolo-lora}.md` reescritos para C1/R1, `analisis-codigos-referencia.md` marcado como historico, `jetson/README.md` con rutas reales y despliegue del servicio, `README.md` raiz (stack, arquitectura, endpoints IoT, Node 22-24, `IOT_SHARED_SECRET`) y `docs/seguridad-y-despliegue.md` (HTTP local de depuracion vs HTTPS de release).
7. **Cableado del SX1278 corregido (indicacion directa del usuario).** El RST del radio va **puenteado a 3.3 V en el pin 17** de forma permanente y DIO0 queda en el **pin 31**; el pin 29 queda libre. En consecuencia `jetson/lora_jetson_rx.py` ya **no controla RST por GPIO**: se eliminaron los imports de `Jetson.GPIO` y `gpiod`, las constantes `PIN_RST`/`RST_GPIO_*`/`USE_GPIO_RST`, los metodos `setup_gpio`, `setup_gpiod_gpio`, `find_gpiod_line`, `reset_line_names` y `hold_reset_high`, y la limpieza de GPIO en `close()`. Ahora el arranque imprime el cableado confirmado. `--use-gpio-rst` y `--rst-gpio-line/--rst-gpio-chip/--rst-gpio-offset` siguen parseandose pero **ocultos y sin efecto**, con aviso en consola, para no romper unidades systemd existentes que todavia los pasen. Se agrego `PIN_DIO0 = 31` como documentacion: el receptor no lee DIO0, sigue con `REG_IRQ_FLAGS`.

### Archivos modificados

- `backend/test/integration/api.test.js` (nuevo caso de ciclo completo).
- `backend/test/security.test.js` (casos de protocolo).
- `frontend/lib/data/services/esp32_ble_bridge_service.dart` (sondeo robusto).
- `frontend/lib/views/ganadero/estado_dispositivo_page.dart` (accion "Actualizar conteo", estado ocupado).
- `frontend/lib/core/config/app_config.dart` (solo `API_BASE_URL`).
- `frontend/lib/data/services/esp8266_bridge_service.dart` y `esp8266_discovery_service.dart` (**eliminados**; recuperables con `git show <commit>:<ruta>`).
- `jetson/lora_jetson_rx.py` (sin control de RST por GPIO; `PIN_DIO0 = 31`).
- `jetson/test_secure_protocol.py` (prueba de que el receptor no reclama GPIO).
- `comunicacion-iot/hardware/pinout-sugerido.md`, `comunicacion-iot/hardware/README.md`.
- `comunicacion-iot/docs/arquitectura-comunicacion.md`, `flujo-comandos.md`, `protocolo-lora.md`, `analisis-codigos-referencia.md`.
- `jetson/README.md`, `README.md`, `docs/seguridad-y-despliegue.md`, `AGENTS.md`.

### Pruebas ejecutadas

| Prueba | Comando | Resultado |
| --- | --- | --- |
| Backend unitario | `cd backend && npm test` | en verde |
| Backend integracion (emuladores) | `firebase emulators:exec --only auth,firestore --project demo-bovisense "npm --prefix backend run test:integration"` con `JAVA_HOME` de JDK 21 | 5/5 |
| Flutter analisis | `cd frontend && flutter analyze` | sin hallazgos |
| Flutter tests | `cd frontend && flutter test` | 13/13 |
| Jetson | `cd jetson && python3 -m unittest test_secure_protocol.py` | 18/18 |
| Formato Dart | `dart format --output=none --set-exit-if-changed lib` sobre los archivos tocados | sin cambios pendientes |

### Errores resueltos

- Pantalla de conteo que podia quedar congelada al morir el sondeo periodico (y sin accion manual de refresco).
- Ausencia de cobertura automatizada para el tramo servidor del flujo `S`/`Q`/`T`/`R` y para la prueba final.
- Documentacion contradictoria sobre RST (22 vs 29), rutas del worker en la Jetson y arquitectura ESP8266/WebSocket.
- Codigo muerto ESP8266 en la app y contrasena de hotspot en texto claro dentro del codigo fuente.
- Riesgo de que el receptor reclamara GPIO para RST con el cableado nuevo: ya no existe ese codigo, asi que no puede competir con el pin 29 ni dejar el radio en reset.

### Problemas pendientes

- **Hardware, sin cambios:** camara CSI y detector (Argus/GStreamer), validacion real de `S`/`Q`/`T`/`R` en el equipo, latencias por tramo, firmware ESP32 efectivamente grabado (comparar version/log serie), reconexion y reinicio.
- **La Jetson no se toco fisicamente:** el repositorio cambio (`lora_jetson_rx.py`, `test_secure_protocol.py`), pero `run_bovino.py` y `secure_protocol.py` siguen como estaban y la instalacion real puede tener otra version. Nada de esto prueba que el servicio activo ya use el codigo nuevo.
- **Despliegue pendiente del receptor actualizado:** `lora_jetson_rx.py` cambio (ya no controla RST) y hay que copiarlo a `/home/cow/Documents/Script/` y reiniciar `bovisense-lora.service`. Mientras no se copie, la Jetson sigue ejecutando la version que intenta controlar RST por `libgpiod`; con el pin 29 libre eso no rompe el radio, pero el codigo queda desactualizado.
- **Android/release:** `applicationId` de ejemplo y firma debug en release siguen pendientes (`frontend/android/app/build.gradle.kts`). Cambiar el `applicationId` exige actualizar `google-services.json` y el registro en Firebase; no hacerlo aislado.
- **Higiene:** `frontend/frontend.zip` (5.6 MB) y `firestore-debug.log` siguen sin seguimiento y no deben commitearse; `.codex` (ignorado por Git) conserva credenciales heredadas del hotspot, conviene borrarlo o rotar esa clave. La contrasena del hotspot que estaba en `app_config.dart` debe rotarse por haber estado en el arbol de trabajo.
- **Sin commit:** todos los cambios siguen sin comitear, igual que el trabajo previo del arbol.

### Siguiente paso recomendado

1. Copiar el `lora_jetson_rx.py` actualizado a `/home/cow/Documents/Script/`, reiniciar `bovisense-lora.service` y confirmar en el log las dos lineas `[GPIO]` del cableado (`VCC y RST a 3.3 V (pin 17)`, `DIO0 en pin 31`), que ya no aparece ningun mensaje de `libgpiod`/`Jetson.GPIO` y que hay un unico propietario del SPI (`sudo fuser -v /dev/spidev0.0`).
2. Correr una sesion real `H -> S -> Q -> T` con trazas correlacionadas por `request_id`, registrando fecha y version de los archivos desplegados.
3. Repetir la sesion dejando que el worker termine solo, y mientras corre, comprobar que la vista de conteo se actualiza cada 4 s y que "Actualizar conteo" funciona con el sondeo activo.
4. Con la medicion de latencias por tramo, decidir si los limites de 22 s (ESP32) y 25 s (app) se ajustan.
5. Solo despues, retomar QA de camara CSI y la decision de despliegue.

## 11. Continuacion 2026-09-22 (tarde): error de conexion en telefono fisico

### Sintoma

Al iniciar sesion con rol ganadero en la app corriendo con `flutter run` sobre
un telefono Android conectado por USB, la vista mostraba un error de conexion a
internet. El log del backend solo registraba un `GET /health` hecho desde
Postman: **la app nunca llego al servidor**. La causa de fondo de este documento
("el incidente SPI") no tenia nada que ver.

### Causa real

No habia `adb reverse` configurado (`adb reverse --list` estaba vacio). La app
usa `http://127.0.0.1:3000` por defecto, y dentro del telefono `127.0.0.1` es el
propio telefono, no la laptop. Todas las llamadas de la API fallaban con
`ClientException` (conexion rechazada) antes de salir del dispositivo.

### Solucion aplicada

1. Se ejecuto `adb reverse tcp:3000 tcp:3000` en la maquina del usuario; la
   prueba desde el propio telefono (`adb shell curl ... /health`) devolvio
   `{"ok":true,...,"firebase":"ready"}`.
2. Nuevo script `frontend/run_usb.sh`: publica el puerto con `adb reverse` y
   arranca `flutter run`, con mensajes claros si falta `adb` o no hay
   dispositivo autorizado.
3. `ApiClient.connectionHelp()` reemplaza el generico "Revisa tu conexion a
   Internet": si el destino es bucle local explica el comando `adb reverse` (con
   el puerto correcto) y la alternativa `--dart-define=API_BASE_URL=...`; si es
   una IP de red, pide revisar la red compartida. Tambien se captura
   `SocketException`, no solo `ClientException`.
4. `AuthRepository.signIn` ya no enmascara los mensajes: antes **cualquier**
   error posterior al login (incluido `El usuario esta inactivo`) se convertia
   en "No se pudo cargar el perfil autorizado...". Ahora se distinguen
   `FirebaseAuthException` (`network-request-failed` incluido, que antes caia al
   mensaje en ingles de Firebase), `FirebaseException` de Firestore
   (`unavailable`, `permission-denied`, `deadline-exceeded`) y los mensajes
   propios del repositorio.

### Archivos modificados

- `frontend/lib/data/services/api_client.dart`
- `frontend/lib/data/repositories/auth_repository.dart`
- `frontend/test/api_client_test.dart`
- `frontend/run_usb.sh` (**nuevo**)
- `README.md` (flujo USB + guia de diagnostico), `AGENTS.md`

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 15/15 (3 nuevas: ayuda de conexion, fallo de conexion accionable) |
| `adb reverse --list` | `tcp:3000 tcp:3000` activo |
| `adb shell curl 127.0.0.1:3000/health` desde el telefono | 200 `firebase: ready` |

### Pendientes

- El `adb reverse` es por sesion de USB: si se reinicia el telefono o se
  reconecta el cable hay que volver a ejecutar `bash frontend/run_usb.sh`.
- La app todavia depende de que el telefono tenga internet propio para Firebase;
  `adb reverse` solo cubre la API local.

## 12. Continuacion 2026-09-22 (tarde): "Falla del equipo" al consultar el conteo

### Sintoma

Con el receptor recien reiniciado en la Jetson (PID nuevo) y el cableado nuevo,
la app mostraba "El conteo se detuvo / Falla del equipo" con el detalle "El
equipo devolvió ERROR durante el conteo", y no habia forma de salir: "Revisar
estado" repetia el mismo ERROR.

Del log de la Jetson (las tramas llegaban bien, `H` respondia `IDLE`):

```text
LoRa RX: C1|...|Q|c3d9e883c6d25c1aaee3155df429a550|...
[Seguro] Comando ESTADOCONTEO recibido session=c3d9e883c6d25c1aaee3155df429a550
[Seguro] Resultado status=ERROR count=-
LoRa TX: R1|...|c3d9e883...|ERROR|-|...
```

### Diagnostico (cadena completa)

1. Una sesion anterior (`c3d9e883...`) quedo reservada en `IotDevices` con
   `lease_until` de hasta 900 s.
2. La Jetson se reinicio y perdio su estado en memoria (`self.session` y
   `self.last_result`). Ese estado **no** esta en SQLite: la persistencia cubre
   antirreplay y resultados firmados, no la sesion viva.
3. El usuario pulso "Iniciar conteo". Como el lease seguia vigente y era su
   propio usuario, el backend **convirtio `S` en `Q`** (logica de "reutilizar la
   sesion activa"). Por eso el log solo muestra `Q`, nunca `S`.
4. En la Jetson, `matches_requested_session()` devolvia `False` cuando
   `self.session is None` y no habia `last_result`, asi que `status()` caia en
   `ERROR detail=session_mismatch`. Un `ERROR` es indistinguible de una falla
   real de hardware.
5. El backend marcaba la sesion como `ERROR` y bajaba el lease, pero **dejaba
   `IotDevices.session_id` apuntando a la sesion muerta**, y la app conservaba
   la instantanea `ERROR`.
6. La accion "Revisar estado" de la pantalla de error enviaba `ESTADOCONTEO`
   (`Q`), que necesita una sesion viva: se repetia el ciclo `Q -> ERROR`.

Conclusion: no era un fallo de radio, ni de SPI, ni de camara. Era un estado
inconsistente entre Firestore, la app y la Jetson tras reiniciar el receptor.

### Correcciones aplicadas

**Jetson (`lora_jetson_rx.py`)**

- `status()`, `stop()` y `result()` ahora comprueban primero si el equipo tiene
  sesion. Si no la tiene y tampoco un resultado de esa misma sesion, responden
  `IDLE detail=no_active_session` en vez de `ERROR session_mismatch`. El
  `session_mismatch` queda reservado para el caso real: hay otra sesion activa
  distinta en el equipo (cubierto por prueba).
- `response_fields()` acepta un `count` explicito con centinela (`_NO_COUNT`) y
  se agrego `idle_fields()`: un `IDLE` o un `ERROR` sin sesion ya no puede
  arrastrar el conteo de una sesion anterior (`count=-`).

**Backend (`backend/src/services/iotService.js`)**

- Si la respuesta verificada es `IDLE`, se libera el dispositivo
  (`lease_until = 0` y se borra `session_id`). Sin esto, el siguiente
  `INICIARCONTEO` se volvia a convertir en `Q` hasta que expirara el lease: la
  app quedaba atascada aunque la Jetson ya estuviera libre.

**App (`frontend/lib/...`)**

- `esp32_ble_bridge_service.dart`: `isStaleSessionError()` detecta el `409` de
  sesion inexistente; para `Q`/`T`/`R` se descarta la instantanea vieja y no se
  reporta como falla del equipo. Tras un `H` verificado con `IDLE` tambien se
  descarta la instantanea, salvo que sea un resultado final pendiente de
  guardar.
- `estado_dispositivo_page.dart`: la accion de la pantalla de error ahora es
  "Consultar equipo" y envia `ESTADO` (`H`), que no depende de la sesion, en
  lugar de `ESTADOCONTEO`.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd jetson && python3 -m unittest test_secure_protocol.py` | 21/21 (4 nuevas: IDLE sin sesion en `status`/`stop`/`result`, no filtracion del conteo viejo, `session_mismatch` real) |
| Integracion backend con emuladores | 6/6 (nuevo: "a device that lost its session releases the lease and can start again") |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 16/16 (nueva: deteccion de sesion obsoleta) |
| `cd backend && npm test` | en verde |

### Como desplegar esta correccion

1. Copiar `jetson/lora_jetson_rx.py` al directorio de trabajo de la Jetson y
   reiniciar el receptor (el servicio o el proceso manual).
2. El backend se recarga solo si corre con `npm run dev` (`node --watch`); si
   no, reiniciarlo para tomar `iotService.js`.
3. En la app, hacer *hot restart* (`R`) y, en la pantalla de error, pulsar
   "Consultar equipo": con la sesion muerta la Jetson responde `IDLE`, la app
   vuelve al flujo normal y "Iniciar" crea una sesion nueva.

### Leccion para el proximo agente

`IotSessions`/`IotDevices` en Firestore y la sesion en memoria de la Jetson
pueden divergir sin que nada este roto: un reinicio del receptor basta. Cualquier
codigo nuevo debe asumir que la sesion del backend puede no existir en el equipo
y tratar esa situacion como "equipo inactivo" (recuperable), nunca como falla.

## 13. Continuacion 2026-09-22 (noche): "bucle" de detener/iniciar en el conteo

### Sintoma

Con el conteo en marcha (`RUNNING`, 0 y despues 1 animal detectado), la pantalla
entraba en lo que el usuario describio como un bucle: cada pocos segundos los
botones mostraban "Deteniendo..." y "Consultando..." y luego volvian a "Detener"
y "Actualizar conteo". Los detalles tecnicos mostraban `ESTADOCONTEO`
repitiendose. El log del backend mostraba pares
`POST /api/ganadero/iot/comandos` + `POST /api/ganadero/iot/respuestas` cada
~7 s, y cada peticion tardaba ~1,6 s.

### Diagnostico

**No habia reinicio del worker ni de la sesion.** Evidencia:

- El conteo subia (0 -> 1); no volvia a cero.
- El estado verificado era `RUNNING` de forma sostenida.
- En el log solo aparecen consultas `Q`; nunca `S` ni `T`.
- `CountSessionController.sync_worker_state()` no relanza nada: si el worker
  muere, finaliza la sesion una sola vez (`STOPPED`/`ERROR`) y no hay bucle.

El "bucle" era el **sondeo automatico ya diseñado** (consultar `Q` cada 4 s
mientras el conteo corre) combinado con dos defectos introducidos al agregar la
accion "Actualizar conteo":

1. Las etiquetas de los botones se calculaban con
   `busy = _isSendingCommand || bridge.isSending`. Como el sondeo dura ~3,5 s
   (1,6 s de ticket + ~1,6 s de verificacion + radio), los botones mostraban
   "Deteniendo..." y "Consultando..." **sin que el usuario hubiera pulsado
   nada**, y volvian a su texto normal al terminar. Eso aparentaba un ciclo de
   parada y reinicio.
2. Ambos botones quedaban deshabilitados durante el sondeo, asi que buena parte
   del tiempo el usuario ni siquiera podia detener el conteo.

### Correcciones aplicadas

- **Cola de comandos** (`frontend/lib/core/utils/command_queue.dart`, nuevo):
  los comandos hacia el equipo se serializan. Un "Detener" pulsado durante un
  sondeo espera su turno y se ejecuta, en lugar de fallar con "Espera la
  respuesta del equipo" o quedar bloqueado.
- **Etiquetas honestas**: "Deteniendo..." usa el flag `_isStopping` y
  "Consultando..." usa `_isRefreshingCount`; solo cambian por una accion del
  usuario. El sondeo de fondo ya no toca el texto de los botones.
- **Botones disponibles durante el sondeo** (la cola resuelve el orden), con el
  aviso fijo "El conteo se actualiza solo cada pocos segundos." en lugar de un
  texto parpadeante.
- **Cadencia real de 4 s**: el siguiente sondeo se programa descontando lo que
  tardo la consulta (minimo 1 s), asi el intervalo pasa de ~7,5 s a ~4,5 s en
  este equipo. El desfase venia de contar los 4 s desde la respuesta.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 18/18 (nuevo `test/command_queue_test.dart`: orden de ejecucion y que un fallo no corta la cola) |

### Despliegue

Solo cambia la app: basta *hot restart* (`R`). No hace falta tocar la Jetson ni
el backend por esta correccion.

### Nota de rendimiento

Cada consulta de conteo implica dos transacciones a Firestore y tarda ~3,5 s en
la laptop de desarrollo (1,6 s por peticion). Si en campo el sondeo resulta
demasiado pesado para el enlace LoRa, conviene subir `countPollCadence` en
`esp32_ble_bridge_service.dart` antes de tocar la logica.

## 14. Continuacion 2026-09-22 (noche): mensajes de conexion Bluetooth

### Sintoma

Al pulsar "Conectar el equipo", la app mostraba siempre lo mismo, sin decir la
causa real:

```text
No se pudo conectar con el equipo
Acerca el teléfono al equipo y vuelve a intentar.
[ERROR] No se pudo conectar. Revisa Bluetooth, permisos y el prototipo.
```

El usuario pidio que, como el ganadero no es tecnico, el sistema pida activar
el Bluetooth cuando esta apagado, y avise cuando el Bluetooth del telefono esta
ocupado con audifonos o parlantes.

### Diagnostico

El `catch` de `scanAndConnect()` reemplazaba el motivo real por un texto
generico:

```dart
_errorMessage = error is TimeoutException
    ? 'Bluetooth no respondio a tiempo.'
    : 'No se pudo conectar. Revisa Bluetooth, permisos y el prototipo.';
```

Se perdian asi tres causas que el codigo ya detectaba pero no comunicaba:
`Permisos Bluetooth denegados.`, `Bluetooth esta apagado.` y
`No se encontro el puente BoviSense.`. Ademas los estados
`Esp32BleBridgeState.adapterOff` y `permissionDenied` existian en el enum pero
nunca se usaban, asi que la pantalla no podia distinguir nada.

### Correcciones aplicadas

**Servicio (`esp32_ble_bridge_service.dart`)**

- Nuevo `enum Esp32BleBridgeFailure` (`bluetoothOff`, `bluetoothUnavailable`,
  `permissionDenied`, `deviceNotFound`, `bluetoothBusy`, `connectionFailed`) y
  `BleConnectException`, con `failureForAdapterState()` y `failureMessage()`
  (textos sin tecnicismos, listos para el ganadero).
- `_ensureBluetoothPermissions()` y `_ensureBluetoothOn()`: piden permisos y
  exigen el adaptador encendido, esperando si esta en `turningOn`/`turningOff`.
- `_watchAdapter()` se suscribe desde el constructor: si el Bluetooth se apaga
  (incluso en medio de un conteo), la pantalla de Conteo avisa y se recupera
  sola cuando el usuario lo vuelve a encender.
- `requestBluetoothEnable()` usa `FlutterBluePlus.turnOn()` (Android muestra su
  propio dialogo del sistema).
- **Deteccion de "Bluetooth ocupado":** al no encontrar el equipo o al fallar
  la conexion se consultan los dispositivos conectados. El plugin BLE solo ve
  conexiones GATT (`systemDevices`), por lo que se agrego el canal nativo
  `bovisense/bluetooth` (`connectedAudioDeviceNames`) que consulta
  `BluetoothManager.getConnectedDevices(A2DP/HEADSET)` para audifonos,
  parlantes y manos libres.

**Pantalla (`estado_dispositivo_page.dart`)**

- La tarjeta de error usa el motivo real: "Activa el Bluetooth", "Falta el
  permiso de Bluetooth", "El Bluetooth está ocupado", "No se encontró el
  equipo", etc.
- Acciones directas: "Activar Bluetooth" (pide encender y continua la conexion),
  "Abrir ajustes del teléfono" (permisos o Bluetooth bloqueado por el
  fabricante) y "Reintentar".
- Cuando el Bluetooth esta ocupado se listan los dispositivos detectados
  ("Bluetooth en uso por: ...") y se explica que BoviSense necesita el
  Bluetooth para el equipo de conteo.

**Android (`MainActivity.kt`)** — canal `MethodChannel` con la consulta de
perfiles de audio, protegido por `BLUETOOTH_CONNECT` (ya declarado en el
manifiesto) y con retorno vacio si no hay permiso o soporte.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 20/20 (nuevo `test/ble_failure_test.dart`: traduccion del estado del adaptador y textos de cada falla) |
| `cd frontend && flutter build apk --debug` | APK generado; valida que el Kotlin del canal nativo compila |

### Pendiente de validar en el telefono real

- Bluetooth apagado desde antes de abrir la pantalla de conteo.
- Permiso de "Dispositivos cercanos" denegado.
- Audifonos o parlantes conectados mientras se intenta conectar.
- Equipo de conteo apagado (debe decir "No se encontró el equipo", no un
  error generico).

## 15. Continuacion 2026-09-22 (noche): estado pegado despues de guardar

### Sintoma

El conteo terminaba, el ganadero pulsaba "Guardar" y se guardaba bien. Pero al
volver a la pestaña Conteo seguia apareciendo "Resultado listo para guardar" con
el boton "Guardar" del conteo ya guardado, mas un error viejo de conexion al
backend. El usuario pidio que al volver se reinicie todo y se vea la secuencia
de un conteo nuevo.

### Diagnostico

Las pestañas del ganadero viven en un `IndexedStack` (`ganadero_nav.dart`), asi
que `EstadoDispositivoPage` **no se recrea** al cambiar de pestaña y tampoco su
`Esp32BleBridgeService` (que es un provider de la sesion). Dos estados
sobrevivian al guardado:

1. `_latestCountStatus` seguia siendo el `STOPPED` con prueba final, asi que
   `finalResult` continuaba verdadero y la vista mostraba el resultado y el
   boton "Guardar" otra vez (el backend lo trataba como idempotente, pero al
   usuario le hace dudar si se guardo o no).
2. `GanaderoViewModel.errorMessage` conservaba el fallo de la recarga del panel
   e historial que ocurre despues de guardar (`registrarConteoReal` llama a
   `loadDashboard`, `loadHistorial` y `loadAlertas`), y esa pestaña lo mostraba
   como si fuera del conteo actual.

### Correcciones aplicadas

- `Esp32BleBridgeService.resetCountSession()`: cancela el sondeo, descarta la
  instantanea del conteo y limpia el error y la falla de conexion. Se conserva
  el estado del receptor (`latestJetsonStatus`) para que el paso 2 siga
  completado y el ganadero solo tenga que pulsar "Iniciar".
- `_saveCountResult()` limpia el conteo **solo cuando el guardado fue exitoso**;
  si falla, el resultado sigue en pantalla para poder reintentar. Ademas
  limpia `_bridgeError` y `vm.errorMessage`, y el aviso pasa a ser
  "Conteo guardado. Ya puedes iniciar uno nuevo."
- Al volver a Conteo, el flujo muestra un estado verde: "Listo para un conteo
  nuevo" + tarjeta "Conteo guardado / Revisa el historial para ver el detalle".
- "Repetir" paso a llamarse "Nuevo conteo" y ahora pide confirmacion, porque
  descartaba un resultado todavia no guardado (perdida de datos silenciosa).
- `_watchAdapter()` quedo defensivo (`onError` y `try`), para que el servicio no
  falle en plataformas sin Bluetooth.

### Criterio de diseño para usuarios no tecnicos

- Nunca dejar en pantalla una sesion ya guardada: al guardar, limpiar el estado.
- Nunca iniciar un conteo de forma automatica: siempre lo decide el usuario.
- Confirmar antes de descartar datos (resultado sin guardar).
- El historial es el lugar donde el ganadero verifica que quedo registrado; por
  eso tras guardar se navega a esa pestaña.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 20/20 |
| `dart format` sobre los archivos tocados | sin cambios pendientes |

## 16. Auditoria de la vista ganadero (2026-09-22, cierre)

Revision completa de la vista ganadero: pantallas, `GanaderoViewModel`,
`GanaderoRepository`, modelos y las rutas del backend que consumen.

### Fallas encontradas y corregidas

1. **Historial y alertas cortados en 30 registros.** El backend respondia
   siempre `next_cursor: null` en la primera pagina, asi que `hasMoreHistorial`,
   `hasMoreAlertas` y los botones "Cargar mas" de la app eran codigo muerto: los
   conteos viejos eran inalcanzables. Ahora `listOwnedMerged()` pagina con un
   cursor real (fecha del ultimo registro en ISO) sobre la mezcla de
   subcoleccion + coleccion heredada, y nunca parte un grupo que comparte la
   misma fecha. Cubierto con prueba de integracion de tres paginas.
2. **Las alertas no se mostraban en ninguna pantalla.** `loadAlertas`,
   `vm.alertas` y `marcarAlertaLeida` existian, pero el ganadero solo veia el
   contador "Alertas pendientes": no habia forma de leerlas ni de marcarlas. Se
   agrego la seccion "Alertas" en la pestana Historial (tipo, nivel, fecha,
   etiqueta "Nueva", "Marcar como leida" y "Cargar mas"), y en el panel un aviso
   con boton "Ver alertas" cuando hay pendientes.
3. **Marcar una alerta como leida solo funcionaba en la subcoleccion nueva**:
   las alertas heredadas devolvian 404. Ahora usa `getOwnedDoc`, que verifica la
   propiedad en ambas ubicaciones.
4. **Se podia intentar contar sin finca configurada** y el backend respondia con
   un error tecnico. La pantalla de conteo ahora muestra "Falta configurar tu
   finca" con el boton "Configurar finca" antes de ofrecer el flujo.
5. **El historial decia "Lote principal" en todos los conteos** (texto heredado
   del mock). Ahora muestra el estado real del conteo.
6. **El panel decia siempre "Conecta el equipo"** porque `estado_conexion` del
   backend nunca pasa a `conectado`. Ahora usa el estado BLE real
   (`Esp32BleBridgeService.isConnected`), asi que tras conectar muestra "El
   equipo esta listo".
7. **La cantidad esperada no tenia tope en el formulario** (el backend acepta
   1..1.000.000): se agrego la validacion local con mensaje claro.
8. **El detalle del conteo no permitia reintentar** ante un fallo de red, y
   mostraba solo el numero. Ahora trae fecha, cantidad esperada y resumen, con
   botones "Reintentar" y "Volver".
9. **Datos viejos tras horas con el telefono bloqueado**: al reanudar la app se
   recarga el panel automaticamente.
10. Higiene: los identificadores se codifican en la URL (`conteos/:id`,
    `alertas/:id/leer`) y se elimino un `TextEditingController` vestigial de la
    pantalla de conteo.

### Fallas detectadas y NO corregidas (recomendaciones antes de produccion)

- **Publicacion Android:** `applicationId` de ejemplo y firma debug en release
  (ver seccion 6.5). Cambiarlo exige actualizar `google-services.json`.
- **Sin modo sin conexion:** si el telefono se queda sin internet no se puede
  guardar el conteo (el conteo en si va por BLE/LoRa, pero la prueba final se
  verifica en el backend). Recomendado: guardar localmente el resultado firmado
  pendiente y reintentar al recuperar red.
- **Sin notificaciones push (FCM):** las alertas solo se ven al abrir la app. Un
  faltante alto deberia notificar al ganadero.
- **Una sola finca por usuario:** la configuracion es por usuario, no por finca;
  un ganadero con varias fincas necesitaria varias cuentas.
- **`GanaderoViewModel.errorMessage` es unico para las cuatro pestanas:** un
  fallo de red de una pantalla se puede ver en otra. Conviene separarlo por caso
  de uso (panel, finca, conteo, historial).
- **`COUNT_MAX_DURATION_SEC = 600` en la Jetson:** confirmar con el usuario si 10
  minutos alcanzan para su operacion real.
- **Credenciales:** rotar la clave del hotspot que estuvo en el arbol de trabajo
  y revisar el `.codex` heredado antes de compartir el repositorio.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 22/22 (nuevo `test/alert_item_test.dart`) |
| Integracion backend con emuladores | 8/8 (nuevas: paginacion del historial y alerta heredada marcada como leida) |
| `cd jetson && python3 -m unittest test_secure_protocol.py` | 21/21 (sin cambios en esta sesion) |
| `dart format` sobre los archivos tocados | sin cambios pendientes |

## 17. Auditoria de la vista administrador (2026-09-22, cierre)

Revision de `AdminDashboardPage`, `UsuarioFormPage`, `AdminUsuariosViewModel`,
`AdminUsuarioRepository`, `UsuarioModel` y las rutas `/api/admin/usuarios`.

### Fallas encontradas y corregidas

1. **Busqueda y filtros ciegos a la paginacion.** La app filtraba localmente
   solo los usuarios cargados (30). Buscar a alguien de la segunda pagina
   devolvia "Sin coincidencias" aunque existiera, asi que el administrador no
   podia editarlo ni darlo de baja. Ahora, al escribir o filtrar, se cargan las
   paginas restantes bajo demanda (`loadRemainingUsers`, tope 10 paginas), se
   avisa cuando todavia quedan sin cargar y la busqueda incluye la cedula.
2. **Orden arbitrario de la lista.** `page()` ordenaba por identificador de
   documento (el uid, un hexadecimal aleatorio), asi que la lista cambiaba sin
   sentido. Ahora se ordena alfabeticamente por `nombre` (`page()` acepta
   direccion `asc`/`desc`).
3. **`operacion_pendiente` invisible y mensaje enganoso.** Un usuario con una
   operacion administrativa a medias queda bloqueado, pero el backend
   respondia "El usuario está inactivo." y el administrador no veia la causa ni
   la solucion. Ahora el 403 dice "Tu cuenta tiene una operación pendiente de un
   administrador", `UsuarioModel` expone el campo y la tarjeta lo marca con la
   indicacion de volver a guardar los mismos datos para completarla.
4. **Autoborrado y autodegradacion.** El administrador podia intentar eliminar
   su propia cuenta o quitarse el rol (el backend lo rechazaba con un error
   confuso). Ahora su tarjeta no muestra "Eliminar", se etiqueta "Tu cuenta" y
   el formulario bloquea rol/estado al editarse a si mismo, con una nota.
5. **Sin resumen del sistema** (y `AdminStatCard` era codigo muerto). El backend
   devuelve conteos reales con agregaciones (`total`, `activos`, `inactivos`,
   `administradores`) solo en la primera pagina, y el panel los muestra.
6. **Riesgo en las pruebas.** Con el `.env` real configurado, un POST a
   `/api/admin/usuarios` desde las pruebas habria enviado correos de activacion
   reales. La suite de integracion ahora vacia `SMTP_*` antes de cargar la app.

### Supuestos y recomendaciones

- **Todo usuario tiene `nombre`.** El orden alfabetico excluye de la lista a
  cualquier documento sin ese campo. Es seguro porque la API lo exige al crear y
  actualizar; si alguna vez se cargan usuarios por fuera, hay que revisarlo.
- **Busqueda en servidor:** hoy se resuelve cargando paginas. Si el sistema
  llegara a cientos de usuarios, conviene mover la busqueda al backend (prefijo
  sobre `correo`, exacto por cedula via `CedulasUsuarios`).
- **Sin registro de auditoria administrativa:** `OperacionesUsuarios` guarda el
  estado de cada operacion, pero no hay historial de "quien cambio que y
  cuando". Para produccion conviene agregarlo.
- **Sin doble confirmacion** al desactivar una cuenta o cambiar un rol (solo al
  eliminar). Es reversible, asi que quedo como decision de producto.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 26/26 (nuevo `test/admin_usuarios_test.dart`) |
| Integracion backend con emuladores | 10/10 (nuevas: orden + resumen + paginacion del listado, operacion pendiente) |
| `cd backend && npm test` | en verde |
| `dart format` sobre los archivos tocados | sin cambios pendientes |

## 18. Ajustes de presentacion en movil (2026-09-22)

Pedido del usuario tras ver el panel en un telefono: las tarjetas de metricas se
veian mal y el saludo mostraba los dos apellidos.

- **Metricas del panel de administracion.** Se quitaron las cuatro tarjetas
  (`AdminStatCard` ocupaba media pantalla y empujaba la lista de usuarios fuera
  de vista). En su lugar queda **una sola linea discreta** bajo los filtros:
  `5 usuarios · 5 activos · 0 inactivos · 1 admin`, con los conteos reales que
  ya devuelve el backend.
- **Saludo corto.** Nuevo `UsuarioModel.nombreCorto`: nombre + apellido paterno
  ("Rover Serrano"). Se usa en el panel del ganadero y en el del administrador.
  La regla del modelo es un nombre y dos apellidos (paterno y materno), asi que
  el saludo toma solo la primera palabra de `apellidos`. El nombre completo se
  mantiene donde importa identificar a la persona: tarjeta de usuario, tarjeta
  de identidad del formulario y dialogo de eliminacion.
- **Formulario.** El campo "Apellidos" ahora muestra la ayuda "Apellido paterno
  y materno".
- **Codigo muerto eliminado:** `usuario_home_page.dart` (pantalla marcador de
  posicion que ya no se referenciaba) y `admin_stat_card.dart` (quedo sin uso al
  quitar las tarjetas). Recuperables con `git show <commit>:<ruta>`.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 27/27 (nueva: saludo con nombre y apellido paterno) |
| `dart format` sobre los archivos tocados | sin cambios pendientes |

## 19. Confirmacion de salida en la vista administrador (2026-09-22)

Pedido: al pulsar el boton retroceder nativo en el panel del administrador debe
aparecer el mismo mensaje "¿Salir de BoviSense?" que ya existia en la vista
ganadero. Antes, en administrador el retroceso cerraba la aplicacion sin avisar.

### Cambios

- Nuevo `lib/views/common/exit_confirm.dart` con el dialogo compartido:
  `confirmExitApp()` (devuelve si el usuario confirmo), `confirmAndExitApp()` y
  `ExitConfirmGuard` (envuelve la pantalla raiz con `PopScope(canPop: false)`).
- `AdminDashboardPage` ahora usa `ExitConfirmGuard`, asi que el boton
  retroceder pide confirmacion antes de cerrar.
- `GanaderoShellPage` reutiliza el mismo componente: conserva su logica propia
  (`onBack` vuelve a la pestana Inicio y, en Inicio, delega la confirmacion).
- El dialogo esta protegido contra aperturas repetidas si el usuario insiste
  con el boton retroceder.
- El guard solo afecta a la ruta raiz del rol: las pantallas apiladas (por
  ejemplo `UsuarioFormPage`) se siguen cerrando con el retroceso normal.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 29/29 (nuevo `test/exit_confirm_test.dart`: simula el retroceso nativo con `handlePopRoute`, verifica el dialogo y que `onBack` puede manejarlo) |
| `dart format` sobre los archivos tocados | sin cambios pendientes |

## 20. Revision de presentacion, inicio de sesion y commit (2026-09-22, cierre final)

### Presentacion (splash)

- Antes esperaba **siempre 1,7 s** aunque la aplicacion estuviera lista: un
  retraso artificial en cada arranque. Ahora sale cuando termina la
  inicializacion de la sesion, con un minimo de 1,2 s para que la marca se vea y
  un maximo de 4 s como red de seguridad (nunca deja la app atrapada).
- Los temporizadores se cancelan en `dispose` (antes quedaba uno vivo) y la
  regla de salida quedo en `AppSplashScreen.isReady()`, con prueba unitaria.

### Inicio de sesion

- `launchUrl` estaba sin proteccion: en Android, si WhatsApp o el marcador no
  estan instalados, lanza `PlatformException` en lugar de devolver `false`, y el
  error se propagaba sin aviso. Ahora se captura y se informa al usuario.
- El error de credenciales se mostraba solo en un `SnackBar` que desaparece y
  puede quedar tapado por el teclado. Ahora aparece **dentro de la tarjeta**,
  sobre el boton, y se limpia cuando el usuario vuelve a escribir.
- Tras un inicio de sesion correcto se llama a `TextInput.finishAutofillContext()`
  para que el telefono ofrezca guardar las credenciales.
- El contacto de soporte (telefono y WhatsApp) salio del archivo de la pantalla
  a `AppConfig`, y el enlace de WhatsApp se construye con `Uri` en lugar de una
  cadena pre-codificada a mano.
- **Cerrar sesion ahora pide confirmacion** (antes cerraba directamente).

### Codigo muerto

- Se eliminaron `AuthViewModel.restoreSession()` y
  `AuthRepository.restoreSession()`: no se llamaban en ningun punto. La
  aplicacion **cierra a proposito la sesion persistida en cada arranque**
  (`initializeSession` -> `discardPersistedSession`), una decision de seguridad
  para un telefono compartido en el campo; si en el futuro se quiere recordar la
  sesion, esa es la funcion a reactivar.

### Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `cd frontend && flutter analyze` | sin hallazgos |
| `cd frontend && flutter test` | 32/32 (nuevo `test/auth_views_test.dart`: reglas del splash, enlace de WhatsApp y confirmacion de cierre de sesion) |
| `cd frontend && flutter build apk --debug` | APK generado |

### Commit

Todo el trabajo de esta sesion quedo en la rama `dev` en un unico commit
"Corrige flujo de conteo, alertas y vistas de ganadero y administrador"
(93 archivos). Queda fuera del repositorio `revicion.txt`, que es una nota
personal de trabajo: no esta versionado ni forma parte de la aplicacion.
