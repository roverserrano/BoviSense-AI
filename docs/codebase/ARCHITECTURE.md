# Architecture

## Core Sections (Required)

### 1) Architectural Style

| Módulo | Estilo real observado | Por qué (con evidencia) |
|--------|----------------------|--------------------------|
| Backend | **En capas**: rutas → controladores → servicios → Firebase Admin | `backend/src/routes/*.js` solo declara rutas y autorización; `backend/src/app.js:59-68` monta routers y el manejador de errores; la lógica de dominio vive en `services/` sin `req`/`res` (`backend/src/services/userService.js:5`) |
| App Flutter | **MVVM con repositorios**: vista → `ChangeNotifier` → repositorio → servicio | `frontend/lib/main.dart:127-160` (`_SessionScope` con `MultiProvider`) registra viewmodels y repositorios; los viewmodels extienden `SessionNotifier` (`frontend/lib/viewmodels/session_notifier.dart:3`) y las vistas consumen `context.watch<...ViewModel>()` |
| Jetson | **Dos procesos cooperativos**: receptor de radio (estado de sesión) + worker de inferencia | `jetson/lora_jetson_rx.py` lanza y supervisa el worker (`COUNT_SCRIPT_PATH`, `jetson/lora_jetson_rx.py:50`), lee sus archivos de estado y líneas de log (`jetson/lora_jetson_rx.py:993-998`) |
| ESP32 | **Relay opaco sin lógica de dominio** | El sketch solo valida prefijo y longitud de la trama y la reenvía (`bridge_hotspot_lora_discovery.ino:245-249`) |

No se observan patrones de Clean Architecture (no hay capas `domain/`,
`usecases/` ni inversión de dependencias con interfaces). Tampoco es un
monolito por capas único: son cuatro artefactos desplegables independientes
conectados por red (HTTP, BLE, LoRa) y por archivos (Jetson).

**Restricciones que moldean el diseño**

1. El puente BLE/LoRa es un canal lento y frágil (22 s de espera declarada,
   `bridge_hotspot_lora_discovery.ino:47`), por lo que el conteo se autoriza con
   tramas cortas firmadas y no con JSON de aplicación.
2. El teléfono no puede asumir que ve al backend: el enlace local (USB/HTTP) y el
   enlace a Firebase son canales distintos (`docs/seguridad-y-despliegue.md`).
3. La Jetson es la única que ve la cámara y el radio; su estado de sesión es
   volátil y debe reconciliarse con Firestore
   (`backend/src/services/iotService.js:100-102`).

### 2) System Flow

```text
App (login Firebase) -> token ID
        |
App -> POST /api/ganadero/iot/comandos  (backend valida rol + sesion)
        |
Backend -> trama C1 firmada (HMAC-SHA256, 60 s de validez)
        |
App -> BLE (fragmentos ~trama\n) -> ESP32 -> LoRa 433 MHz -> Jetson
        |
Jetson -> verifica firma + antirreplay (SQLite) -> ejecuta (H/P/S/T/Q/R)
        |
Jetson -> trama R1 firmada por LoRa -> ESP32 -> BLE -> App
        |
App -> POST /api/ganadero/iot/respuestas (backend verifica firma)
        |
App -> muestra estado; guarda conteo real con POST /api/ganadero/conteos (exige proof)
```

Pasos con evidencia:

1. La app pide el ticket y envía la trama por BLE:
   `frontend/lib/data/services/esp32_ble_bridge_service.dart` (`sendCommand`,
   escritura en fragmentos de 18 bytes).
2. El backend firma: `backend/src/services/iotProtocol.js:21-28`
   (`commandFrame`), y registra el ticket en `IotCommands`
   (`backend/src/services/iotService.js:63`).
3. El ESP32 solo reenvía: `bridge_hotspot_lora_discovery.ino:245-249`.
4. La Jetson autentica y ejecuta:
   `jetson/secure_protocol.py:26-48` (`parse_command`) y
   `jetson/lora_jetson_rx.py:1318-1345` (`execute_secure_command`).
