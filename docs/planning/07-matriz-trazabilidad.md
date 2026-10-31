# 07 — Matriz de trazabilidad

Fase 5 de la skill. Vincula cada requisito con su fuente documental, su estado,
la tarea que lo atiende (si existe), los archivos de código implicados y la
prueba o evidencia que lo respalda.

Códigos de fuente y estado: ver `01-inventario-fuentes.md` y
`03-catalogo-requisitos.md`.

## 1. App Flutter

| Requisito | Fuente | Estado | Tarea | Archivos | Prueba / evidencia |
|-----------|--------|--------|-------|----------|--------------------|
| R-FLUTTER-01 Login con Firebase y roles | S4:6-8, S7:15-41 | IMPLEMENTADA_SIN_VALIDAR | — | `frontend/lib/data/repositories/auth_repository.dart`, `views/auth_gate.dart` | Prueba manual en `AGENTS.md` §5 |
| R-FLUTTER-02 Flujo de conteo por pasos | S4:80-103 | IMPLEMENTADA_SIN_VALIDAR | — | `views/ganadero/estado_dispositivo_page.dart` | Sin prueba de UI |
| R-FLUTTER-03 Guardado solo con prueba firmada | S4:111-125, S6 | VALIDADA | — | `data/repositories/ganadero_repository.dart` | `backend/test/integration/api.test.js` |
| R-FLUTTER-04 No iniciar sin configuración | S4:64 | VALIDADA (backend) | — | `backend/src/services/iotService.js:43`; `estado_dispositivo_page.dart` | Integración (flujo exige config) |
| R-FLUTTER-05 Errores en lenguaje no técnico | S4:127-140 | VALIDADA | — | `data/services/api_client.dart`, `esp32_ble_bridge_service.dart` | `frontend/test/ble_failure_test.dart`, `api_client_test.dart` |
| R-FLUTTER-06 Detalles técnicos colapsables | S4:101-103 | IMPLEMENTADA_SIN_VALIDAR | — | `estado_dispositivo_page.dart:870-885` | Inspección de código |
| R-FLUTTER-07 Alertas visibles y marcables | S7:28-31 | VALIDADA | — | `views/ganadero/historial_conteos_page.dart` | `frontend/test/alert_item_test.dart` + integración |
| R-FLUTTER-08 Saludo con apellido paterno | S2 §18 | VALIDADA | — | `data/models/usuario_model.dart` | `frontend/test/admin_usuarios_test.dart` |
| R-FLUTTER-09 Confirmaciones de salida y logout | S2 §19-20 | VALIDADA | — | `views/common/exit_confirm.dart`, `session_actions.dart` | `frontend/test/exit_confirm_test.dart`, `auth_views_test.dart` |
| R-FLUTTER-10 Sin constantes ni credenciales heredadas | S2 §10.5, S1 F10 | VALIDADA | — | `core/config/app_config.dart` | `rg -i esp8266 frontend/lib` sin resultados |
| R-FLUTTER-11 Gestión de usuarios en el panel | S7:17-21 | VALIDADA | — | `views/admin/*` | `frontend/test/admin_usuarios_test.dart` + integración |
| R-FLUTTER-12 Modo sin conexión | S9 CONCERNS | PROPUESTA | T-19 | `data/services/api_client.dart` | No implementado |
| R-FLUTTER-13 Publicación Android | S2 §6.5, §21.5 | PENDIENTE_APROBACION | T-08 | `android/app/build.gradle.kts` | `flutter build apk --release` |

## 2. Backend Node.js

| Requisito | Fuente | Estado | Tarea | Archivos | Prueba / evidencia |
|-----------|--------|--------|-------|----------|--------------------|
| R-NODE-01 API con autenticación y roles | S1 F5, S4:147 | VALIDADA | — | `middlewares/authMiddleware.js`, `routes/*.js` | `test/integration/api.test.js` (401/403) |
| R-NODE-02 Sin datos simulados | S4:19,121-123 | VALIDADA | — | `controllers/ganaderoController.js:329-368` | Integración del ciclo con `proof` |
| R-NODE-03 Validación estricta | S1 F9, S4:145 | VALIDADA | — | `utils/validation.js` | `test/security.test.js` (4 casos) |
| R-NODE-04 Idempotencia de operaciones | S1 F4 | VALIDADA | — | `services/userService.js:12-35` | Integración (alta duplicada, cédulas) |
| R-NODE-05 Guardado de conteo idempotente | S6 | VALIDADA | — | `controllers/ganaderoController.js:329-368` | Integración (201 y luego 200) |
| R-NODE-06 Paginación con cursor | S7:25-31, S2 §16 | VALIDADA | — | `controllers/ganaderoController.js:162-210` | Integración de 3 páginas |
| R-NODE-07 Listado ordenado con resumen | S2 §17 | VALIDADA | — | `controllers/usuarioController.js:38-62` | Integración |
| R-NODE-08 C1/R1 con HMAC y expiración | S6, S2 §3 | VALIDADA | — | `services/iotProtocol.js` | `test/security.test.js` + integración |
| R-NODE-09 Compatibilidad heredada | Código | VALIDADA | T-14, T-18 | `controllers/ganaderoController.js:127-221` | `legacy collections are merged without duplicating records`; observación C-14 |
| R-NODE-10 Trazas y errores | S1 F12-13 | VALIDADA | — | `src/app.js:27-38,62-68` | `tracing, rate limit headers, body limit and malformed JSON` |
| R-NODE-11 Límite de tasa y de cuerpo | S1 F20 | VALIDADA | — | `src/app.js:18-22` | Casos de 413 y 400 en integración; `RATE_LIMIT_MAX` configurable |

