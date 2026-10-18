# Módulos, dependencias y contratos públicos

Un apartado por artefacto desplegable. Cada módulo declara: responsabilidad,
punto de entrada, contratos públicos, dependencias y evidencia.

## 1. Backend (API REST)

| Aspecto | Detalle |
|---------|---------|
| Responsabilidad | Identidad y roles, configuración de finca, emisión/verificación de tramas IoT, conteos, alertas y envío de credenciales |
| Punto de entrada | `backend/src/app.js` (servidor local) y `backend/api/index.js` (función serverless) |
| Runtime | Node.js 22-24 |
| Contratos públicos | HTTP (`docs/arquitectura/api-http.md`) y trama firmada C1 (salida) / R1 (entrada) |
| Dependencias internas | `config/firebaseAdmin.js`, `utils/validation.js`, `utils/pagination.js`, `utils/passwordGenerator.js` |
| Dependencias externas | Firebase Admin (Auth + Firestore), SMTP vía nodemailer |
| Evidencia | `backend/src/app.js:59-68`, `backend/package.json:20-28` |

### Servicios de dominio y contratos

| Servicio | Contrato público | Evidencia |
|----------|------------------|-----------|
| `iotProtocol` | `COMMANDS`, `STATES`, `secretKey()`, `sign()`, `commandFrame()`, `responseFrame()` | `backend/src/services/iotProtocol.js:52` |
| `iotService` | `createIotService(db)` → `{ issue(uid, input), verify(uid, raw) }` | `backend/src/services/iotService.js:5,105` |
| `userService` | `createUserService({ db, auth, FieldValue, enviarActivacion })` → `{ execute(uid, action, payload, actor) }` | `backend/src/services/userService.js:5,110` |
| `mailService` | `enviarActivacion({ correo, nombreCompleto, enlace })` | `backend/src/services/mailService.js:3` |
| `validation` | `HttpError`, `object`, `text`, `integer`, `documentId`, `hexId`, `respondError` | `backend/src/utils/validation.js:56` |
| `pagination` | `page(collection, query, sortField, direction)` | `backend/src/utils/pagination.js:3,19` |

### Comportamiento transaccional relevante

- El alta/edición/baja de usuario es una **operación con huella y lease**:
  `fingerprint = sha256({action, payload})`, estado `pending` con `lease_until`
  de 5 minutos y resultado `done` reutilizable
  (`backend/src/services/userService.js:13-35`).
- El **lease del dispositivo** dura 900 s y es por usuario
  (`backend/src/services/iotService.js:51`); `S` con lease activo del mismo
  usuario se degrada a `Q` (`iotService.js:37-41`).

## 2. Aplicación Flutter (Android)

| Aspecto | Detalle |
|---------|---------|
| Responsabilidad | Autenticación, panel de ganadero (finca, conteo, historial, alertas) y panel de administrador (usuarios) |
| Punto de entrada | `frontend/lib/main.dart:21` (`main()`), enrutado de rol en `frontend/lib/views/auth_gate.dart:11-33` |
| Contratos públicos | Consume la API HTTP y BLE; no expone API propia |
| Dependencias internas | `core/` (config, tema, utilidades), `data/` (modelos, repositorios, servicios), `viewmodels/`, `views/` |
| Dependencias externas | Firebase (Core/Auth/Firestore), HTTP, `flutter_blue_plus`, `permission_handler`, `url_launcher` |
| Evidencia | `frontend/pubspec.yaml:13-23`, `frontend/lib/main.dart:127-160` |

### Contratos de los servicios de datos

| Componente | Contrato | Evidencia |
|------------|----------|-----------|
| `ApiClient` | `get/post/put/delete(path[, body])`, `connectionHelp(origin)`, `close()`; valida HTTPS salvo host local | `frontend/lib/data/services/api_client.dart:25-97,182-196` |
| `Esp32BleBridgeService` | `scanAndConnect()`, `sendCommand(cmd)`, `requestCountingStatus()`, `resetCountSession()`, `pausePolling()/resumePolling()`, `failure`, `otherBluetoothDevices` | `frontend/lib/data/services/esp32_ble_bridge_service.dart` |
| `GanaderoRepository` | `obtenerDashboard`, `guardarConfiguracion`, `registrarConteoReal({proof, sessionId})`, `listarConteos/Alertas(cursor)`, `obtenerConteoDetalle`, `marcarAlertaLeida`, `issueCommand`, `verifyResponse` | `frontend/lib/data/repositories/ganadero_repository.dart` |
| `AdminUsuarioRepository` | `listarUsuarios({cursor})`, `crearUsuario`, `actualizarUsuario`, `eliminarUsuario`, `nextCursor`, `resumen`, `creationNotice` | `frontend/lib/data/repositories/admin_usuario_repository.dart` |
| `AuthRepository` | `signIn`, `signOut`, `changePassword`, `sendPasswordResetEmail`, `discardPersistedSession` | `frontend/lib/data/repositories/auth_repository.dart` |

### Estado de sesión en la app

Los providers se reconstruyen por `uid` con `KeyedSubtree`
(`frontend/lib/main.dart:127-135`), el servicio BLE pausa su sondeo al pasar la
app a segundo plano y lo reanuda al volver, y la sesión se cierra en
`detached` (`frontend/lib/main.dart`, `_AppLifecycleSessionGuard`).

## 3. Receptor de la Jetson (`lora_jetson_rx.py`)

