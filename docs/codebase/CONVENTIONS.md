# Coding Conventions

## Core Sections (Required)

### 1) Naming Rules

| Item | Rule | Example | Evidence |
|------|------|---------|----------|
| Archivos Dart | `snake_case` descriptivo, sufijo por rol (`_page`, `_service`, `_repository`, `_model`) | `estado_dispositivo_page.dart`, `api_client.dart` | `frontend/lib/views/ganadero/`, `frontend/lib/data/services/` |
| Archivos JS | `camelCase` para utilidades; dominio en singular/plural según recurso | `iotService.js`, `ganaderoRoutes.js`, `passwordGenerator.js` | `backend/src/services/`, `backend/src/routes/` |
| Archivos Python | `snake_case` | `lora_jetson_rx.py`, `secure_protocol.py` | `jetson/` |
| Clases Dart/JS | `PascalCase` | `ApiClient`, `SessionNotifier`, `HttpError` | `frontend/lib/data/services/api_client.dart:25`, `backend/src/utils/validation.js:1` |
| Funciones/métodos | `camelCase` (Dart/JS) y `snake_case` (Python) | `commandFrame()`, `execute_secure_command()` | `backend/src/services/iotProtocol.js:21`, `jetson/lora_jetson_rx.py:1213` |
| Campos privados | Prefijo `_` | `_repository`, `_pollFailures`, `_errorMessage` | `frontend/lib/data/services/esp32_ble_bridge_service.dart` |
| Constantes de módulo | `MAYÚSCULAS_CON_GUIONES` | `FRAME_QUEUE_SIZE`, `COUNT_MAX_DURATION_SEC`, `HEX_ID` | `jetson/run_bovino.py:20-21`, `jetson/lora_jetson_rx.py:61` |
| Variables de entorno | `SCREAMING_SNAKE` | `IOT_SHARED_SECRET`, `BOVISENSE_STATE_DIR` | `backend/src/app.js:74`, `jetson/secure_protocol.py:16` |
| Claves JSON de la API | `snake_case` en español de dominio | `cantidad_detectada`, `next_cursor`, `session_id` | `backend/src/controllers/ganaderoController.js:80-94` |

Convención de idioma: identificadores técnicos en inglés, dominio en español
(`obtenerDashboard`, `registrarConteoReal`, `alerta_model.dart`). Es consistente
en los cuatro módulos.

### 2) Formatting and Linting

- **Dart**: formatter oficial `dart format` (sin configuración propia); linter
  `package:flutter_lints/flutter.yaml` con la sección `rules` vacía, es decir,
  solo reglas por defecto (`frontend/analysis_options.yaml:10-28`).
- **JavaScript**: no hay ESLint/Prettier ni configuración de estilo; el escáner
  reportó `No linting or formatting config files found in project root`
  (`docs/codebase/.codebase-scan.txt`). El estilo se deduce del código: 4
  espacios, comillas simples, punto y coma obligatorio
  (`backend/src/app.js:15-26`).
- **Python**: sin `ruff`/`flake8`/`black`; estilo PEP 8 de facto, 4 espacios y
  líneas largas ocasionales (`jetson/run_bovino.py`).
- Comandos: `cd frontend && flutter analyze`, `dart format <archivos>`,
  `cd backend && npm test`, `python3 -m py_compile <archivo>.py`.

### 3) Import and Module Conventions

- **Dart**: sin aliases ni barrel files; imports relativos ordenados
  paquete → proyecto (`frontend/lib/main.dart:1-23`). Las vistas importan
  `provider` y modelos, nunca el cliente HTTP.
- **JS**: `require` de CommonJS; primero módulos de Node, luego paquetes, luego
  archivos locales (`backend/src/app.js:1-9`). Los `module.exports` enumeran
  explícitamente el contrato público, p. ej.
  `module.exports = { COMMANDS, secretKey, sign, commandFrame, responseFrame }`
  (`backend/src/services/iotProtocol.js:52`).
- **Python**: imports estándar, luego terceros, luego locales
  (`jetson/run_bovino.py:1-17`). El protocolo se importa con
  `from secure_protocol import STATES, SecureProtocol`
  (`jetson/lora_jetson_rx.py:10`), lo que exige ejecutar el script desde su
  carpeta.
- **Dependencias opcionales**: se importan dentro de la función y con
  tolerancia a fallos, para permitir degradación
  (`jetson/run_bovino.py:1438-1439`, import diferido de `supervision` y
  `trackers`).

### 4) Error and Logging Conventions

- **Backend, capa de dominio**: se lanza `HttpError(status, mensaje)` con texto
  en español apto para el usuario final (`backend/src/utils/validation.js:1-6`).
  El manejador central traduce el resto a `503` y registra en stderr un JSON
  `{event:'request_failed', status, code}` (`backend/src/utils/validation.js:43-56`).
