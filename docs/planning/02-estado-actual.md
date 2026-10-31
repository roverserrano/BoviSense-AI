# 02 — Estado actual verificado

Fase 3 de la skill (`Verificación`). Cada afirmación distingue **implementación**
(existe en el código) de **validación** (existe prueba que lo ejercita) y de
**verificación en hardware** (solo comprobable con el equipo físico).

## 1. Resumen por módulo

| Módulo | Implementación | Pruebas automatizadas | Verificación en hardware |
|--------|----------------|----------------------|--------------------------|
| Backend (Node/Express) | Completa para el alcance documentado | 4 casos unitarios + 10 de integración con emuladores | Parcial: `/health` y `H` verificados en sesiones previas |
| App Flutter (Android) | Completa para el alcance documentado | 32 casos (analyze sin hallazgos) | Parcial: flujo de conexión y conteo probado por el usuario en campo |
| Puente ESP32 | Sketch presente; sin binario versionado | Ninguna | No verificable: se desconoce la versión grabada |
| Jetson (radio y sesión) | Completa para el alcance documentado | 21 casos unitarios | Parcial: log de arranque de la sesión anterior citado en `AGENTS.md` §4 |
| Jetson (detección y tracking) | Tracker implementado; detector preexistente | Ninguna prueba automatizada del worker | Bloqueada: requiere cámara, engine y vuelo real |

## 2. Estado por componente

### 2.1 Backend

| Área | Estado | Evidencia |
|------|--------|-----------|
| Autenticación y autorización por rol | Implementada y ejercitada | `backend/test/integration/api.test.js` (401/403), `backend/src/middlewares/authMiddleware.js` |
| Validación estricta de entradas | Implementada y ejercitada | `backend/test/security.test.js` (4 casos) |
| Alta/edición/baja de usuario idempotente | Implementada y ejercitada | `backend/test/integration/api.test.js` (serialización de cédulas, fallo de SMTP) |
| Protocolo C1/R1 (emisión y verificación) | Implementado y ejercitado | `backend/test/security.test.js`, integración del ciclo completo `H→S→Q→T` |
| Conteo real con prueba firmada | Implementado y ejercitado | `POST /api/ganadero/conteos` en integración; rechazo de conteo parcial |
| Paginación de historial y alertas | Implementada y ejercitada | Test de 3 páginas con cursor |
| Compatibilidad con colecciones heredadas | Implementada, **sin prueba específica** | `backend/src/controllers/ganaderoController.js:127-221` |
| Despliegue serverless (Vercel) | Configurado, **sin evidencia de despliegue** | `backend/vercel.json`, `backend/api/index.js` |

### 2.2 App Flutter

| Área | Estado | Evidencia |
|------|--------|-----------|
| Login, roles y ciclo de sesión | Implementado; probado manualmente | `frontend/lib/data/repositories/auth_repository.dart`, `AGENTS.md` §5 |
| Flujo de conteo por pasos | Implementado; sin prueba de UI completa | `frontend/lib/views/ganadero/estado_dispositivo_page.dart` |
| Sondeo de conteo con retroceso | Implementado y ejercitado | `frontend/test/command_queue_test.dart`, código de `_pollDelay` |
| Fallas de Bluetooth tipadas | Implementado y ejercitado | `frontend/test/ble_failure_test.dart` |
| Alertas visibles y marcables | Implementado y ejercitado | `frontend/test/alert_item_test.dart`, integración backend |
| Panel de administración (búsqueda, orden, resumen, autoedición protegida) | Implementado y ejercitado | `frontend/test/admin_usuarios_test.dart`, integración backend |
| Splash, confirmación de salida y logout | Implementados y ejercitados | `frontend/test/auth_views_test.dart`, `frontend/test/exit_confirm_test.dart` |
| `applicationId` y firma de release | **Pendiente** | `frontend/android/app/build.gradle.kts:27,44-47` |
| Modo sin conexión | **No implementado** | Sin caché en `frontend/lib/data/services/api_client.dart` |

### 2.3 Puente ESP32

| Área | Estado | Evidencia |
|------|--------|-----------|
| BLE `BoviSense-Bridge` con servicio y características | Implementado en el sketch | `.ino:31-34` |
| Filtro de tramas: solo `C1\|` desde BLE | Implementado | `.ino:245-249` |
| Radio 433 MHz, SF7, BW 125 kHz, CR 4/5, CRC, SyncWord `0xF3` | Implementado | `.ino:39-47` |
| Trama de error `B0\|...` con razones tipadas | Implementada y consumida por la app | `.ino:161,178,250,328` |
| Versión grabada en el prototipo | **No verificable desde el repositorio** | Sin binario versionado |

