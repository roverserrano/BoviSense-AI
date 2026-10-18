# Codebase Structure

Repositorio único con cuatro módulos desplegables y documentación. No es un
monorepo con workspaces: cada módulo tiene su propio gestor de paquetes y ciclo
de build (`docs/codebase/.codebase-scan.txt`, sección `MONOREPO SIGNALS`).

## Core Sections (Required)

### 1) Top-Level Map

| Path | Purpose | Evidence |
|------|---------|----------|
| `backend/` | API REST Express + integración Firebase Admin + protocolo IoT | `backend/src/app.js:59-60` |
| `backend/api/index.js` | Adaptador serverless que exporta la app Express | `backend/api/index.js:1-3` |
| `backend/src/` | Código fuente del backend (routes, controllers, services, utils) | `find backend/src -type f` |
| `backend/test/` | Pruebas unitarias y de integración | `backend/package.json:9-10` |
| `frontend/` | Aplicación Flutter (Android como plataforma objetivo real) | `frontend/pubspec.yaml:1` |
| `frontend/lib/` | Código Dart: core, data, viewmodels, views | `find frontend/lib -name "*.dart"` |
| `frontend/android/` | Proyecto Android: manifiesto, Gradle, íconos, splash nativo | `frontend/android/app/build.gradle.kts` |
| `frontend/test/` | Pruebas de widget y unitarias | `find frontend/test -type f` |
| `jetson/` | Receptor LoRa + protocolo seguro + detector TensorRT | `jetson/lora_jetson_rx.py`, `jetson/run_bovino.py` |
| `jetson/systemd/` | Drop-in de systemd para logs sin buffer | `jetson/systemd/unbuffered.conf:1-2` |
| `comunicacion-iot/` | Firmware del puente y documentación de hardware/protocolo | `comunicacion-iot/esp32/.../*.ino`, `comunicacion-iot/docs/` |
| `docs/` | Documentación técnica (esta carpeta) y despliegue/seguridad | `docs/README.md`, `docs/seguridad-y-despliegue.md` |
| `firestore.rules`, `firebase.json` | Seguridad de Firestore y configuración de emuladores | `firebase.json:1-10` |
| `README.md`, `.agents/Instrucciones/AGENTS.md` | Presentación del producto y bitácora de traspaso técnico | `README.md`, `.agents/Instrucciones/AGENTS.md` |
| `.agents/skills/` | Skills instaladas para análisis de código y arquitectura | `skills-lock.json` |

### 2) Entry Points

- **Backend HTTP**: `backend/src/app.js` exporta la app Express y solo escucha en
  puerto si se ejecuta directamente (`backend/src/app.js:70-87`,
  `module.exports = app`). `backend/package.json:7` declara
  `node src/app.js` como `start`.
- **Backend serverless**: `backend/api/index.js` reexporta la app, y
  `backend/vercel.json` enruta todo el tráfico a esa función con
  `maxDuration: 30`.
- **App**: `frontend/lib/main.dart:21` (`Future<void> main()`), que inicializa
  Firebase y monta `BoviSenseApp`; la sesión se resuelve en
  `frontend/lib/views/auth_gate.dart:11-33`.
- **Receptor Jetson**: `jetson/lora_jetson_rx.py:1451` (`def main()`), ejecutado
  por `bovisense-lora.service` con `EnvironmentFile=/etc/bovisense/iot.env`
  (`AGENTS.md`, sección 4).
- **Detector Jetson (worker)**: `jetson/run_bovino.py:2490` (`def main()`),
  lanzado como subproceso por el receptor
  (`jetson/lora_jetson_rx.py:981` define `--source` del worker).
- **Puente ESP32**: `setup()`/`loop()` del sketch
  (`comunicacion-iot/esp32/.../*.ino:384-497`), sin binario compilado en el repo.
- **Scripts de ayuda**: `frontend/run_usb.sh` (publica el puerto con `adb reverse`
  y ejecuta `flutter run`).

### 3) Module Boundaries