## 3. Vercel

| Requisito | Fuente | Estado | Tarea | Archivos | Prueba / evidencia |
|-----------|--------|--------|-------|----------|--------------------|
| R-VERCEL-01 API como función serverless | S10 (commits), S3 | IMPLEMENTADA_SIN_VALIDAR | T-16 | `backend/api/index.js`, `backend/vercel.json` | Configuración presente |
| R-VERCEL-02 Coherencia con proxy inverso | Código | IMPLEMENTADA_SIN_VALIDAR | T-16 | `backend/src/app.js:13,18-21` | Inspección |
| R-VERCEL-03 Variables de producción | S6 | PENDIENTE_APROBACION | T-16 | `config/firebaseAdmin.js:15-16` | Sin evidencia |
| R-VERCEL-04 Verificar despliegue activo | S9 CONCERNS | PENDIENTE_APROBACION | T-16 | — | Sin evidencia |

## 4. IoT

| Requisito | Fuente | Estado | Tarea | Archivos | Prueba / evidencia |
|-----------|--------|--------|-------|----------|--------------------|
| R-IOT-01 Puente opaco sin clave | S6, S2 §1 | IMPLEMENTADA_SIN_VALIDAR | T-10 | `.ino:10,245-249` | Inspección del sketch |
| R-IOT-02 C1/R1 firmado con expiración | S6, S2 §3 | VALIDADA | — | `secure_protocol.py`, `iotProtocol.js` | `security.test.js`, `test_secure_protocol.py` |
| R-IOT-03 Parámetros de radio | S3:194-211, S2 §4 | VALIDADA (parámetros) | — | `.ino:39-47`, `lora_jetson_rx.py:36-42` | Log de arranque en `AGENTS.md` §4 |
| R-IOT-04 RST a 3.3 V, DIO0 pin 31 | S2 §4 | VALIDADA (log) | — | `lora_jetson_rx.py:34` | Mensajes de arranque |
| R-IOT-05 Un solo propietario del SPI | S2 §5 | VALIDADA | — | `lora_jetson_rx.py:251-272` | `test_only_one_receiver_can_own_spi` |
| R-IOT-06 Solo comandos autenticados | S1 F5, S6 | VALIDADA | — | `lora_jetson_rx.py` (`maybe_reply_to_command`) | `test_unsigned_frames_never_execute_commands`; conflicto C-01 resuelto |
| R-IOT-07 Firmware coincidente | S2 §6.3 | BLOQUEADA | T-10 | `.ino` | Requiere serie del prototipo |

## 5. Jetson

| Requisito | Fuente | Estado | Tarea | Archivos | Prueba / evidencia |
|-----------|--------|--------|-------|----------|--------------------|
| R-JETSON-01 Tracking sin cambiar el detector | S5 | IMPLEMENTADA_SIN_VALIDAR | T-12 | `run_bovino.py` (`infer_worker`, `create_tracker`) | Harness manual 2026-10-12 |
| R-JETSON-02 BoT-SORT con GMC | S5 | IMPLEMENTADA_SIN_VALIDAR | T-11, T-12 | `run_bovino.py:1438-1530` | Librería ausente en el entorno observado |
| R-JETSON-03 Sin ReID con CNN | S5 | VALIDADA con divergencia | T-11 | `run_bovino.py:1497-1560` | Conflicto C-07 |
| R-JETSON-04 Ejecución sin tracker | S5 | IMPLEMENTADA_SIN_VALIDAR | — | `run_bovino.py:1921-1990` | Harness manual |
| R-JETSON-05 Un conteo por track | S5 | VALIDADA | — | `run_bovino.py:1726-1750` | `jetson/test_tracking_logic.py` |
| R-JETSON-06 Reset del estado por sesión | S5 | IMPLEMENTADA_SIN_VALIDAR | T-13 | `create_tracker` en el proceso hijo | Inspección |
| R-JETSON-07 `IDLE` sin sesión | S2 §12 | VALIDADA | — | `lora_jetson_rx.py:840-891` | 4 casos en `test_secure_protocol.py` |
| R-JETSON-08 Hooks del worker | S2 §2, S5 | IMPLEMENTADA_SIN_VALIDAR | T-13 | `run_bovino.py:103-155` | Sin prueba |
| R-JETSON-09 Sin control de RST por GPIO | S2 §4, §10.7 | VALIDADA | — | `lora_jetson_rx.py` | `test_receiver_never_controls_reset_by_gpio` |
| R-JETSON-10 Detección a 20-30 m | S5, S2 §6.1 | BLOQUEADA | T-09, T-12 | `run_bovino.py` | Errores Argus documentados |
| R-JETSON-11 Duración máxima de sesión | Código | PENDIENTE_APROBACION | T-19 | `lora_jetson_rx.py:62` | Sin decisión |
| R-JETSON-12 Mosaicos de detección | S9 CONCERNS | PROPUESTA | T-12 | `run_bovino.py` | No implementado |