### 2.4 Jetson — radio, sesión y protocolo

| Área | Estado | Evidencia |
|------|--------|-----------|
| Bloqueo exclusivo del SPI | Implementado y ejercitado | `jetson/test_secure_protocol.py` (`test_only_one_receiver_can_own_spi`) |
| Autenticación C1 y firma R1 | Implementadas y ejercitadas | `jetson/test_secure_protocol.py` (autenticación, manipulación, expiración) |
| Antirreplay persistente en SQLite | Implementado y ejercitado | `test_replay_is_durable_and_never_reexecutes` |
| `IDLE` cuando no hay sesión | Implementado y ejercitado | 4 casos nuevos (`status`/`stop`/`result`) |
| RST sin control por GPIO | Implementado | `AGENTS.md` §4 y §10; script sin `libgpiod`/`Jetson.GPIO` |
| **Camino de comando heredado sin autenticación** | **Presente en el código** | `jetson/lora_jetson_rx.py:1398-1459` (ver conflicto `C-01`) |
| Sesión real completa `S→Q→T` en hardware | **No verificada** | `AGENTS.md` §6.2 |

### 2.5 Jetson — detección y tracking

| Área | Estado | Evidencia |
|------|--------|-----------|
| Captura CSI/TensorRT preexistente | Implementada; **bloqueada por errores Argus/GStreamer** | `AGENTS.md` §6.1 |
| Contador por identidad de track | Implementado; validado con harness manual, no con video | `jetson/run_bovino.py` (`_count_confirmed_track`), verificación de esta sesión |
| Compensación de movimiento global (ORB) | Implementada; verificada con datos sintéticos | Prueba del harness adjunta en `docs/arquitectura/*` |
| BoT-SORT con la librería `trackers` | Implementado; **sin evidencia de ejecución** (librería no instalada en el entorno observado) | `jetson/run_bovino.py:1438-1439,1973-1978` |
| Modo sin tracker (`--tracker none`) | Implementado; ejercitado en harness | `jetson/run_bovino.py:1921-1990` |
| ReID con CNN | **No implementado** (correcto según la especificación) | `jetson/run_bovino.py`; existe heurística HSV, ver `C-07` |
| Publicación `COUNT_UPDATE`/`COUNT_FINAL` | Implementada; sin prueba | `jetson/run_bovino.py:103-155` |

## 3. Estado del repositorio y de la documentación

| Aspecto | Estado | Evidencia |
|---------|--------|-----------|
| Rama de trabajo | `dev`; `main` integra con merges | `git branch`, historial |
| Árbol de trabajo | **Sucio**: `AGENTS.md`, `README.md` y `jetson/run_bovino.py` modificados; `docs/`, `.agents/`, `skills-lock.json` y `jetson/tracking.md` sin seguimiento | `git status --short` |
| Documentación técnica | Generada y commiteada parcialmente: `docs/codebase/` y `docs/arquitectura/` están sin commitear | `git status` |
| Documentación histórica | Intacta: `revicion.txt`, `pasos.txt`, `.codex`, `AGENTS.md` (con adiciones) | Sin cambios destructivos en esta sesión |
| CI/CD | **No existe** | `docs/codebase/.codebase-scan.txt` (`No CI/CD pipelines detected`) |
| Reglas de Firestore | Configuradas; sin evidencia de despliegue | `firestore.rules`, `AGENTS.md` §6 |

## 4. Lo que NO se puede afirmar

Para evitar clasificar sin evidencia:

- No se puede afirmar que el firmware del ESP32 en el prototipo coincida con el
  sketch del repositorio.
- No se puede afirmar que la instalación de la Jetson ejecute la misma versión de
  `lora_jetson_rx.py` y `run_bovino.py` que el repositorio.
- No se puede afirmar que BoT-SORT esté funcionando en la Jetson: en el entorno
  analizado la librería `trackers` no está disponible y el sistema degrada al
  tracker interno.
- No se puede afirmar rendimiento, latencia ni tasa de acierto del conteo real.
- No se puede afirmar que las reglas de Firestore estén desplegadas en
  producción.
- No se puede afirmar que el despliegue en Vercel esté activo.

## 5. Evidencia

- `git status --short`, `git log --oneline -1`
- Ejecuciones de prueba documentadas en `AGENTS.md` §8, §10-§20 y en
  `docs/codebase/TESTING.md`
- Lectura directa de los archivos citados en cada tabla
