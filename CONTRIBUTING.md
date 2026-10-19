# Cómo contribuir a BoviSense-AI

Guía corta para trabajar en el repositorio. El detalle de cada tema vive en la
documentación enlazada; aquí está lo esencial.

## Antes de empezar

1. Lee el [índice de documentación](docs/README.md) y las reglas de trabajo en
   [`.agents/Instrucciones/AGENTS.md`](.agents/Instrucciones/AGENTS.md)
   (sección 9).
2. Ejecuta `git status --short` antes de tocar nada: puede haber trabajo de
   otras sesiones sin commitear. No hagas `reset` ni `checkout` destructivos, y
   no sobrescribas cambios ajenos.
3. El proyecto está en fase local: **no** despliegues servicios, reglas ni la
   app, y no toques el hardware (Jetson, ESP32, cableado) sin acordarlo con el
   responsable.
4. No copies secretos (claves, tokens, contraseñas) a documentos, issues ni
   commits. La clave IoT y las credenciales viven fuera de Git.

## Entorno de desarrollo

Los requisitos y la preparación por módulo están en
[`docs/arquitectura/desarrollo.md`](docs/arquitectura/desarrollo.md). Resumen:

| Módulo | Preparación | Ejecución local |
| --- | --- | --- |
| Backend | `cd backend && npm ci` (necesita `.env` privado) | `npm run dev` y `curl http://127.0.0.1:3000/health` |
| App | `cd frontend && flutter pub get` | `bash run_usb.sh` (USB) o `flutter run --dart-define=API_BASE_URL=http://<ip-de-la-laptop>:3000` |
| Jetson | Python 3 con `spidev`; en la Jetson real, el servicio `bovisense-lora` | `python3 lora_jetson_rx.py` solo si el servicio está detenido |

## Pruebas

Ejecuta lo que corresponda a tu cambio antes de darlo por terminado:

```bash
cd backend && npm test                               # unitarias (4 casos)
cd frontend && flutter analyze && flutter test       # app (44 casos)
cd jetson && python3 -m unittest test_secure_protocol.py   # receptor (29 casos)
cd jetson && python3 -m unittest test_tracking_logic.py    # tracking (9 casos)
```

La integración del backend exige emuladores de Firebase (nunca producción) y
JDK 21 para `firebase-tools`:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
PATH=/usr/lib/jvm/java-21-openjdk-amd64/bin:$PATH \
  firebase emulators:exec --only auth,firestore --project demo-bovisense \
  "npm --prefix backend run test:integration"
```

Estado esperado: 4 unitarias de backend, 12 de integración, 32 en Flutter,
22 del receptor Jetson y 9 de tracking. Detalle en
[`docs/codebase/TESTING.md`](docs/codebase/TESTING.md).

## Convenciones

- Sigue [`docs/codebase/CONVENTIONS.md`](docs/codebase/CONVENTIONS.md)
  (nombres, formato, errores y logs).
- Commits en español, en imperativo y con alcance claro.
- Documenta el "por qué" en `AGENTS.md` (bitácora) cuando resuelvas un
  incidente o tomes una decisión relevante.
- Todo cambio que afecte contratos (API, tramas C1/R1, esquema de Firestore)
  debe venir con prueba y con la documentación actualizada.

## Flujo de trabajo

1. Crea una rama desde `dev` (el trabajo activo vive en `dev`, no en `main`).
2. Haz cambios pequeños y verificables; corre las pruebas del módulo.
3. Actualiza la documentación afectada (la tabla de abajo resume el mapeo).
4. Abre un Pull Request describiendo el cambio, las pruebas ejecutadas y el
   hardware involucrado (si aplica).

| Si cambias… | Actualiza… |
| --- | --- |
| Endpoints o contratos HTTP | `docs/arquitectura/api-http.md` |
| Protocolo C1/R1 o LoRa | `comunicacion-iot/docs/*`, `docs/arquitectura/integraciones-iot.md` |
| Esquema o reglas de Firestore | `docs/codebase/INTEGRATIONS.md`, `docs/seguridad-y-despliegue.md` |
| Despliegue o servicio systemd | `docs/arquitectura/despliegue.md`, `jetson/README.md` |
| Comandos y flujo de desarrollo | `docs/arquitectura/desarrollo.md` |
| Hitos o correcciones relevantes | `CHANGELOG.md` |

## Integración continua

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) ejecuta cuatro jobs sin
secretos: backend unitario, backend con emuladores, Flutter (`analyze` +
`test`) y Jetson (`unittest`). Un Pull Request debe pasar los cuatro.

## ¿Dudas?

Revisa `docs/` y el historial de
[`AGENTS.md`](.agents/Instrucciones/AGENTS.md); si el tema es de producto o de
hardware, pregunta al responsable del proyecto antes de asumir.
