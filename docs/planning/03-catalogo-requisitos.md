# 03 — Catálogo de requisitos

Requisitos extraídos de las fuentes históricas (Fase 2 de la skill) y
clasificados tras contrastarlos con el código y las pruebas (Fase 3).

**Estados permitidos**: `PROPUESTA`, `PENDIENTE_APROBACION`, `APROBADA`,
`EN_PROGRESO`, `IMPLEMENTADA_SIN_VALIDAR`, `VALIDADA`, `BLOQUEADA`,
`DESCARTADA`.

Criterio de clasificación:

- `VALIDADA`: existe implementación **y** una prueba automatizada o un registro
  de ejecución documentado que la ejercita.
- `IMPLEMENTADA_SIN_VALIDAR`: existe código, pero no hay prueba ni verificación
  en hardware.
- `PENDIENTE_APROBACION`: requiere una decisión del equipo/usuario.
- `BLOQUEADA`: depende de hardware o de un tercero.
- `PROPUESTA`: recomendación técnica; **no** es requisito aprobado.
- `DESCARTADA`: pertenece a una etapa anterior del proyecto.

## 1. Flutter / App Android

| ID | Requisito | Fuente | Estado | Evidencia |
|----|-----------|--------|--------|-----------|
| R-FLUTTER-01 | Autenticación con Firebase y roles `administrador` / `usuario` | S4:6-8, S7:15-41 | IMPLEMENTADA_SIN_VALIDAR (probado a mano) | `frontend/lib/data/repositories/auth_repository.dart`, `frontend/lib/views/auth_gate.dart:24-32` |
| R-FLUTTER-02 | Flujo de conteo guiado por pasos (conectar, revisar, preparar, iniciar, detener, resultado) | S4:80-103 | IMPLEMENTADA_SIN_VALIDAR | `frontend/lib/views/ganadero/estado_dispositivo_page.dart` (usar `StepFlowItem`) |
| R-FLUTTER-03 | Guardar el conteo solo con prueba firmada; nunca con una cantidad declarada por el cliente | S4:111-125, S6 | VALIDADA | `backend/test/integration/api.test.js` (conteo parcial rechazado con 400) |
| R-FLUTTER-04 | No permitir iniciar conteo sin configuración de finca | S4:64 | VALIDADA en backend; app sin prueba | `backend/src/services/iotService.js:43`; guarda en `estado_dispositivo_page.dart` |
| R-FLUTTER-05 | Errores traducidos a lenguaje no técnico, con acción concreta | S4:127-140 | VALIDADA | `frontend/test/ble_failure_test.dart`, `frontend/test/api_client_test.dart` |
| R-FLUTTER-06 | Detalles técnicos en sección colapsable; no exponer `pid`, `session`, `reason` como información principal | S4:101-103 | IMPLEMENTADA_SIN_VALIDAR | `TechnicalDetails` en `estado_dispositivo_page.dart:870-885` |
| R-FLUTTER-07 | Alertas visibles en la interfaz y marcables como leídas | S7:28-31 | VALIDADA | `frontend/test/alert_item_test.dart`, integración backend, `historial_conteos_page.dart` |
| R-FLUTTER-08 | Saludo con nombre y apellido paterno | S2 §18 | VALIDADA | `frontend/test/admin_usuarios_test.dart` (`nombreCorto`) |
| R-FLUTTER-09 | Confirmación al cerrar sesión y al usar el botón retroceder | S2 §19, §20 | VALIDADA | `frontend/test/exit_confirm_test.dart`, `frontend/test/auth_views_test.dart` |
| R-FLUTTER-10 | `AppConfig` sin constantes heredadas de ESP8266 ni credenciales en el código | S2 §10.5, S1 Fase 10 | VALIDADA | `frontend/lib/core/config/app_config.dart` (solo `apiBaseUrl` y soporte) |
| R-FLUTTER-11 | Gestión de usuarios en el panel de administración (alta, edición, baja, búsqueda, filtros) | S7:17-21 | VALIDADA | `frontend/test/admin_usuarios_test.dart`, integración backend |
| R-FLUTTER-12 | Modo sin conexión (caché local de datos) | S9 (`docs/codebase/CONCERNS.md`) | PROPUESTA | No implementado; sin caché en `api_client.dart` |
| R-FLUTTER-13 | Publicación en Play Store (`applicationId` definitivo y firma de release) | S2 §6.5, §21.5 | PENDIENTE_APROBACION | `frontend/android/app/build.gradle.kts:27,44-47` |

