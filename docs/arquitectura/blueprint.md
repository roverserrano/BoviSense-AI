# Project Architecture Blueprint — BoviSense-AI

Documento maestro de arquitectura. Equivale al `Project_Architecture_Blueprint.md`
de la skill `architecture-blueprint-generator`, adaptado al idioma y a la
estructura de `docs/` del proyecto.

**Variables de configuración aplicadas**

| Variable | Valor usado | Motivo |
|----------|-------------|--------|
| `PROJECT_TYPE` | Auto-detección | El repositorio es políglota: Flutter/Dart, Node.js/JS, Python y C++ (Arduino ESP32) |
| `ARCHITECTURE_PATTERN` | Auto-detección | Se detectaron tres estilos distintos conviviendo (capas, MVVM y dos procesos en el borde) |
| `DIAGRAM_TYPE` | C4 + Componentes + Flujo | Ver [diagramas.md](diagramas.md) |
| `DETAIL_LEVEL` | Comprehensive | Alcance pedido: documentación integral |
| `INCLUDES_CODE_EXAMPLES` | No | Se referencia archivo:línea en lugar de copiar código |
| `INCLUDES_IMPLEMENTATION_PATTERNS` | Sí | Ver sección 10 |
| `INCLUDES_DECISION_RECORDS` | Sí | Ver sección 15 |
| `FOCUS_ON_EXTENSIBILITY` | Sí | Ver sección 13 y 17 |

## 1. Detección de arquitectura

La arquitectura **no** se deduce de los nombres de carpeta, sino del flujo real
de dependencias y de los mecanismos de comunicación:

| Artefacto | Tecnología | Evidencia |
|-----------|------------|-----------|
| Aplicación móvil | Flutter 3 / Dart `^3.10.4` | `frontend/pubspec.yaml:9` |
| API | Node.js `>=22 <25` + Express 5 | `backend/package.json:16-24` |
| Borde (radio + detección) | Python 3 en Jetson Orin Nano | `jetson/lora_jetson_rx.py`, `jetson/run_bovino.py` |
| Puente físico | C++ sobre core ESP32 | `comunicacion-iot/esp32/.../*.ino:13-15` |
| Persistencia central | Cloud Firestore (Admin SDK + SDK cliente) | `backend/src/config/firebaseAdmin.js`, `firestore.rules` |
| Almacén del borde | SQLite local | `jetson/secure_protocol.py:64-70` |

Patrones detectados con evidencia: capas en backend
(`backend/src/app.js:59-68`), MVVM con repositorios en la app
(`frontend/lib/main.dart:127-160`), dos procesos cooperativos en el borde
(`jetson/lora_jetson_rx.py` lanza y supervisa a `jetson/run_bovino.py`).

## 2. Visión general arquitectónica

BoviSense-AI es un sistema **distribuido de borde con autoridad central**: el
backend emite autorizaciones firmadas, un dispositivo físico transporta tramas
opacas y la Jetson ejecuta y firma el resultado. La app es un cliente delgado que
nunca produce datos de conteo por sí misma.

Principios evidentes en el código:

1. **Autoridad criptográfica central.** Solo backend y Jetson conocen
   `IOT_SHARED_SECRET`; el puente no (`bridge_hotspot_lora_discovery.ino:10`,
   `jetson/secure_protocol.py:15-20`).
2. **Datos verificables por encima de datos convenientes.** El conteo se guarda
   únicamente con prueba final firmada, no con la cantidad que declare el cliente
   (`backend/src/controllers/ganaderoController.js:329-333`).
3. **Degradación explícita antes que fallo silencioso.** Fallback de tracker con
   aviso, mensajes de error con causa y acción, reconciliación de sesión perdida.
4. **Alcance local por decisión de proyecto.** El hospedaje y el despliegue no
   están autorizados hasta completar pruebas (`AGENTS.md`, encabezado).

Límites arquitectónicos: backend ↔ Firestore (Admin SDK), backend ↔ app (HTTP
con token), app ↔ puente (BLE GATT), puente ↔ Jetson (LoRa), Jetson interna
(subproceso + archivos). No existe comunicación directa Jetson ↔ backend.

## 3. Visualización

Todos los diagramas están en [diagramas.md](diagramas.md): contexto C4,
contenedores C4, componentes del backend y de la app, secuencia del login, del
ciclo de conteo y del alta de usuario, máquina de estados de la sesión y
topología de despliegue. Se elaboraron a partir del código citado, no de la
intención declarada en el README.

