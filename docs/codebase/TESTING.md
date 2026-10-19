# Testing Patterns

## Core Sections (Required)

### 1) Test Stack and Commands

- **Backend**: runner integrado de Node (`node --test`) y `node:assert/strict`,
  sin framework externo (`backend/test/security.test.js:1-2`).
- **App**: `flutter_test` con `MockClient` de `package:http/testing.dart` para
  simular HTTP (`frontend/test/api_client_test.dart:1-6`).
- **Jetson**: `unittest` de la biblioteca estándar con dobles de hardware
  (`jetson/test_secure_protocol.py:1-12`).

```bash
# Backend
cd backend && npm test                      # unitarias
cd backend && npm run test:integration      # requiere emuladores de Firebase

# App
cd frontend && flutter analyze
cd frontend && flutter test

# Jetson
cd jetson && python3 -m unittest test_secure_protocol.py
cd jetson && python3 -m unittest test_tracking_logic.py
python3 -m py_compile run_bovino.py lora_jetson_rx.py secure_protocol.py

# Integración continua (las mismas suites, sin hardware)
# .github/workflows/ci.yml -> jobs: backend, backend-integration, frontend, jetson

# Cobertura: no configurada en ningún módulo
```

Ejecución de integración documentada (los tests se niegan a correr sin
emuladores, `backend/test/integration/api.test.js:6-8`):

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 PATH=/usr/lib/jvm/java-21-openjdk-amd64/bin:$PATH \
  firebase emulators:exec --only auth,firestore --project demo-bovisense \
  "npm --prefix backend run test:integration"
