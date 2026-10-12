# Despliegue: backend, app Android, Jetson y puente

Documenta la configuración **presente en el repositorio** y los pasos
verificables. Lo que no puede comprobarse desde el código está marcado como
`PENDIENTE DE VERIFICACIÓN`.

Regla vigente del proyecto: **trabajar en local**; el hospedaje y el despliegue
no están autorizados hasta completar pruebas y validación de campo
(`AGENTS.md`, encabezado).

## 1. Backend

### 1.1 Ejecución local

```bash
cd backend
npm ci                 # instalación reproducible desde package-lock.json
npm run dev            # node --watch src/app.js
curl http://127.0.0.1:3000/health
```

| Requisito | Detalle | Evidencia |
|-----------|---------|-----------|
| Node.js | `>=22 <25` | `backend/package.json:16-18` |
| Variables | `GOOGLE_APPLICATION_CREDENTIALS` o `FIREBASE_SERVICE_ACCOUNT_JSON`, `IOT_SHARED_SECRET` (64 hex), `IOT_DEVICE_ID`, `SMTP_*`, `PORT`, `CORS_ORIGINS`, `RATE_LIMIT_MAX` (120 por defecto) | `backend/src/app.js:2,16-21,71-79`; `backend/src/config/firebaseAdmin.js:15-21` |
| Archivo privado | `backend/.env` (ignorado por Git) | `.gitignore:1` |
| Bind | `0.0.0.0:3000`; el teléfono **no** debe usar esa dirección | `backend/src/app.js:71-73`, `AGENTS.md` sección 7 |
| Salud | `200` si Firestore y Auth responden, `503` si no | `backend/src/app.js:42-56` |

### 1.2 Despliegue en Vercel (configuración detectada)

| Elemento | Contenido | Evidencia |
|----------|-----------|-----------|
| Entrada serverless | `backend/api/index.js` exporta la app Express | `backend/api/index.js:1-3` |
| Ruteo | Todo el tráfico va a `api/index.js` | `backend/vercel.json:6-11` |
| Timeout de función | `maxDuration: 30` segundos | `backend/vercel.json:2-5` |
| Detección de plataforma | Si `VERCEL=1`, se activa `trust proxy` (necesario para el límite por IP) | `backend/src/app.js:13` |
| Variables requeridas en Vercel | Las mismas que en local; el servicio de Firebase puede inyectarse como JSON en `FIREBASE_SERVICE_ACCOUNT_JSON` en lugar de archivo | `backend/src/config/firebaseAdmin.js:15-16` |

Consideraciones detectadas para serverless:

- El manejador de salud cachea 15 s (`backend/src/app.js:40-49`), adecuado para
  instancias efímeras.
- El límite de 120 req/min por IP con `trust proxy` agrupa a los clientes detrás
  del balanceador de Vercel: `PENDIENTE DE VERIFICACIÓN` si el umbral es
  suficiente con varios usuarios simultáneos.
- `PENDIENTE DE VERIFICACIÓN`: si el despliegue está activo y qué dominio usa
  (no hay evidencia en el repositorio de la URL de producción; el historial
  menciona un cambio de ruta a "host Vercel" en `b55aeba`).

### 1.3 Reglas e infraestructura de Firebase

```bash
# Verificación con emuladores (no toca producción)
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 PATH=/usr/lib/jvm/java-21-openjdk-amd64/bin:$PATH \
  firebase emulators:exec --only auth,firestore --project demo-bovisense \
  "npm --prefix backend run test:integration"

# Despliegue de reglas (acción deliberada, no ejecutada en esta revisión)
firebase deploy --only firestore:rules --project aplicacion-cabfa
```