## 4. Componentes arquitectónicos principales

| Componente | Responsabilidad | Estructura interna | Interacción | Extensión |
|------------|-----------------|--------------------|-------------|-----------|
| API HTTP (`backend/src`) | Identidad, roles, configuración, conteos, alertas y emisión/verificación de tramas | `routes → controllers → services → utils` | Recibe HTTP con token; usa Firestore y SMTP | Nuevos recursos: añadir router, controlador y servicio |
| Protocolo IoT (`backend/src/services/iotProtocol.js`) | Formato y firma C1/R1 | Funciones puras + constantes | Usada por `iotService.js` y los tests | Nuevos comandos: agregar a `COMMANDS` y a los alias de la Jetson |
| Sesión IoT (`backend/src/services/iotService.js`) | Tickets, lease del dispositivo, verificación de respuesta | Transacciones Firestore | Invocada por el controlador de ganadero | Nuevos estados: extender `STATES` en ambos extremos |
| App Flutter (`frontend/lib`) | Experiencia de ganadero y administrador | `views → viewmodels → repositories → services` | HTTP + Firebase + BLE | Nuevas pantallas: vista + viewmodel + método de repositorio |
| Servicio BLE (`frontend/lib/data/services/esp32_ble_bridge_service.dart`) | Descubrir, conectar, enviar comandos, escanear respuestas, sondeo y errores tipados | Estado en memoria + cola serializada + temporizadores | BLE GATT y API HTTP | Nuevos comandos: `sendCommand('NOMBRE')` |
| Receptor Jetson (`jetson/lora_jetson_rx.py`) | SPI, radio, autenticación, sesión y supervisión del worker | Clase `SX1278Receiver` + `CountSessionController` | LoRa y subproceso | Nuevos comandos: `execute_secure_command` |
| Worker de detección (`jetson/run_bovino.py`) | Captura, inferencia TensorRT, tracking, conteo y métricas | Hilos de captura/inferencia/dibujo + tracker | Archivos de estado y stdout | Nuevos trackers: `create_tracker` |
| Puente ESP32 (`comunicacion-iot/esp32/.../*.ino`) | Transporte BLE ↔ LoRa | Máquina de estados simple | BLE y radio | Cambios de pines o de tiempo de espera |

## 5. Capas y dependencias

```text
Backend:            routes ──> controllers ──> services ──> Firebase Admin / SMTP
App:                views ──> viewmodels ──> repositories ──> services ──> HTTP/BLE/Firebase
Jetson (radio):     secure_protocol <── lora_jetson_rx ──> CountSessionController ──> subproceso
Jetson (detección): captura ──> inferencia ──> tracker ──> contador ──> archivos/stdout
```

Reglas de dependencia verificadas: ninguna vista importa `package:http`
(verificado con búsqueda), ningún servicio de backend recibe `req`/`res`
(`backend/src/services/userService.js:5-12`), y `secure_protocol.py` no importa
nada del receptor (`jetson/secure_protocol.py:1-13`), por lo que es reutilizable
en pruebas.

No se detectaron dependencias circulares entre módulos del repositorio. En la app
existe un acoplamiento intencional entre vista y servicio BLE vía Provider
(`frontend/lib/main.dart:149`), documentado como decisión en la sección 15.

## 6. Arquitectura de datos

- **Modelo central**: documentos por usuario en Firestore
  (`Usuarios/{uid}` con subcolecciones `ConfiguracionSistema`,
  `DispositivosConteo`, `Conteos`, `Alertas`) más colecciones de coordinación
  IoT (`IotCommands`, `IotSessions`, `IotDevices`) y de integridad
  (`CedulasUsuarios`, `OperacionesUsuarios`)
  (`backend/src/controllers/ganaderoController.js:26-36`,
  `backend/src/services/iotService.js:5-9`,
  `backend/src/services/userService.js:6-8`).
- **Compatibilidad heredada**: el controlador de ganadero lee también las
  colecciones de nivel raíz `Conteos`, `Alertas` y `ConfiguracionSistema`
  (`backend/src/controllers/ganaderoController.js:127-221`).
