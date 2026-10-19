# App Flutter de BoviSense

Aplicación Android para la operación ganadera: inicio de sesión, configuración
de la finca, conteo asistido por BLE/LoRa, historial, alertas y administración
de usuarios.

## Flujo general

1. `main.dart` inicializa Firebase, construye las dependencias (Provider) y
   muestra el splash; `AuthGate` decide por rol: panel de administrador o shell
   del ganadero (Inicio · Finca · Conteo · Historial).
2. La sesión persistida se descarta en cada arranque (decisión para un teléfono
   compartido en el campo): siempre se pide correo y contraseña.
3. En el flujo de conteo, la app pide al backend una trama `C1` firmada, la
   envía por BLE al puente ESP32, espera la respuesta `R1` de la Jetson y solo
   la muestra **después** de que el backend verifica la firma.

## Ejecución local (teléfono por USB)

```bash
flutter pub get
bash run_usb.sh      # adb reverse tcp:3000 + flutter run
```

`run_usb.sh` publica el backend local (`127.0.0.1:3000` dentro del teléfono)
con `adb reverse`. Sin ese paso la app no llega al backend; como alternativa,
usa `--dart-define=API_BASE_URL=http://<ip-de-la-laptop>:3000` por WiFi.

La URL de la API se configura en `lib/core/config/app_config.dart`
(`API_BASE_URL`, por defecto `http://127.0.0.1:3000`). En release el tráfico en
claro está bloqueado; `debug` y `profile` lo permiten para el backend local.

## Estructura

| Ruta | Contenido |
| --- | --- |
| `lib/main.dart` | Arranque, providers por sesión y guard de ciclo de vida. |
| `lib/views/` | Pantallas: `auth/`, `admin/`, `ganadero/` y `common/`. |
| `lib/viewmodels/` | Estado por pantalla (Provider/ChangeNotifier). |
| `lib/data/repositories/` | Acceso al backend (API REST) y a Firebase Auth/Firestore. |
| `lib/data/services/` | `api_client.dart` (HTTP + token) y `esp32_ble_bridge_service.dart` (BLE). |
| `lib/data/models/` | Modelos y utilidades de parseo. |
| `lib/core/` | Configuración, tema y utilidades (`command_queue`, `request_id`). |
| `android/` | Proyecto Android; `MainActivity.kt` añade el canal nativo de Bluetooth. |
| `test/` | Pruebas de widgets y reglas puras (44 casos). |

El detalle del flujo BLE, timeouts y códigos de error está en
[`docs/arquitectura/integraciones-iot.md`](../docs/arquitectura/integraciones-iot.md).

## Pruebas y análisis

```bash
flutter analyze
flutter test
```

## Notas para Android

- Permisos BLE declarados en `AndroidManifest.xml` (`BLUETOOTH_SCAN` con
  `neverForLocation`, `BLUETOOTH_CONNECT` y permisos heredados ≤ API 30).
- La app distingue Bluetooth apagado, permiso denegado, adaptador ocupado
  (audífonos/parlantes, vía canal nativo) y equipo no encontrado, con acciones
  para resolverlo.
- Pendiente antes de publicar: `applicationId` definitivo y firma de release en
  `android/app/build.gradle.kts`; cambiarlo exige actualizar
  `google-services.json` y el registro en Firebase.