## 2. Node.js / Backend

| ID | Requisito | Fuente | Estado | Evidencia |
|----|-----------|--------|--------|-----------|
| R-NODE-01 | API REST con autenticación por token de Firebase y autorización por rol | S1 Fase 5, S4:147 | VALIDADA | `backend/test/integration/api.test.js` (401 sin token, 403 por rol) |
| R-NODE-02 | No generar datos simulados ni aleatorios: solo datos reales | S4:19, S4:121-123 | VALIDADA | No hay generación aleatoria de conteos; el conteo proviene de `proof` (`ganaderoController.js:329-368`) |
| R-NODE-03 | Validación estricta de toda entrada, sin confiar en el cliente | S1 Fase 9, S4:145-146 | VALIDADA | `backend/test/security.test.js` (4 casos) |
| R-NODE-04 | Operaciones de usuario idempotentes ante reintentos | S2 §10, S1 Fase 4 | VALIDADA | `backend/src/services/userService.js:12-35`; integración de serialización de cédulas |
| R-NODE-05 | Guardado de conteo idempotente y coherente con la sesión firmada | S6 | VALIDADA | Integración: segundo guardado devuelve 200 |
| R-NODE-06 | Historial y alertas con paginación real (cursor) | S7:25-31, S2 §16 | VALIDADA | Test de 3 páginas con cursor |
| R-NODE-07 | Listado de usuarios ordenado, con resumen y sin operaciones pendientes silenciosas | S2 §17 | VALIDADA | Integración: orden alfabético, resumen, mensaje de operación pendiente |
| R-NODE-08 | Emisión y verificación de tramas C1/R1 con HMAC-SHA256 y expiración | S6, S2 §3 | VALIDADA | `backend/test/security.test.js`, integración del ciclo completo |
| R-NODE-09 | Compatibilidad con datos de la etapa anterior (colecciones heredadas) | S2 §16, código | **VALIDADA** (prueba añadida el 2026-10-12) | `test/integration/api.test.js` (*legacy collections are merged without duplicating records*); ver observación `C-14` |
| R-NODE-10 | Registro de trazas correlacionables (`X-Request-Id`) y errores sin filtrar detalles | S1 Fase 12, S1 Fase 13 | **VALIDADA** (prueba añadida el 2026-10-12) | `backend/src/app.js:27-38,62-68`; `test/integration/api.test.js` (*tracing, rate limit headers…*) |
| R-NODE-11 | Límite de tasa y tamaño de cuerpo | S1 Fase 20 | **VALIDADA** (límite configurable con `RATE_LIMIT_MAX`) | `backend/src/app.js:18-22`; casos de `413` y `400` en integración |

## 3. Vercel (despliegue del backend)

| ID | Requisito | Fuente | Estado | Evidencia |
|----|-----------|--------|--------|-----------|
| R-VERCEL-01 | Exponer la API como función serverless reutilizando la app Express | S3:121-140 (segunda etapa), S10 (commits *"se exporto express para serverless vercel"*) | IMPLEMENTADA_SIN_VALIDAR | `backend/api/index.js`, `backend/vercel.json` |
| R-VERCEL-02 | Coherencia con proxy inverso (`trust proxy`) para el límite por IP | Código | IMPLEMENTADA_SIN_VALIDAR | `backend/src/app.js:13,18-21` |
| R-VERCEL-03 | Variables de entorno de producción definidas (incluida la cuenta de servicio como JSON) | S6 | PENDIENTE_APROBACION | `backend/src/config/firebaseAdmin.js:15-16`; el proyecto mantiene alcance local |
| R-VERCEL-04 | Verificar si el despliegue está activo y con qué dominio | S9 (`CONCERNS.md`) | PENDIENTE_APROBACION | Sin evidencia en el repositorio |

## 4. IoT (ESP32 y protocolo)