- **Transformación**: cada controlador mapea documentos a DTO con nombres
  explícitos (`mapConteo`, `mapAlerta`, `mapConfiguracion`,
  `backend/src/controllers/ganaderoController.js:38-107`).
- **Validación**: en el borde de entrada con `object/text/integer/documentId/hexId`
  (`backend/src/utils/validation.js:8-40`) y en el borde físico con
  `parse_command` (`jetson/secure_protocol.py:26-48`).
- **Caché**: no hay capa de caché; solo una caché de 15 s para el chequeo de
  salud (`backend/src/app.js:40-49`).

## 7. Preocupaciones transversales

| Concern | Implementación | Evidencia |
|---------|----------------|-----------|
| Autenticación | Token de Firebase verificado con revocación (`verifyIdToken(token, true)`) y perfil en Firestore | `backend/src/middlewares/authMiddleware.js:24,57-103` |
| Autorización | Roles `administrador` y `usuario/ganadero` por router | `backend/src/routes/usuarioRoutes.js:35`, `ganaderoRoutes.js:8` |
| Bloqueo por estado | Usuario inactivo u operación pendiente ⇒ `403` con mensaje diferenciado | `backend/src/middlewares/authMiddleware.js:81-93` |
| Errores | `HttpError` + manejador central; nada de stack traces al cliente | `backend/src/app.js:62-68` |
| Logs y trazas | `X-Request-Id`, log de entrada/salida con duración, log de dominio por paso | `backend/src/app.js:27-38`, `ganaderoController.js:109-116` |
| Validación | Estricta, sin coerción implícita; límites de tamaño y formato | `backend/src/utils/validation.js:8-40` |
| Configuración | `.env` local, variables de entorno en Vercel y `iot.env` en la Jetson | `backend/src/app.js:2`, `docs/seguridad-y-despliegue.md` |
| Secretos | Fuera de Git salvo configuración pública de cliente de Firebase | `.gitignore`, `git ls-files` (ver `CONCERNS.md`) |

## 8. Comunicación entre servicios

| Tramo | Protocolo | Formato | Autenticación | Evidencia |
|-------|-----------|---------|---------------|-----------|
| App → Backend | HTTP/JSON | DTO `snake_case` | `Authorization: Bearer <ID token>` | `frontend/lib/data/services/api_client.dart:118-130` |
| Backend → App | HTTP/JSON | DTO + códigos de error | — | `backend/src/utils/validation.js:43-56` |
| App → ESP32 | BLE GATT | `~<trama C1>\n` fragmentada | Firma HMAC de la trama | `esp32_ble_bridge_service.dart` (escritura por fragmentos) |
| ESP32 → Jetson | LoRa 433 MHz | Trama `C1` ASCII | HMAC-SHA256 truncado | `bridge_hotspot_lora_discovery.ino:39-47` |
| Jetson → ESP32 → App | LoRa/BLE | Trama `R1` ASCII | HMAC-SHA256 truncado | `jetson/secure_protocol.py:50-58` |
| Jetson interna | Subproceso + archivos + stdout | JSON y líneas `CLAVE|clave=valor` | — | `jetson/run_bovino.py:92-155` |

No hay versionado de API ni service discovery; la compatibilidad se mantiene por
despliegue coordinado (`docs/seguridad-y-despliegue.md`).

## 9. Patrones por tecnología

- **Node.js/Express**: composición por middleware en orden explícito
  (`backend/src/app.js:15-38`), routers por rol, controladores delgados,
  servicios con dependencias inyectadas por parámetro
  (`createIotService(db)`, `createUserService({...})`).
- **Flutter**: `ChangeNotifier` + Provider, base `SessionNotifier` con bandera
  `disposed` (`frontend/lib/viewmodels/session_notifier.dart:3-14`), widgets
  privados con `_`, y separación estricta datos/vista.
- **Python (borde)**: clases con estado explícito, funciones puras para el
  protocolo, argparse con valores por defecto para todos los parámetros de
  hardware y degradación tolerante a fallos.
- **C++ (ESP32)**: máquina de estados con `waitingForResponse`, cola FreeRTOS
  para comandos BLE y temporización por `millis()`.

## 10. Patrones de implementación (con evidencia)