| Boundary | What belongs here | What must not be here |
|----------|-------------------|------------------------|
| `backend/src/routes` | Declaración de rutas y middleware de autorización | Lógica de negocio o acceso a Firestore |
| `backend/src/controllers` | Traducción HTTP ↔ dominio, mapeo de documentos, transacciones | Detalles de criptografía o de envío SMTP |
| `backend/src/services` | Dominio reutilizable: protocolo IoT, operaciones de usuario, correo | Objetos `req`/`res` |
| `backend/src/utils` | Validación, paginación, generación de contraseñas | Estado de aplicación |
| `frontend/lib/views` | Widgets y composición visual | Llamadas HTTP directas |
| `frontend/lib/viewmodels` | Estado de pantalla y orquestación | UI |
| `frontend/lib/data/repositories` | Contratos con backend y Firebase | Estado de UI |
| `frontend/lib/data/services` | Transporte: HTTP, BLE, cola de comandos | Reglas de negocio |
| `jetson/` | Radio, protocolo seguro y detector | Lógica de la app o del backend |
| `comunicacion-iot/` | Firmware y documentación de hardware | Código de aplicación |

Evidencia del cumplimiento de los límites: los controladores no contienen
criptografía (vive en `backend/src/services/iotProtocol.js`), los servicios no
reciben `req`/`res` (`backend/src/services/userService.js:5-12`), y las vistas no
importan `http` (ningún archivo de `frontend/lib/views` importa
`package:http`; la única importación está en
`frontend/lib/data/services/api_client.dart:3`).

### 4) Naming and Organization Rules

- **Archivos Dart**: `snake_case` por capa y dominio
  (`frontend/lib/data/services/api_client.dart`,
  `frontend/lib/views/ganadero/estado_dispositivo_page.dart`). Los widgets
  privados usan prefijo `_` (`frontend/lib/views/auth/login_page.dart:289`).
- **Archivos JS**: `camelCase` para utilidades y `PascalCase` semántico para
  controladores/rutas (`ganaderoController.js`, `usuarioRoutes.js`).
- **Python**: `snake_case` para módulos y funciones (`lora_jetson_rx.py`), y
  constantes en `MAYÚSCULAS` para parámetros de hardware
  (`jetson/lora_jetson_rx.py:20-63`).
- **Organización**: por capa dentro de cada módulo; el dominio de la app se
  agrupa por rol de usuario (`views/admin`, `views/ganadero`, `views/auth`).
- **Alias de importación**: no hay `path` aliases ni barrel files; se usan rutas
  relativas (`frontend/lib/main.dart:9-23`).
- **Rutas HTTP**: prefijo por rol (`/api/admin/...`, `/api/ganadero/...`) con
  sustantivos en plural (`backend/src/routes/ganaderoRoutes.js:9-20`).

### 5) Evidence

- `backend/src/app.js:59-61` (montaje de routers)
- `frontend/lib/main.dart:21-60` (arranque de la app)
- `jetson/lora_jetson_rx.py:1307-1561` (argumentos y `main`)
- `docs/codebase/.codebase-scan.txt` (árbol de directorios y métricas)
- `git ls-files` para distinguir código fuente de artefactos

## Extended Sections

### Archivos presentes pero no utilizados (evidencia de estructura muerta)

| Archivo | Estado | Evidencia |
|---------|--------|-----------|
| `backend/src/routes/usuarioRoute.js` | No referenciado por nadie; `app.js` monta `usuarioRoutes.js` | `rg "usuarioRoute(?!/s)" backend/src` sin resultados; `backend/src/app.js:59` |
| `comunicacion-iot/shared/protocol.py`, `constants.py`, `message_examples.json` | Protocolo JSON/WebSocket de la etapa ESP8266, sin referencias en el repo | `rg -l "from shared\|import shared"` sin resultados; cabecera del propio archivo |
| `frontend/{ios,linux,macos,web,windows}/` | Andamiaje generado por Flutter; sin uso declarado | `ls -d frontend/{ios,linux,macos,web,windows}` y `frontend/lib/firebase_options.dart:43-85` |
| `frontend/README.md` | README genérico de Flutter, sin contenido del proyecto | `frontend/README.md:1-5` |

### Archivos de trabajo sin seguimiento en Git (estado al 2026-10-17)

`git status --short` reporta como no versionados: `.agents/skills/` (4 skills),
`.agents/Instrucciones/README.md` y `jetson/tracking.md` (especificación de
trabajo del tracker MOT). Los archivos de trabajo `revicion.txt`, `pasos.txt` y
`.codex` están en `.agents/Instrucciones/` y siguen ignorados por git.