| ID | Requisito | Fuente | Estado | Evidencia |
|----|-----------|--------|--------|-----------|
| R-IOT-01 | El puente no conoce la clave compartida: solo retransmite tramas opacas | S6, S2 §1 | IMPLEMENTADA_SIN_VALIDAR (firmware) | `.ino:10,245-249` |
| R-IOT-02 | Protocolo C1/R1 firmado con expiración nominal de 60 s | S6, S2 §3 | VALIDADA | `backend/test/security.test.js`, `jetson/test_secure_protocol.py` |
| R-IOT-03 | Radio 433 MHz, SF7, BW 125 kHz, CR 4/5, CRC activado, SyncWord `0xF3` | S3:194-211, S2 §4 | VALIDADA en parámetros (sin medición de enlace) | `.ino:39-47`, `jetson/lora_jetson_rx.py:36-42`, log de arranque en `S2` §4 |
| R-IOT-04 | RST del SX1278 puenteado a 3.3 V (pin 17); DIO0 en pin 31; pin 29 libre | S2 §4 (indicación del usuario) | VALIDADA (log de arranque) | `jetson/lora_jetson_rx.py:34`; mensajes de arranque; `AGENTS.md` §4 |
| R-IOT-05 | Un único propietario del SPI | S2 §5 | VALIDADA | `jetson/test_secure_protocol.py` (`test_only_one_receiver_can_own_spi`) |
| R-IOT-06 | El receptor solo debe ejecutar comandos autenticados | S1 Fase 5, S6 | **VALIDADA** (corregido el 2026-10-12: se eliminó el camino heredado y se añadió prueba) | `jetson/lora_jetson_rx.py` (`maybe_reply_to_command`); `test_secure_protocol.py::test_unsigned_frames_never_execute_commands` |
| R-IOT-07 | Verificar que el firmware grabado coincide con el del repositorio | S2 §6.3 | BLOQUEADA | Requiere acceso al prototipo y puerto serie |

## 5. Jetson (radio, sesión y tracking)

| ID | Requisito | Fuente | Estado | Evidencia |
|----|-----------|--------|--------|-----------|
| R-JETSON-01 | Tracking posterior a la inferencia, sin reemplazar el detector MobileNet SSD | S5 (regla principal) | IMPLEMENTADA_SIN_VALIDAR | `jetson/run_bovino.py` (`infer_worker`, `create_tracker`) |
| R-JETSON-02 | BoT-SORT con compensación de movimiento global (dron en movimiento) | S5 (tracker recomendado) | IMPLEMENTADA_SIN_VALIDAR | `jetson/run_bovino.py:1438-1530`; la librería no estaba instalada en el entorno analizado |
| R-JETSON-03 | No incorporar un modelo ReID con CNN en esta fase | S5 (sección ReID) | VALIDADA (sin CNN) con divergencia | `jetson/run_bovino.py` (heurística HSV en `_reid_score`); ver `C-07` |
| R-JETSON-04 | Poder ejecutar sin tracker para comparar comportamiento | S5 (compatibilidad hacia atrás) | IMPLEMENTADA_SIN_VALIDAR | `--tracker none`; ejercitado con harness manual |
| R-JETSON-05 | Un mismo `tracker_id` no puede generar dos incrementos en la misma sesión | S5 (counted ids) | **VALIDADA** (prueba añadida el 2026-10-12) | `jetson/run_bovino.py:1726-1750`; `jetson/test_tracking_logic.py` |
| R-JETSON-06 | Reset del estado de tracking y conteo al iniciar una sesión nueva | S5 (reset del conteo) | IMPLEMENTADA_SIN_VALIDAR | El tracker se construye por ejecución del worker (`create_tracker` en el proceso hijo) |
| R-JETSON-07 | Responder `IDLE` en lugar de `ERROR` cuando el equipo no tiene sesión | S2 §12 | VALIDADA | `jetson/test_secure_protocol.py` (4 casos) |
| R-JETSON-08 | El worker publica `COUNT_UPDATE`/`COUNT_FINAL` y el receptor los interpreta | S2 §2, S5 | IMPLEMENTADA_SIN_VALIDAR | `jetson/run_bovino.py:103-155`, `jetson/lora_jetson_rx.py:976-1005` |
| R-JETSON-09 | El dispositivo no controla RST por GPIO | S2 §4, §10.7 | VALIDADA | `jetson/test_secure_protocol.py` (`test_receiver_never_controls_reset_by_gpio`) |
| R-JETSON-10 | Detección de bovinos a 20-30 m de altitud con cámara IMX219 | S5 (contexto), S2 §6.1 | BLOQUEADA | Errores Argus/GStreamer documentados; requiere hardware |
| R-JETSON-11 | Duración máxima de sesión de 600 s | Código | PENDIENTE_APROBACION | `jetson/lora_jetson_rx.py:62`; confirmar con la operación real |
| R-JETSON-12 | Mejorar el recall de detección en objetos pequeños (mosaicos) | S9 (`CONCERNS.md`) | PROPUESTA | No implementado; recomendación técnica, no requisito aprobado |