| Elemento | Detalle | Evidencia |
|----------|---------|-----------|
| Reglas | Solo lectura del propio perfil activo; todo lo demás por API | `firestore.rules:1-14` |
| Emuladores | Auth 9099, Firestore 8080, UI deshabilitada, proyecto único | `firebase.json:1-10` |
| Proyecto de la app | `aplicacion-cabfa` | `frontend/firebase.json`, `frontend/lib/firebase_options.dart` |
| Estado de despliegue | `PENDIENTE DE VERIFICACIÓN` | — |

## 2. Aplicación Android

### 2.1 Preparación

```bash
cd frontend
flutter pub get
flutter analyze && flutter test
```

| Requisito | Detalle | Evidencia |
|-----------|---------|-----------|
| Flutter/Dart | Dart `^3.10.4` | `frontend/pubspec.yaml:9` |
| Firebase | `frontend/lib/firebase_options.dart` y `android/app/google-services.json` presentes | `frontend/firebase.json`, `frontend/lib/firebase_options.dart` |
| Permisos | `INTERNET`, `BLUETOOTH_SCAN` (with `neverForLocation`), `BLUETOOTH_CONNECT`, legados con `maxSdkVersion=30`, `ACCESS_FINE_LOCATION` hasta API 30, feature BLE requerida | `frontend/android/app/src/main/AndroidManifest.xml:2-10` |

### 2.2 Ejecución en teléfono por USB (flujo habitual)

```bash
cd frontend
bash run_usb.sh          # ejecuta adb reverse tcp:3000 tcp:3000 y luego flutter run
```

Por qué: `127.0.0.1` dentro del teléfono es el teléfono, no la laptop. Sin
`adb reverse` la app no alcanza el backend local y muestra un error de conexión
explicando esta causa (`frontend/run_usb.sh`,
`frontend/lib/data/services/api_client.dart:182-196`, `AGENTS.md` sección 11).

Alternativa por WiFi:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000
```

### 2.3 Compilación de release

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<host-https>
```

| Restricción | Detalle | Evidencia |
|-------------|---------|-----------|
| HTTPS obligatorio | El cliente acepta HTTP solo para hosts locales (loopback y rangos privados) | `frontend/lib/data/services/api_client.dart:60-88` |
| Tráfico en claro | `usesCleartextTraffic` es `false` en release y `true` en debug/profile | `frontend/android/app/build.gradle.kts:34-42`, `AndroidManifest.xml:15` |
| Pendiente bloqueante | `applicationId = "com.example.frontend"` y firma debug en release | `frontend/android/app/build.gradle.kts:27,44-47` |

Cuidado: cambiar `applicationId` obliga a actualizar `google-services.json` y el
registro en Firebase (`AGENTS.md` sección 10).

## 3. Jetson

### 3.1 Archivos y servicio

```bash
# desde el PC
scp jetson/lora_jetson_rx.py jetson/secure_protocol.py \
    cow@<ip-jetson>:/home/cow/Documents/Script/
# en la Jetson (si cambio el worker de deteccion)
scp jetson/run_bovino.py cow@<ip-jetson>:/home/cow/Documents/Script/

# en la Jetson
sudo systemctl daemon-reload
sudo systemctl restart bovisense-lora
sudo journalctl -u bovisense-lora -f
sudo fuser -v /dev/spidev0.0
```

| Elemento | Valor | Evidencia |
|----------|-------|-----------|
| Ruta de trabajo | `/home/cow/Documents/Script/` | `jetson/lora_jetson_rx.py:48-51`, `jetson/README.md` |
| Entorno Python del worker | `/home/cow/Documents/Script/env_detection/bin/python3` | `jetson/lora_jetson_rx.py:49` |
| Engine TensorRT | `/home/cow/Documents/proyecto/modelos/model_fp32.engine` (fuera del repositorio) | `jetson/lora_jetson_rx.py:51` |
| Variables del servicio | `EnvironmentFile=/etc/bovisense/iot.env` con `IOT_SHARED_SECRET` y, opcionalmente, `BOVISENSE_STATE_DIR` | `AGENTS.md` sección 4; `jetson/secure_protocol.py:16` |
| Log sin buffer | Drop-in `jetson/systemd/unbuffered.conf` → `/etc/systemd/system/bovisense-lora.service.d/` | `jetson/systemd/unbuffered.conf:1-2` |
| Estado antirreplay | `~/.local/state/bovisense/protocol.sqlite3` (no borrar) | `jetson/secure_protocol.py:64-70` |