5. La app verifica la respuesta antes de mostrarla:
   `frontend/lib/data/services/esp32_ble_bridge_service.dart` (llamada a
   `verifyResponse`) y `backend/src/services/iotService.js:69-103`.
6. El conteo solo se persiste con prueba final firmada:
   `backend/src/controllers/ganaderoController.js:329-333`.

### 3) Layer/Module Responsibilities

| Layer or module | Owns | Must not own | Evidence |
|-----------------|------|--------------|----------|
| `backend/src/routes` | Rutas, autorización por rol | Lógica de negocio, acceso a datos | `backend/src/routes/ganaderoRoutes.js:8-20` |
| `backend/src/controllers` | Traducción HTTP, validación de entrada, mapeo de documentos, transacciones | Criptografía, SMTP | `backend/src/controllers/ganaderoController.js:329-368` |
| `backend/src/services` | Protocolo IoT, máquina de operaciones de usuario, correo | Objetos HTTP | `backend/src/services/iotProtocol.js`, `userService.js` |
| `backend/src/middlewares` | Verificación de token y perfil | Reglas de negocio | `backend/src/middlewares/authMiddleware.js:57-103` |
| `frontend/lib/views` | Composición visual y navegación | Acceso a red | ninguna vista importa `package:http` (verificado) |
| `frontend/lib/viewmodels` | Estado de pantalla, carga/errores, orquestación | UI, transporte | `frontend/lib/viewmodels/ganadero_view_model.dart:40-55` |
| `frontend/lib/data/repositories` | Contratos con backend/Firebase, cursores de paginación | Estado de UI | `frontend/lib/data/repositories/ganadero_repository.dart:104-118` |
| `frontend/lib/data/services` | HTTP con token, BLE, cola de comandos, sondeo | Reglas de negocio | `frontend/lib/data/services/api_client.dart`, `esp32_ble_bridge_service.dart` |
| `jetson/*.py` | Radio, autenticación C1/R1, sesión y worker | Nada de la app ni del backend | `jetson/secure_protocol.py`, `jetson/lora_jetson_rx.py` |

### 4) Reused Patterns

| Pattern | Where found | Why it exists |
|---------|-------------|---------------|
| Repository | `frontend/lib/data/repositories/*` | Aislar la UI del transporte y centralizar cursores de paginación |
| Observer / ChangeNotifier + Provider | `frontend/lib/viewmodels/session_notifier.dart:3`, `frontend/lib/main.dart:141-160` | Reconstruir la UI sin gestión manual de estado |
| Dependency injection por árbol de widgets | `frontend/lib/main.dart:127-160` | Repositorios y viewmodels se destruyen al cambiar de sesión |
| Idempotencia por huella + lease | `backend/src/services/userService.js:12-34` | Evitar altas/ediciones duplicadas si el cliente reintenta |
| Antirreplay persistente | `jetson/secure_protocol.py:60-96` | Impedir que una trama reenviada se ejecute dos veces tras un reinicio |
| Estrategia (selección de tracker) | `jetson/run_bovino.py:1921-1985` (`create_tracker`) | Comparar BoT-SORT/ByteTrack/OC-SORT/interno sin tocar la inferencia |
| Filtro adaptativo (Kalman) + GMC | `jetson/run_bovino.py:1316-1326`, librería `trackers` | Compensar el movimiento del dron y mantener identidad temporal |
| Cola serializada | `frontend/lib/core/utils/command_queue.dart` | Evitar comandos BLE solapados entre el sondeo y el usuario |
| Degradación con aviso | `jetson/run_bovino.py:1973-1978` | Si la librería de tracking no está, sigue con el tracker interno y lo registra |
| Adaptador serverless | `backend/api/index.js:1-3` | Reutilizar la misma app Express en Vercel |

### 5) Known Architectural Risks

- **Estado de sesión en dos lugares.** La sesión viva existe en memoria de la
  Jetson y como documento en Firestore; al reiniciar el receptor se pierde la
  primera y hay que reconciliar (`backend/src/services/iotService.js:100-102`,
  documentado en `AGENTS.md` sección 12). Impacto: comandos que apuntan a
  sesiones inexistentes si la reconciliación falla.
