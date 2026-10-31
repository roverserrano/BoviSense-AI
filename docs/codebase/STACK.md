# Technology Stack

Proyecto políglota: cuatro artefactos desplegables con lenguajes y runtimes
distintos. No hay un manifiesto raíz; la detección se hizo por módulo.

## Core Sections (Required)

### 1) Runtime Summary

| Area | Value | Evidence |
|------|-------|----------|
| Lenguaje principal (app) | Dart (Flutter) | `frontend/pubspec.yaml:1` (`name: frontend`) |
| Lenguaje principal (backend) | JavaScript CommonJS | `backend/package.json:16` (`"type": "commonjs"`) |
| Lenguaje principal (Jetson) | Python 3 | `jetson/lora_jetson_rx.py:1`, `jetson/run_bovino.py:1` |
| Lenguaje principal (puente) | C++ (Arduino ESP32) | `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino:13` |
| Runtime app | Flutter SDK, Dart `^3.10.4` | `frontend/pubspec.yaml:9` |
| Runtime backend | Node.js `>=22 <25` | `backend/package.json:16-18` |
| Runtime Jetson | Python 3 del venv `env_detection` | `jetson/lora_jetson_rx.py:49` |
| Runtime puente | Core Arduino `ARDUINO_ARCH_ESP32` | `.ino:13-15` (error de compilación si no es ESP32) |
| Gestor de paquetes (backend) | npm (`package-lock.json`, lockfileVersion 3) | `backend/package-lock.json:4`, `backend/package.json:6-11` |
| Gestor de paquetes (app) | `flutter pub` (`pubspec.lock`) | `frontend/pubspec.lock`, `frontend/pubspec.yaml` |
| Gestor de paquetes (Jetson) | PENDIENTE DE VERIFICACIÓN: no hay `requirements.txt` ni `pyproject.toml`; las dependencias se instalan a mano en el venv | Búsqueda en el repo sin resultados |
| Sistema de módulos | CommonJS (backend); ESM/Dart packages (app); scripts sueltos (Jetson) | `backend/package.json:16`, `frontend/pubspec.yaml` |

### 2) Production Frameworks and Dependencies

**Backend** (`backend/package.json:20-28`, versiones declaradas):

| Dependency | Version | Role in system | Evidence |
|------------|---------|----------------|----------|
| express | ^5.2.1 | Servidor HTTP y enrutado | `backend/package.json` |
| firebase-admin | ^14.4.0 | Auth y Firestore con privilegios de servidor | `backend/src/config/firebaseAdmin.js:3-5` |
| helmet | ^8.3.0 | Cabeceras de seguridad HTTP | `backend/src/app.js:15` |
| cors | ^2.8.6 | Control de orígenes permitidos | `backend/src/app.js:16-17` |
| express-rate-limit | ^8.7.0 | Límite de 120 req/min por IP | `backend/src/app.js:18-21` |
| dotenv | ^18.0.0 | Carga de `backend/.env` | `backend/src/app.js:2` |
| nodemailer | ^10.0.10 | Envío SMTP del enlace de activación | `backend/src/services/mailService.js:1` |

**App Android** (`frontend/pubspec.yaml:13-23`, versiones declaradas):

| Dependency | Version | Role in system | Evidence |
|------------|---------|----------------|----------|
| firebase_core | ^4.6.0 | Inicialización de Firebase | `frontend/lib/main.dart:14-17` |
| firebase_auth | ^6.3.0 | Login, cambio y recuperación de contraseña | `frontend/lib/data/repositories/auth_repository.dart` |
| cloud_firestore | ^6.2.0 | Lectura del perfil propio | `frontend/lib/data/repositories/auth_repository.dart:130-136` |
| provider | ^6.1.5+1 | Inyección de dependencias y notificación a la UI | `frontend/lib/main.dart:84-140` |
| http | ^1.6.0 | Cliente HTTP con `AbortableRequest` | `frontend/lib/data/services/api_client.dart:3,120` |
| flutter_blue_plus | ^1.36.8 | Escaneo y GATT BLE hacia el puente | `frontend/lib/data/services/esp32_ble_bridge_service.dart:9` |
| permission_handler | ^11.4.0 | Permisos de Bluetooth y ubicación | `frontend/lib/data/services/esp32_ble_bridge_service.dart:10` |
| url_launcher | ^6.3.1 | Llamada y WhatsApp de soporte | `frontend/lib/views/auth/login_page.dart:3` |

**Jetson** (sin manifiesto; dependencias detectadas por import):

