# Flujos de datos extremo a extremo

Cada flujo describe el recorrido real de los datos con evidencia. Los diagramas
de secuencia equivalentes están en [diagramas.md](diagramas.md).

## 1. Inicio de sesión y carga del panel de ganadero

1. La vista valida el formulario y llama a `AuthViewModel.login()`
   (`frontend/lib/views/auth/login_page.dart:34-51`).
2. `AuthRepository.signIn()` autentica con Firebase, carga el perfil desde
   `Usuarios/{uid}` con `Source.server` y rechaza cuentas no activas
   (`frontend/lib/data/repositories/auth_repository.dart`, `signIn`).
3. `AuthGate` decide la vista por rol (`frontend/lib/views/auth_gate.dart:24-32`).
4. `_SessionScope` reconstruye los providers con `KeyedSubtree(uid)`, por lo que
   un cambio de cuenta descarta el estado anterior
   (`frontend/lib/main.dart:127-140`).
5. `GanaderoViewModel.loadDashboard()` y `loadAlertas()` piden los datos a la API
   (`frontend/lib/viewmodels/ganadero_view_model.dart:40-55`).

Datos que viajan: `UsuarioModel` (uid, nombre, apellidos, correo, rol, estado,
operación pendiente) y los DTO del dashboard (`configuracion`, `dispositivo`,
`conteos_recientes`, `alertas_recientes`, contadores).

## 2. Alta de usuario (administrador)

1. El formulario crea un `UsuarioModel` y el repositorio adjunta un
   `request_id` estable mientras el payload no cambie
   (`frontend/lib/data/repositories/admin_usuario_repository.dart:150-176`).
2. El backend valida y ejecuta una operación con huella
   (`backend/src/services/userService.js:12-35`).
3. Se crea la cuenta en Firebase Auth con contraseña aleatoria
   (`backend/src/utils/passwordGenerator.js`), se escribe el perfil en Firestore
   y se indexa la cédula en `CedulasUsuarios`.
4. Se genera un enlace de restablecimiento y se envía por SMTP; si falla, la
   cuenta queda recuperable y la respuesta lo indica
   (`backend/src/services/userService.js:81-90`).

Datos que viajan: payload del formulario, transacción en Firestore, cuenta en
Auth y correo con enlace de activación.

## 3. Cambio y recuperación de contraseña

- Cambio (usuario autenticado): reautenticación con la contraseña actual y
  `updatePassword` (`frontend/lib/data/repositories/auth_repository.dart`,
  `changePassword`), con reglas de robustez evaluadas en la vista
  (`frontend/lib/views/auth/cambiar_contrasena_page.dart:71`).
- Recuperación: `sendPasswordResetEmail` y retorno del correo a la pantalla de
  login para precargarlo
  (`frontend/lib/views/auth/recuperar_contrasena_page.dart:40-72`,
  `login_page.dart:53-66`).

## 4. Ciclo de vida del dispositivo y la sesión

```text
[S] el backend crea IotSessions/{session} y IotDevices con lease de 900 s
     |
     v
[Q]/[T]/[R] usan device.session_id activo
     |
     +-- terminal (STOPPED/RESULT con count) -> guarda proof y lease = 0
     +-- ERROR  -> lease = 0 y la sesion queda marcada ERROR
     +-- IDLE   -> lease = 0 y se borra device.session_id
                   (la Jetson no conoce la sesion: reinicio del receptor)
```

Evidencia: `backend/src/services/iotService.js:37-51,88-102`. El último caso
corresponde al incidente resuelto y documentado en `AGENTS.md` sección 12.

## 5. Sesión de conteo completa (flujo principal)