- **Duplicación de rutas de usuario.** Existen `usuarioRoutes.js` y
  `usuarioRoute.js`; solo el primero está montado
  (`backend/src/app.js:59`). Impacto: editar el archivo equivocado no tiene
  efecto.
- **Acoplamiento de la app al formato del ticket.** La app reenvía la trama tal
  cual y valida que el `request_id` coincida
  (`frontend/lib/data/services/esp32_ble_bridge_service.dart`), así que cualquier
  cambio de protocolo exige desplegar app, firmware y receptor a la vez
  (`docs/seguridad-y-despliegue.md`).
- **Sin capa de caché en el cliente.** Toda lectura pasa por red
  (`frontend/lib/data/services/api_client.dart`); sin conexión no hay datos
  (`PENDIENTE DE VERIFICACIÓN` el comportamiento esperado en campo).
- **Módulo Jetson sin empaquetado.** No hay manifiesto de dependencias ni
  pruebas más allá de `test_secure_protocol.py`; el detector solo se valida con
  hardware (`AGENTS.md`, sección 6).

### 6) Evidence

- `backend/src/app.js` (composición del backend)
- `backend/src/services/iotProtocol.js`, `iotService.js`, `userService.js`
- `frontend/lib/main.dart`, `frontend/lib/viewmodels/`, `frontend/lib/data/`
- `jetson/lora_jetson_rx.py`, `jetson/secure_protocol.py`, `jetson/run_bovino.py`
- `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino`

## Extended Sections

### Orden de inicialización del backend

1. `dotenv` carga `backend/.env` (`backend/src/app.js:2`).
2. `firebaseAdmin.js` inicializa la app Admin, con proyecto
   `demo-bovisense` si detecta emuladores y `NODE_ENV=test`
   (`backend/src/config/firebaseAdmin.js:8-22`).
3. `helmet`, CORS, límite de tasa, parser JSON de 16 kb y `Cache-Control`
   (`backend/src/app.js:15-26`).
4. Middleware de trazas con `X-Request-Id` y log de entrada/salida
   (`backend/src/app.js:27-38`).
5. `/health` con caché de 15 s y timeout de 5 s (`backend/src/app.js:40-57`).
6. Routers de rol, 404 y manejador de errores (`backend/src/app.js:59-68`).

### Topología asíncrona (Jetson)

```text
lora_jetson_rx.py (proceso 1: SPI + radio + sesion)
   |  subprocess: python run_bovino.py --engine ... --source csi://0
   v
run_bovino.py (proceso 2: captura en hilos -> inferencia -> tracker)
   |  escribe JSON (BOVISENSE_STATUS_FILE, BOVISENSE_RESULT_FILE)
   |  imprime COUNT_UPDATE / COUNT_FINAL / WORKER_STATUS al log
   v
lora_jetson_rx.py lee ambos y los traduce a la trama R1
```

Evidencia: `jetson/run_bovino.py:26-28,103-155` (salidas del worker) y
`jetson/lora_jetson_rx.py:993-998,1058-1060` (lectura de hooks del worker).

### Postura de resiliencia (resumen)

| Fallo esperado | Comportamiento implementado | Evidencia |
|----------------|----------------------------|-----------|
| Reintento de la misma operación de usuario | Se reutiliza el resultado por huella | `backend/src/services/userService.js:21` |
| Comando duplicado por LoRa | Se devuelve la respuesta cacheada | `jetson/secure_protocol.py:77-82` |
| Pérdida del puente BLE | Error tipado y aviso en pantalla | `frontend/lib/data/services/esp32_ble_bridge_service.dart` (`failureMessage`) |
| Caída del sondeo del conteo | Reintento con espera creciente (4/5/8/12 s) | `frontend/lib/data/services/esp32_ble_bridge_service.dart` (`_scheduleCountPoll`) |
| Backend inalcanzable desde el teléfono | Mensaje con la causa y el comando `adb reverse` | `frontend/lib/data/services/api_client.dart:182-196` |
| Librería de tracking ausente | Degradación a tracker interno con aviso | `jetson/run_bovino.py:1973-1978` |