### 3.2 Verificaciones de arranque

| Verificación | Resultado esperado | Evidencia |
|--------------|--------------------|-----------|
| Cableado impreso | `[GPIO] Cableado confirmado: VCC y RST del SX1278 a 3.3 V (pin 17), DIO0 en pin 31` | `jetson/lora_jetson_rx.py` (mensajes de arranque) |
| Sin control de GPIO | Ninguna línea de `libgpiod`/`Jetson.GPIO` | `AGENTS.md` secciones 4 y 10 |
| Propietario único del SPI | `fuser` muestra un solo proceso (el servicio) | `jetson/lora_jetson_rx.py:251-272` |
| Reloj | Backend y Jetson con NTP; desfase tolerado ±5/65 s | `jetson/secure_protocol.py:40-44`, `docs/seguridad-y-despliegue.md` |

### 3.3 Ejecución manual (solo diagnóstico)

No iniciar un segundo receptor mientras el servicio está activo: la segunda
instancia falla intencionalmente al no obtener el `flock`
(`jetson/lora_jetson_rx.py:251-272`). El comando manual documentado, si el
servicio está detenido, es:

```bash
sudo bash -lc 'set -a; source /etc/bovisense/iot.env; set +a; \
  cd /home/cow/Documents/Script && python3 lora_jetson_rx.py'
```

## 4. Puente ESP32

| Aspecto | Detalle | Evidencia |
|---------|---------|-----------|
| Placa | ESP32 con core Arduino (`ARDUINO_ARCH_ESP32`) | `.ino:13-15` |
| Librerías | `LoRa` (Sandeep Mistry) y BLE nativo del core | `.ino:17-24` |
| Sketch | `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/` | — |
| Pines | SS 5, RST 14, DIO0 4 | `.ino:36-38` |
| Verificación en campo | Comparar la versión impresa por puerto serie con la del repositorio | `AGENTS.md` sección 6.3 (`PENDIENTE DE VERIFICACIÓN`) |

No hay binario compilado versionado, por lo que el firmware del prototipo puede
no coincidir con el del repositorio.

## 5. Secuencia de despliegue recomendada

1. **Backend**: `npm ci`, revisar `.env`, `npm run dev`, comprobar `/health`.
2. **App**: `bash frontend/run_usb.sh` (dependencia: `adb reverse` activo).
   Si cambió algo nativo (`MainActivity.kt`, manifiesto, recursos), reinstalar.
3. **Jetson**: copiar los scripts, `daemon-reload`, reiniciar el servicio y
   verificar las tres comprobaciones de la tabla 3.2.
4. **Puente**: solo si cambió el sketch; grabar y comprobar por serie.
5. **Validación**: seguir el checklist de la sección 21 de `AGENTS.md`
   (cámara, sesión completa, alertas, cuatro escenarios de Bluetooth,
   reconexión y medición de latencias).

## 6. Evidencia

- `backend/vercel.json`, `backend/api/index.js`, `backend/src/app.js`,
  `backend/src/config/firebaseAdmin.js`, `backend/package.json`
- `frontend/run_usb.sh`, `frontend/android/app/build.gradle.kts`,
  `frontend/android/app/src/main/AndroidManifest.xml`,
  `frontend/lib/data/services/api_client.dart`
- `jetson/systemd/unbuffered.conf`, `jetson/lora_jetson_rx.py`,
  `jetson/secure_protocol.py`, `docs/seguridad-y-despliegue.md`, `AGENTS.md`
- `firebase.json`, `firestore.rules`