## 6. Transversales

| ID | Requisito | Fuente | Estado | Evidencia |
|----|-----------|--------|--------|-----------|
| R-X-01 | Auditoría en modo lectura antes de corregir; sin cambios sin autorización | S1:99-103, S1:1499-1517 | VALIDADA (cumplido aquí) | Esta consolidación no modificó código ni documentos históricos |
| R-X-02 | No marcar como seguro o validado nada sin evidencia | S1:1471-1480 | VALIDADA | Criterios de estado de este catálogo |
| R-X-03 | Ningún secreto en el repositorio; rotar los expuestos | S1 Fase 10, S2 §6.7 | PARCIAL | `.env` y cuenta de servicio ignorados; **dos `google-services.json` versionados**; credenciales en archivos locales (`C-04`) |
| R-X-04 | Pruebas automatizadas en los tres módulos | S1 Fase 22, S4:202-209 | VALIDADA | 4 unitarias + 10 integración (backend), 32 (app), 21 (Jetson) |
| R-X-05 | Documentación técnica centralizada y navegable | Esta solicitud, S9 | VALIDADA | `docs/README.md`, `docs/codebase/`, `docs/arquitectura/`, `docs/planning/` |
| R-X-06 | Registro de decisiones y traspaso entre sesiones | S2 (encabezado) | VALIDADA | `AGENTS.md` §10-§22 |
| R-X-07 | No desplegar ni hospedar hasta completar QA y validación de campo | S2 (encabezado), S2 §9 | APROBADA (vigente) | `AGENTS.md` encabezado |
| R-X-08 | Integración continua que ejecute las pruebas | S9 (`CONCERNS.md`), S1 Fase 24 | IMPLEMENTADA_SIN_VALIDAR (workflow añadido el 2026-10-12; falta verlo correr en GitHub) | `.github/workflows/ci.yml` (4 jobs: backend, integración, Flutter, Jetson) |
| R-X-09 | Matriz de trazabilidad requisito ↔ código ↔ prueba | Esta solicitud | VALIDADA | `07-matriz-trazabilidad.md` |

## 7. Requisitos descartados (etapas anteriores)

| ID | Requisito original | Fuente | Motivo de descarte |
|----|--------------------|--------|--------------------|
| D-01 | Descubrimiento del ESP8266 por UDP/HTTP y `baseUrl` dinámico | S3:50-85 | El firmware ESP8266 se eliminó del repositorio y los servicios de la app también; el transporte actual es BLE (`commit 7d10336`) |
| D-02 | Protocolo de comandos `CMD:` / respuestas `RESP:` y `JETSON_STATUS:` / `JETSON_COUNT:` | S3:187-240, S4:11-18,199-200 | Sustituido por C1/R1 firmado (`S6`, `commit 7d10336`) |
| D-03 | Ejecutar el detector con `--source http://192.168.1.4:8080/video` | S3:307-329 | Hoy la fuente por defecto es `csi://0` (`jetson/lora_jetson_rx.py:52`) |
| D-04 | SPI a 500 kHz y TX a 2 dBm | S3:268-278 | El código vigente usa 10 kHz y 17 dBm (`jetson/lora_jetson_rx.py:22,42`) |
| D-05 | Control del RST por GPIO en el script | S3:283-287 | Sustituido por RST puenteado a 3.3 V (`S2` §4) |
| D-06 | Landing page Next.js y `pkill -x cloudflared` | S4:229-281 | Contenido ajeno al proyecto móvil, incluido por error en el archivo |

## 8. Evidencia

- Documentos fuente citados como `S#` en `01-inventario-fuentes.md`.
- Código y pruebas: rutas indicadas en cada fila.
- Resultados de prueba: `AGENTS.md` §8 y `docs/codebase/TESTING.md`.