- **Backend, capa HTTP**: nunca se filtran stack traces al cliente; el detalle
  completo va a consola (`backend/src/app.js:62-68`).
- **Backend, trazabilidad**: cada petición recibe `X-Request-Id` (cabecera del
  cliente o generado) y se registra entrada y salida con duración
  (`backend/src/app.js:27-38`); el controlador de ganadero añade
  `logGanadero(req, 'paso', {...})` (`backend/src/controllers/ganaderoController.js:109-116`).
- **App, transporte**: `ApiException` encapsula `message`, `statusCode` y `path`
  (`frontend/lib/data/services/api_client.dart:8-23`); los fallos de red se
  convierten a mensajes accionables con
  `ApiClient.connectionHelp()` (`frontend/lib/data/services/api_client.dart:182-196`).
- **App, presentación**: los viewmodels capturan y exponen `errorMessage` sin
  lanzar (`frontend/lib/viewmodels/ganadero_view_model.dart:47-50`); la UI lo
  muestra en `AlertCard` o `SnackBar`. Nunca se muestra el `toString()` crudo de
  una excepción al usuario final.
- **Jetson**: se usa `print` con prefijos estables que el receptor parsea o el
  operador filtra: `COUNT_UPDATE|`, `COUNT_FINAL|`, `WORKER_STATUS|`
  (`jetson/run_bovino.py:103-127`), `COUNT_ACCEPTED|` / `COUNT_REJECTED_*`
  (`jetson/run_bovino.py:1731-1750`), `[Seguro]`, `LoRa TX:`, `[TRACKER]`.
  El receptor se ejecuta con `PYTHONUNBUFFERED=1`
  (`jetson/systemd/unbuffered.conf:1-2`).
- **Redacción de secretos**: la clave IoT nunca se imprime; al arrancar el
  backend solo se informa `configurado` / `NO CONFIGURADO`
  (`backend/src/app.js:74-79`).

### 5) Testing Conventions

- **Dart**: pruebas en `frontend/test/`, nombre `<tema>_test.dart`
  (`api_client_test.dart`, `ble_failure_test.dart`); sin cobertura declarada.
- **JS**: `node --test` con archivos `*.test.js` en `backend/test/` y las de
  integración aparte en `backend/test/integration/`
  (`backend/package.json:9-10`).
- **Python**: `unittest` en `jetson/test_secure_protocol.py`, con dobles de
  hardware (clase `FakeSpi`) y `patch.object` para aislar el radio.
- Mocking: HTTP se simula con `MockClient` de `package:http/testing.dart`
  (`frontend/test/api_client_test.dart:5`); Firebase se sustituye por emuladores
  reales (`backend/test/integration/api.test.js:6-8`), no por mocks.

### 6) Evidence

- `frontend/analysis_options.yaml`
- `backend/src/utils/validation.js`, `backend/src/app.js`
- `frontend/lib/data/services/api_client.dart`
- `jetson/run_bovino.py`, `jetson/systemd/unbuffered.conf`
- `docs/codebase/.codebase-scan.txt` (sección LINTING AND FORMATTING CONFIG)

## Extended Sections

### Matriz de manejo de errores por capa

| Capa | Mecanismo | Visible al usuario | Evidencia |
|------|-----------|--------------------|-----------|
| Rutas backend | Delegación al controlador | — | `backend/src/routes/*.js` |
| Controladores backend | `try/catch` + `respondError` | Mensaje corto en español | `backend/src/controllers/ganaderoController.js:426` |
| Servicios backend | `HttpError` con código de dominio | Mensaje del error | `backend/src/services/iotService.js:17-58` |
| Repositorios app | `throw Exception(...)` / `ApiException` | No directo | `frontend/lib/data/repositories/ganadero_repository.dart:30-38` |
| Viewmodels app | Captura y expone `errorMessage` | Sí, vía UI | `frontend/lib/viewmodels/admin_usuarios_view_model.dart:52-55` |
| Servicio BLE | Excepción tipada + cola serializada | Sí, mensaje por causa | `frontend/lib/data/services/esp32_ble_bridge_service.dart` (`failureMessage`) |
| Jetson | `try/except` que responde `ERROR` en la trama R1 | Sí, como estado | `jetson/secure_protocol.py:86-92` |

### Convención de commits y ramas

Historial reciente en español, mensajes cortos y sin prefijos tipo
Conventional Commits: `Mejoras backend BoviSense`,
`Corrige flujo de conteo, alertas y vistas de ganadero y administrador`
(`git log --oneline -20`). Ramas observadas: `dev` (trabajo) y `main`
(integración), con merges `dev → main`.