| Patrón | Implementación concreta | Archivo |
|--------|-------------------------|---------|
| Idempotencia con huella | `fingerprint = sha256(action+payload)` y `lease_until` | `backend/src/services/userService.js:12-35` |
| Transacción con verificación de lease | Se relee la operación y se compara `lease` | `backend/src/services/userService.js:72-80` |
| Antirreplay | Tabla `requests` con respuesta cacheada + tabla `results` | `jetson/secure_protocol.py:69-100` |
| Estados de track y confirmación | `minimum_consecutive_frames` y contador de identidad | `jetson/run_bovino.py:1828-1900` (tracker con librería), `1285-1308` (tracker interno) |
| Anti doble conteo | `identity_counted_ids`/`counted_track_ids` | `jetson/run_bovino.py:1726-1750`, `1295-1308` |
| Compensación de movimiento global | ORB + `estimateAffinePartial2D` | `jetson/run_bovino.py:1290-1326` |
| Degradación con aviso | `create_tracker` cae al tracker interno e imprime el motivo | `jetson/run_bovino.py:1973-1978` |
| Serialización de comandos | `CommandQueue` en la app | `frontend/lib/core/utils/command_queue.dart` |
| Reintento con espera creciente | `_pollDelay` 4/5/8/12 s | `frontend/lib/data/services/esp32_ble_bridge_service.dart` |

## 11. Arquitectura de pruebas

Detalle completo en [../codebase/TESTING.md](../codebase/TESTING.md). Resumen
arquitectónico: pruebas unitarias por módulo, pruebas de integración del backend
contra emuladores reales de Firebase, pruebas del protocolo y del control de
radio en la Jetson con dobles de SPI, y pruebas de widget aisladas en la app.
No existe prueba end-to-end con hardware.

## 12. Arquitectura de despliegue

Detalle en [despliegue.md](despliegue.md). Resumen:

| Destino | Artefacto | Configuración |
|---------|-----------|---------------|
| Vercel (serverless) | `backend/api/index.js` exportando la app Express | `backend/vercel.json` (`maxDuration: 30`, ruta catch-all) |
| Android | APK/AAB Flutter | `frontend/android/`, `--dart-define=API_BASE_URL=...` |
| Jetson | `bovisense-lora.service` + venv `env_detection` | `EnvironmentFile=/etc/bovisense/iot.env`, drop-in `jetson/systemd/unbuffered.conf` |
| Firebase | Reglas de Firestore | `firestore.rules` + `firebase.json` (emuladores) |
| ESP32 | Firmware Arduino | `comunicacion-iot/esp32/.../*.ino` (sin binario versionado) |

## 13. Puntos de extensión

- **Nuevo comando IoT**: añadir a `COMMANDS` (`backend/src/services/iotProtocol.js:4`),
  al mapa `SECURE_COMMAND_LABELS` y a `execute_secure_command`
(`jetson/lora_jetson_rx.py:117,1318`) y, si aplica, al menú de la app.
- **Nuevo tracker**: agregar la clase al mapa de `tracker_classes`
  (`jetson/run_bovino.py:1440-1448`) y a `create_tracker`
  (`jetson/run_bovino.py:1921`). La inferencia no cambia.
- **Nueva métrica de conteo**: los contadores ya se publican por
  `summary_fields()` de cada tracker (`jetson/run_bovino.py:1897-1915`).
- **Nueva pantalla de ganadero**: crear `*_page.dart`, su viewmodel y un método
  en `GanaderoRepository`; registrar el provider si es de sesión.
- **Nuevo rol**: extender `requireRoles` y el enrutado de `AuthGate`
  (`frontend/lib/views/auth_gate.dart:24-32`), y la validación de rol en
  `backend/src/controllers/usuarioController.js:33`.
- **Reidentificación global (fase futura)**: el código deja el punto natural en
  `_match_recent_identity` (`jetson/run_bovino.py:1541`), que hoy usa descriptores
  HSV en lugar de un modelo ReID entrenado.

## 14. Gobernanza de la arquitectura

- **Verificación automática disponible**: `flutter analyze` con
  `flutter_lints`, `py_compile` para los scripts de la Jetson y `npm test` con el
  runner de Node. No hay verificación de límites de arquitectura ni CI.
- **Documentación de decisiones**: `AGENTS.md` funciona como bitácora de
  incidentes y decisiones; `docs/seguridad-y-despliegue.md` fija los cambios
  incompatibles de protocolo.