| Dependency | Role | Evidence |
|------------|------|----------|
| TensorRT (`tensorrt`) | Inferencia del engine MobileNet SSD | `jetson/run_bovino.py:12` |
| CUDA runtime (`cuda.bindings.runtime`) | Copias host↔device | `jetson/run_bovino.py:14-17` |
| OpenCV (`cv2`) | Captura GStreamer, dibujo, ORB para GMC | `jetson/run_bovino.py:2` |
| numpy | Álgebra de cajas y descriptores | `jetson/run_bovino.py:11` |
| spidev | SPI hacia el SX1278 | `jetson/lora_jetson_rx.py:9` |
| SQLite3 (stdlib) | Antirreplay persistente | `jetson/secure_protocol.py:6` |
| `trackers` + `supervision` (Roboflow) | BoT-SORT / ByteTrack / OC-SORT | `jetson/run_bovino.py:1447-1448` (import diferido) |

### 3) Development Toolchain

| Tool | Purpose | Evidence |
|------|---------|----------|
| `flutter_lints` ^5.0.0 | LINT (reglas recomendadas de Flutter) | `frontend/pubspec.yaml:27`, `frontend/analysis_options.yaml:10` |
| `dart format` | FORMAT | Uso verificado en esta sesión; sin archivo de configuración propio |
| `node --test` (runner integrado) | TEST | `backend/package.json:9-10` |
| `node --watch` | DEV (recarga automática) | `backend/package.json:8` |
| `flutter test` / `flutter analyze` | TEST / LINT | `frontend/pubspec.yaml:26-27` |
| `unittest` (stdlib Python) | TEST (Jetson) | `jetson/test_secure_protocol.py:11` |
| `firebase-tools` (CLI) | Emuladores e integración | `firebase.json`, `docs/seguridad-y-despliegue.md` |
| Android SDK + Gradle 8.14 | BUILD Android | `frontend/android/gradle/wrapper/` |

### 4) Key Commands

```bash
# Backend
cd backend && npm ci && npm run dev            # desarrollo (node --watch)
cd backend && npm test                         # pruebas unitarias
cd backend && npm run test:integration         # requiere emuladores de Firebase

# App Android
cd frontend && flutter pub get
bash run_usb.sh                                # adb reverse + flutter run
cd frontend && flutter analyze && flutter test
cd frontend && flutter build apk --release --dart-define=API_BASE_URL=https://<host>

# Jetson
cd jetson && python3 -m unittest test_secure_protocol.py
python3 -m py_compile run_bovino.py lora_jetson_rx.py
```

### 5) Environment and Config

- Sources de configuración: `backend/.env` (privado, ignorado por Git),
  `backend/vercel.json`, `firestore.rules`, `firebase.json`,
  `frontend/lib/firebase_options.dart`, `frontend/android/app/google-services.json`,
  `/etc/bovisense/iot.env` (Jetson, fuera del repo).
- Variables que lee el backend (`grep` sobre `backend/src` y `backend/api`):
  `PORT`, `VERCEL`, `CORS_ORIGINS`, `RATE_LIMIT_MAX` (por defecto 120),
  `NODE_ENV`, `GOOGLE_APPLICATION_CREDENTIALS`,
  `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIRESTORE_EMULATOR_HOST`,
  `FIREBASE_AUTH_EMULATOR_HOST`, `IOT_DEVICE_ID`, `IOT_SHARED_SECRET`,
  `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`.
- Variables que leen los scripts de la Jetson: `IOT_SHARED_SECRET`,
  `BOVISENSE_STATE_DIR`, `BOVISENSE_SESSION_ID`, `BOVISENSE_STATUS_FILE`,
  `BOVISENSE_RESULT_FILE` (`jetson/secure_protocol.py:16,63`;
  `jetson/run_bovino.py:26-28`).
- Restricciones de despliegue: la app exige HTTPS salvo hosts locales
  (`frontend/lib/data/services/api_client.dart:60-88`); en `release` el tráfico
  en claro está bloqueado por el manifiesto
  (`frontend/android/app/build.gradle.kts:34-42`).

### 6) Evidence

- `backend/package.json`, `backend/package-lock.json`
- `frontend/pubspec.yaml`, `frontend/pubspec.lock`, `frontend/analysis_options.yaml`
- `jetson/lora_jetson_rx.py`, `jetson/run_bovino.py`, `jetson/secure_protocol.py`
- `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino`
- `docs/codebase/.codebase-scan.txt` (secciones STACK DETECTION y CODE METRICS)

## Extended Sections

### Brecha de manifiestos

El escáner de la skill, ejecutado en la raíz, reportó
`No recognized manifest files found in project root` porque los manifiestos
viven en `backend/` y `frontend/` (`docs/codebase/.codebase-scan.txt`). Ejecutado
dentro de `backend/`, detectó `package-lock.json` y `src/app.js` como punto de
entrada (`/tmp/scan-backend.txt`, generado durante este análisis).

El módulo Jetson **no** tiene manifiesto de dependencias: instalar el entorno
depende de pasos manuales en el venv `env_detection`
(`PENDIENTE DE VERIFICACIÓN`: contenido exacto de ese entorno).