## 6. Transversales

| Requisito | Fuente | Estado | Tarea | Archivos | Prueba / evidencia |
|-----------|--------|--------|-------|----------|--------------------|
| R-X-01 Auditoría read-only primero | S1:99-103,1499-1517 | VALIDADA | — | — | Esta consolidación no modificó código |
| R-X-02 Nada validado sin evidencia | S1:1471-1480 | VALIDADA | — | — | Criterios de estado |
| R-X-03 Sin secretos; rotar los expuestos | S1 F10, S2 §6.7 | PARCIAL | T-04, T-05, T-06, T-07 | `.gitignore`, `pasos.txt`, `.codex` | `git ls-files`, `git check-ignore`; conflicto C-04 |
| R-X-04 Pruebas en los tres módulos | S1 F22, S4:202-209 | VALIDADA | T-13, T-14, T-15 | `backend/test`, `frontend/test`, `jetson/test_secure_protocol.py` | 4 + 10 + 32 + 21 casos |
| R-X-05 Documentación centralizada | Solicitud actual, S9 | VALIDADA | T-20 | `docs/**` | `docs/README.md` y subcarpetas |
| R-X-06 Registro de decisiones y traspaso | S2 encabezado | VALIDADA | — | `AGENTS.md` | Secciones 10-22 |
| R-X-07 Sin despliegue hasta validar | S2 encabezado, §9 | APROBADA | — | — | Restricción vigente |
| R-X-08 CI/CD | S9 CONCERNS, S1 F24 | IMPLEMENTADA_SIN_VALIDAR | T-22 | `.github/workflows/ci.yml` | Workflow con 4 jobs; falta la primera ejecución en GitHub |
| R-X-09 Matriz de trazabilidad | Solicitud actual | VALIDADA | — | Este documento | — |

## 7. Cobertura del catálogo

| Estado | Requisitos | Total |
|--------|-----------|-------|
| VALIDADA | R-FLUTTER-03, 04, 05, 07, 08, 09, 10, 11; R-NODE-01 a R-NODE-11; R-IOT-02, 03, 04, 05, 06; R-JETSON-03, 05, 07, 09; R-X-01, 02, 04, 05, 06, 09 | 34 |
| IMPLEMENTADA_SIN_VALIDAR | R-FLUTTER-01, 02, 06; R-VERCEL-01, 02; R-IOT-01; R-JETSON-01, 02, 04, 06, 08; R-X-08 | 12 |
| PENDIENTE_APROBACION | R-FLUTTER-13; R-VERCEL-03, 04; R-JETSON-11 | 4 |
| PROPUESTA | R-FLUTTER-12; R-JETSON-12 | 2 |
| BLOQUEADA | R-IOT-07; R-JETSON-10 | 2 |
| PARCIAL | R-X-03 (archivos limpios; rotación pendiente) | 1 |
| APROBADA | R-X-07 (restricción vigente de no desplegar) | 1 |
| **Total** | | **56** |
| DESCARTADA | D-01 a D-06 (ver catálogo §7) | 6 |

## 8. Lectura de la matriz

- **Ningún requisito del catálogo quedó sin fuente**: todos referencian un
  documento histórico o el propio código vigente.
- **Las 12 filas `IMPLEMENTADA_SIN_VALIDAR`** son la deuda de verificación más
  accionable sin hardware; buena parte depende de hardware (`R-JETSON-01/02/04/06/08`) o de una decisión (`R-VERCEL-03/04`, `R-FLUTTER-13`).
- **Las 2 filas `BLOQUEADA`** y la validación de campo (T-09) son el camino
  crítico del proyecto de grado.
- **Las 3 `PROPUESTA`** no deben tratarse como requisitos aprobados.

## 9. Evidencia

- Catálogo de requisitos: `03-catalogo-requisitos.md`.
- Backlog y tareas: `05-backlog-ejecucion.md`.
- Conflictos: `06-registro-conflictos.md`.
- Pruebas: `docs/codebase/TESTING.md` y `AGENTS.md` §8.