| Fase | Quién | Qué ocurre | Datos que se mueven | Evidencia |
|------|-------|-----------|---------------------|-----------|
| Inicio | App | El usuario pulsa "Iniciar" (antes: conectar BLE y revisar estado) | `command=INICIARCONTEO` | `frontend/lib/views/ganadero/estado_dispositivo_page.dart` |
| Autorización | Backend | Valida rol, configuración de finca y lease; crea la sesión | `IotSessions`, `IotDevices{lease_until}` | `backend/src/services/iotService.js:37-51` |
| Transporte | App, ESP32, Jetson | La trama C1 viaja por BLE y LoRa | `C1\|request_id\|expires\|S\|session_id\|mac` | `.ino:245-249`, `jetson/secure_protocol.py:26-48` |
| Ejecución | Jetson | Abre sesión interna y lanza el worker | argumentos CLI del worker | `jetson/lora_jetson_rx.py:703-785` |
| Recuento | Jetson | El worker detecta, rastrea y cuenta; publica avances | `COUNT_UPDATE\|count=...` | `jetson/run_bovino.py:1306,1747` |
| Consulta | App | Sondeo cada 4 s mientras el estado es `RUNNING` | `Q` y `R1 RUNNING count` | `esp32_ble_bridge_service.dart` |
| Cierre | App y Jetson | El usuario pulsa "Detener" | `T` y `R1 STOPPED count completed_at` | `jetson/lora_jetson_rx.py:787-838` |
| Verificación | Backend | Recalcula el HMAC, valida fechas y marca terminal | `proof` guardada en la sesión | `backend/src/services/iotService.js:80-96` |
| Persistencia | App y Backend | La app envía la prueba y el backend deriva la cantidad | `POST /conteos {session_id, proof}` | `backend/src/controllers/ganaderoController.js:329-368` |
| Consecuencia | Backend | Crea conteo, calcula diferencia y alerta | `Conteos/{session}`, `Alertas/{session}` | `ganaderoController.js:250-265,340-360` |
| Cierre en la app | App | Limpia el estado del conteo y vuelve al flujo inicial | `resetCountSession()` | `esp32_ble_bridge_service.dart`, `AGENTS.md` sección 15 |

## 6. Detección y conteo (transformación interna del worker)

```text
frame BGR (1920x1080)
  -> preprocess (resize/letterbox segun el engine)
  -> TRTDetector.infer
  -> decode_detections (conf >= --conf, NMS)  -> [x1,y1,x2,y2,score,cls]
  -> tracker.update(detecciones, frame)       -> tracks con tracker_id
  -> identidad estable y anti doble conteo    -> total_count
  -> COUNT_UPDATE / COUNT_FINAL               -> receptor -> trama R1
```

Evidencia: `jetson/run_bovino.py` (`infer_worker`, `decode_detections`,
`tracker.update`, `_count_confirmed_track`) y
`jetson/lora_jetson_rx.py:976-1005` (lectura de los hooks del worker).

Nota de negocio: el conteo es **por identidad de track confirmada**, no por
detección. Un animal visible durante cientos de frames produce un solo evento
mientras el tracker mantenga su identidad (`jetson/run_bovino.py:1726-1750`).

## 7. Flujo de alertas

1. Al guardar un conteo el backend calcula
   `diferencia = detectada - esperada`
   (`backend/src/controllers/ganaderoController.js:234-236`).
2. Si la diferencia no es cero crea una alerta con tipo (`faltante` o
   `excedente`) y nivel (`alta` si es 10 o más, `media` si es 4 o más, `baja` en
   el resto) en la misma transacción
   (`ganaderoController.js:250-265,340-350`).
3. La app las muestra en la pestaña Historial, con las no leídas primero, y
   permite marcarlas como leídas
   (`frontend/lib/views/ganadero/historial_conteos_page.dart`,
   `ganadero_dashboard_page.dart`).
4. Marcar como leída actualiza `Alertas` y recarga panel e historial
   (`frontend/lib/viewmodels/ganadero_view_model.dart:158-172`).

## 8. Evidencia

- `backend/src/services/iotService.js`, `backend/src/services/userService.js`,
  `backend/src/controllers/ganaderoController.js`
- `frontend/lib/data/repositories/`, `frontend/lib/viewmodels/`,
  `frontend/lib/views/ganadero/`
- `jetson/lora_jetson_rx.py`, `jetson/run_bovino.py`, `jetson/secure_protocol.py`