| Aspecto | Detalle |
|---------|---------|
| Responsabilidad | Único propietario del SPI/SX1278, autenticación C1/R1, antirreplay, sesión de conteo y supervisión del worker |
| Punto de entrada | `jetson/lora_jetson_rx.py:1451` (`main()`), con argparse completo (`:1307`) |
| Contratos públicos | Trama R1 por LoRa; archivos/logs del worker por stdout y JSON |
| Dependencias internas | `jetson/secure_protocol.py` |
| Dependencias externas | `spidev`, radio SX1278 por SPI, subproceso `run_bovino.py` |
| Evidencia | `jetson/lora_jetson_rx.py:20-63,251-272,1213-1245,1451` |

### Parámetros de operación por defecto

| Parámetro | Valor | Evidencia |
|-----------|-------|-----------|
| Bus/dispositivo SPI | `0` / `0`, 10 kHz | `jetson/lora_jetson_rx.py:20-22` |
| Bloqueo de exclusividad | `fcntl.flock` en `/run/bovisense-spidev0.0.lock` | `jetson/lora_jetson_rx.py:23,251-272` |
| Worker | `python3 run_bovino.py` en `env_detection` con `--engine`, `--source csi://0`, 1920x1080 a 30 fps | `jetson/lora_jetson_rx.py:48-58` |
| Límites | 600 s por sesión, 8 s de espera al detener | `jetson/lora_jetson_rx.py:61-62` |
| Frecuencia | 433 MHz, SF7, BW 125 kHz, CR 4/5, CRC on, SyncWord `0xF3`, TX 17 dBm | `jetson/lora_jetson_rx.py` (constantes de radio) |
| GPIO de reset | Eliminado; RST puenteado a 3.3 V y `PIN_DIO0 = 31` solo documental | `jetson/lora_jetson_rx.py:33`, `AGENTS.md` sección 4 |

### Protocolo seguro (`secure_protocol.py`)

| Función | Contrato |
|---------|----------|
| `load_key()` | Exige `IOT_SHARED_SECRET` de 64 hex; lanza si falta |
| `parse_command(frame, key, now)` | Valida versión `C1`, id, comando, sesión, expiración (±5/65 s) y firma |
| `response_frame(...)` | Genera `R1` con firma truncada a 32 hex |
| `SecureProtocol.handle(frame, execute)` | Antirreplay con SQLite (`requests`, `results`), cachea la respuesta |
| `save_result/result` | Persistencia del resultado por sesión |

Evidencia: `jetson/secure_protocol.py:15-100`.

## 4. Worker de detección (`run_bovino.py`)

| Aspecto | Detalle |
|---------|---------|
| Responsabilidad | Capturar cámara, ejecutar el engine TensorRT, decodificar detecciones, rastrear identidades y contar |
| Punto de entrada | `jetson/run_bovino.py:2490` (`main()`), que arma hilos de captura, inferencia y dibujo |
| Contratos públicos | stdout (`WORKER_STATUS\|`, `COUNT_UPDATE\|`, `COUNT_FINAL\|`, `TRACK_METRIC\|`, `INFERENCE_METRIC\|`, `PIPELINE_METRIC\|`, `TRACK_FINAL\|`) y archivos JSON opcionales |
| Dependencias internas | Tracker interno y GMC propios; helpers de cajas |
| Dependencias externas | TensorRT, CUDA, OpenCV, numpy, y opcionalmente `trackers` + `supervision` |
| Evidencia | `jetson/run_bovino.py:26-28,103-174`, `create_tracker` en `:1928` |

### Selección de tracker

| `--tracker` | Motor efectivo | GMC | Cuándo usarlo |
|-------------|----------------|-----|---------------|
| `botsort` (por defecto) | `BoTSORTTracker` de la librería | Sí (ORB/ECC/sparseOptFlow) | Escenario real con dron en movimiento |
| `bytetrack` | `ByteTrackTracker` | No | Línea base de comparación |
| `ocsort` | `OCSORTTracker` | No | Comparación con foco en oclusiones |
| `simple` | `PersistentBovineTracker` interno | ORB propio | Respaldo sin dependencias externas |
| `none` | `LegacyUniqueBovineTracker` | No | Reproducir el comportamiento previo, sin tracking |

Evidencia: `jetson/run_bovino.py:1928-2005` y `--tracker` en `:2521`.

## 5. Puente ESP32

| Aspecto | Detalle |
|---------|---------|
| Responsabilidad | Anunciarse por BLE, recibir tramas del teléfono y retransmitirlas por LoRa; devolver la R1 por BLE |
| Punto de entrada | `setup()` y `loop()` del sketch |
| Contratos públicos | Servicio BLE `7d2f0001-…`, RX `…0002`, TX `…0003`; nombre `BoviSense-Bridge` |
| Seguridad | No conoce la clave; solo verifica prefijo `C1\|` y longitudes |
| Evidencia | `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino:31-47,245-249` |

## 6. Documentación y herramientas del repositorio

| Elemento | Responsabilidad | Evidencia |
|----------|-----------------|-----------|
| `docs/` | Documentación técnica (este conjunto) y despliegue/seguridad | `docs/README.md`, `docs/seguridad-y-despliegue.md` |
| `AGENTS.md` | Bitácora de estado, incidentes y reglas de trabajo | `AGENTS.md` |
| `.agents/skills/` + `skills-lock.json` | Skills de análisis usadas para generar esta documentación | `skills-lock.json` |
| `comunicacion-iot/docs/`, `hardware/` | Protocolo y pinout del hardware | `comunicacion-iot/docs/flujo-comandos.md`, `hardware/pinout-sugerido.md` |

## 7. Evidencia consolidada

- `backend/src/**`, `frontend/lib/**`, `jetson/*.py`,
  `comunicacion-iot/**`, `docs/**`
- `git ls-files`, `find` y `rg` ejecutados durante el análisis (ver
  `docs/codebase/.codebase-scan.txt`)