```

### 2) Test Layout

| Módulo | Ubicación | Nomenclatura | Casos |
|--------|-----------|--------------|-------|
| Backend unitario | `backend/test/security.test.js` | `<tema>.test.js` | 4 |
| Backend integración | `backend/test/integration/api.test.js` | `<tema>.test.js` bajo `integration/` | 15 |
| App | `frontend/test/**` | `<tema>_test.dart` | 44 |
| Jetson (receptor y protocolo) | `jetson/test_secure_protocol.py` | `test_<tema>.py` | 29 |
| Jetson (tracking y conteo) | `jetson/test_tracking_logic.py` | `test_<tema>.py` | 9 |

Detalle de la app (`rg -c "^\s*(test|testWidgets)\("`):

| Archivo | Casos | Foco |
|---------|-------|------|
| `test/admin_usuarios_test.dart` | 5 | Parseo del listado y tarjeta de usuario |
| `test/api_client_test.dart` | 7 | HTTPS, allowed hosts, sesión cambiada, ayuda de conexión |
| `test/utils/formatters_test.dart` | 8 | Formateo de fechas y signos |
| `test/auth_views_test.dart` | 3 | Reglas del splash, enlace de WhatsApp, confirmación de logout |
| `test/alert_item_test.dart` | 2 | Alerta leída/no leída |
| `test/ble_failure_test.dart` | 2 | Traducción de fallas de Bluetooth y textos |
| `test/command_queue_test.dart` | 4 | Serialización, fallo que no corta la cola e invalidación al desconectar |
| `test/design_system_test.dart` | 9 | Contraste WCAG de los tokens, tema global y componentes compartidos |
| `test/exit_confirm_test.dart` | 2 | Diálogo de salida y `onBack` |
| `test/widget_test.dart` | 1 | Marcador de posición de la plantilla |

No hay `setUp` global ni archivos de preparación compartidos; cada archivo se
autoabastece de dobles.

### 3) Test Scope Matrix

| Scope | Covered? | Typical target | Notes |
|-------|----------|----------------|-------|
| Unit | Sí | Validación, protocolo C1/R1, utilidades de cajas, cola de comandos, formateadores, contraste de tokens | Backend 4; app 44; Jetson 29 |
| Integration | Sí | API completa contra emuladores de Firebase; receptor con SPI simulado | 15 casos de backend; las pruebas de la Jetson simulan el SX1278 |
| E2E (dispositivo real) | No | Flujo `H → S → Q → T → R` con radio, cámara y teléfono | PENDIENTE DE VERIFICACIÓN: requiere hardware (`AGENTS.md`, secciones 6 y 8) |

### 4) Mocking and Isolation Strategy

- **Backend**: se sustituyen servicios externos por dobles inyectados
  (`createUserService({ db, auth, FieldValue, enviarActivacion })`,
  `backend/test/integration/api.test.js` usa un `enviarActivacion` que lanza
  error para probar el camino de respaldo). Firebase se reemplaza por
  **emuladores reales**, no por mocks.
- **Aislamiento de datos**: los tests de integración borran Firestore y las
  cuentas del emulador antes de correr y crean cuentas propias
  (`backend/test/integration/api.test.js`, `before(...)`).
- **Correo real bloqueado**: la suite vacía `SMTP_HOST`, `SMTP_USER`,
  `SMTP_PASS` y `SMTP_FROM` antes de cargar la app para no enviar correos
  (`backend/test/integration/api.test.js`, comentario previo a los `require`).
- **App**: `MockClient` responde JSON enlatado y permite verificar cabeceras
  (`frontend/test/api_client_test.dart:52-70`); el estado se limita a objetos
  creados dentro del test.
- **Jetson**: `FakeSpi` emula los registros del SX1278 (IRQ, FIFO, `OP_MODE`) y
  `patch.object` neutraliza `sync_worker_state`, `is_worker_alive` y
  `spidev.SpiDev` (`jetson/test_secure_protocol.py`, clases `FakeSpi` y
  `radio()`).

### 5) Coverage and Quality Signals

- Umbral de cobertura: no configurado (`PENDIENTE DE VERIFICACIÓN`: no hay
  `jest.config`, `.nycrc` ni `--coverage` en los scripts).
- Última ejecución del backend y la Jetson (2026-10-17): backend unitario en
  verde, **15/15** integración, **29/29** receptor y **9/9** tracking;
  `py_compile` de los tres scripts de la Jetson. La app se revalidó el
  2026-10-18: `flutter analyze` sin hallazgos y **44/44** casos.
- Huecos conocidos: sin pruebas de UI end-to-end, sin pruebas de resiliencia de
  red, sin cobertura instrumentada y sin prueba de la publicación de hooks del
  worker (`COUNT_UPDATE`/`COUNT_FINAL` se verifican de forma indirecta).
- Zonas históricamente frágiles por cambios recientes: `run_bovino.py`
  (tracker), `lora_jetson_rx.py` (radio y sesión) y
  `ganaderoController.js` (paginación y compatibilidad con colecciones
  heredadas) — ver `docs/codebase/CONCERNS.md`.

### 6) Evidence

- `backend/package.json:6-11`, `backend/test/security.test.js`,
  `backend/test/integration/api.test.js`
- `frontend/test/` (10 archivos, 44 casos)
- `jetson/test_secure_protocol.py` (29 casos)
- `docs/codebase/.codebase-scan.txt` (sección PERFORMANCE & TESTING)
- `AGENTS.md` sección 8 (resultados de la última corrida)

## Extended Sections

### Patrones de prueba representativos

| Patrón | Uso | Ejemplo |
|--------|-----|---------|
| Simulación de hardware por dobles | Sustituir SX1278 sin radio real | `jetson/test_secure_protocol.py`, `class FakeSpi` |
| Tramas firmadas de prueba | Validar HMAC, expiración y replay | `jetson/test_secure_protocol.py`, `command()` y `sign()` |
| Emuladores en lugar de mocks | Verificar reglas de Firestore y transacciones reales | `backend/test/integration/api.test.js` |
| Cliente HTTP simulado | Forzar códigos y errores de red | `frontend/test/api_client_test.dart` con `MockClient` |
| Pruebas de widget sin Firebase | Renderizar componentes puros | `frontend/test/alert_item_test.dart`, `exit_confirm_test.dart` |

### Limitación estructural de la app para pruebas

Las páginas que dependen de `AuthViewModel` requieren `FirebaseAuth.instance`,
por lo que no pueden instanciarse en `flutter test` sin inicializar Firebase; por
eso las pruebas de widget cubren componentes aislados en lugar de pantallas
completas (evidencia: `frontend/test/auth_views_test.dart` prueba el guard de
salida sin montar la app completa).