- **Práctica recomendada** (no implementada): pipeline de CI con los tres
  conjuntos de pruebas y una verificación de que app, firmware y receptor
  comparten la misma versión de protocolo.

## 15. Registro de decisiones arquitectónicas (ADR)

| Decisión | Contexto | Consecuencias |
|----------|----------|---------------|
| **Protocolo binario-textual C1/R1 con HMAC en lugar de JSON sobre LoRa** | El puente no debe conocer secretos y el canal LoRa es limitado (`docs/seguridad-y-despliegue.md`) | Positivo: puente opaco y verificable. Negativo: cambios incompatibles exigen desplegar app, firmware y receptor juntos |
| **Firestore como única fuente de verdad de usuarios y conteos** | Ya existía Firebase en el proyecto y el backend corre en Node con Admin SDK | Positivo: identidad y datos unificados. Negativo: dependencia de red en cada operación y estado de sesión duplicado con la Jetson |
| **Cortar el servicio con `IDLE` cuando el equipo no tiene sesión** | Incidente real de sesión fantasma (`AGENTS.md` sección 12) | Positivo: recuperación automática. Negativo: exige que la Jetson responda `IDLE` correctamente ante cualquier consulta |
| **Tracker BoT-SORT con GMC sobre detecciones existentes, sin cambiar el detector** | Requisito explícito de no reemplazar MobileNet SSD (`jetson/tracking.md`) | Positivo: se conserva lo validado. Negativo: el subconteo por detecciones perdidas no se puede corregir en el tracker |
| **Recuento por identidad (`counted_track_ids`) y no por detección** | Evitar doble conteo de un animal visible en cientos de frames | Positivo: conteo estable por sesión. Negativo: depende de la continuidad del track; requiere ReID o proyección al suelo para identidad global |
| **Registrar solo la operación más reciente por usuario (`OperacionesUsuarios`) y bloquear su acceso mientras está pendiente** | Firebase Auth y Firestore no comparten transacción | Positivo: nunca queda un usuario a medio crear accesible. Negativo: un fallo deja la cuenta bloqueada hasta reintentar con los mismos datos |
| **Sondeo periódico en la app en lugar de notificaciones del dispositivo** | El puente BLE no empuja eventos con fiabilidad | Positivo: simple y observable. Negativo: consume peticiones (2 transacciones por ciclo) y depende del backend |

## 16. Blueprint para desarrollo nuevo

Flujo sugerido (derivado de cómo está construido el repositorio):

1. **Backend**: crear/ajustar `routes` → `controller` → `service`; validar
   entrada con `utils/validation`; añadir caso a `backend/test/`.
2. **App**: modelo → método de repositorio → viewmodel → vista; registrar
   providers si el estado es de sesión.
3. **Borde**: si toca el protocolo, actualizar backend y Jetson a la vez y
   ampliar `jetson/test_secure_protocol.py`.
4. **Verificación mínima**: `npm test`, `flutter analyze && flutter test`,
   `py_compile` de los scripts tocados.
5. **Documentación**: añadir la sección correspondiente en `docs/` y registrar
   el cambio en `AGENTS.md`.

Errores frecuentes a evitar en este código: cambiar el protocolo sin tocar los
tres extremos; contar detecciones en lugar de identidades; eliminar el estado
SQLite de la Jetson; asumir que `127.0.0.1` del teléfono es la laptop; y
modificar el archivo `usuarioRoute.js` (no está montado).

## 17. Mantenimiento de este blueprint

Generado el 2026-10-12 a partir del commit `84dc003` y del árbol de trabajo con
los cambios locales de `jetson/run_bovino.py`. Debe actualizarse cuando cambie
alguno de estos elementos: protocolo C1/R1, esquema de Firestore, contratos HTTP,
selección de tracker, o topología de despliegue.

## Evidencia consolidada

- `backend/src/**`, `backend/test/**`, `backend/package.json`, `backend/vercel.json`
- `frontend/lib/**`, `frontend/test/**`, `frontend/pubspec.yaml`, `frontend/android/**`
- `jetson/*.py`, `jetson/systemd/unbuffered.conf`
- `comunicacion-iot/esp32/**`, `comunicacion-iot/docs/**`, `comunicacion-iot/hardware/**`
- `firestore.rules`, `firebase.json`, `.gitignore`, `AGENTS.md`, `README.md`
- `docs/codebase/.codebase-scan.txt`
