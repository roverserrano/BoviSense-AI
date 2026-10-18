# Backend de BoviSense

API REST en Node.js/Express que da servicio a la app Flutter y firma/verifica
el protocolo de conteo con la Jetson.

## Qué hace

- Autenticación con Firebase Auth (token Bearer + perfil Firestore con rol y
  estado).
- Administración de usuarios (`/api/admin/usuarios`): alta, edición y baja con
  paginación, índice único de cédula y operaciones idempotentes.
- Módulo ganadero (`/api/ganadero`): finca, panel, conteos, alertas y
  comandos/respuestas IoT firmados (`C1`/`R1`, HMAC-SHA256).
- Verificación de la prueba final de conteo antes de guardarlo: nunca se acepta
  una cantidad inventada por el cliente.
- Salud del servicio en `/health` (200 solo si Auth y Firestore responden,
  cacheado 15 s).

El contrato completo de endpoints (entradas, salidas, autorización y códigos de
error) está en [`docs/arquitectura/api-http.md`](../docs/arquitectura/api-http.md).

## Estructura

| Ruta | Contenido |
| --- | --- |
| `src/app.js` | Composición de Express: seguridad, rate limit, `/health`, montaje y manejo de errores. |
| `src/routes/` | `usuarioRoutes.js` (admin) y `ganaderoRoutes.js` (ganadero + IoT). |
| `src/controllers/` | Validación de entrada y serialización de respuestas. |
| `src/services/` | `userService`, `iotService`, `iotProtocol` y `mailService`. |
| `src/middlewares/` | `authMiddleware`: token, rol, estado y operación pendiente. |
| `src/utils/` | Paginación, validación estricta y generador de contraseña inicial. |
| `src/config/firebaseAdmin.js` | Inicialización de Firebase Admin (JSON en variable, archivo o emuladores en pruebas). |
| `test/` | Unitarias (`security.test.js`) e integración (`integration/api.test.js`). |
| `api/index.js`, `vercel.json` | Entrada serverless para Vercel. |

## Ejecución local

Requiere Node.js 22–24 y un archivo `.env` privado (ver tabla de variables).
El `.env` no se versiona.

```bash
npm ci
npm run dev          # se recarga solo al guardar (node --watch)
curl http://127.0.0.1:3000/health
```

`/health` responde `200` con `firebase: ready`; `503` significa que Firebase
Auth/Firestore no responden.

### Variables de entorno (solo nombres)

| Variable | Uso |
| --- | --- |
| `PORT` | Puerto local (3000 por defecto). |
| `CORS_ORIGINS` | Lista blanca de orígenes separada por comas. |
| `RATE_LIMIT_MAX` | Máximo de solicitudes por minuto (120 por defecto). |
| `FIREBASE_SERVICE_ACCOUNT_JSON` o `GOOGLE_APPLICATION_CREDENTIALS` | Credenciales de Firebase Admin. |
| `FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST` | Emuladores de Firebase (solo pruebas). |
| `IOT_DEVICE_ID` | Identificador del dispositivo (`jetson-01` por defecto). |
| `IOT_SHARED_SECRET` | Clave HMAC compartida con la Jetson (64 hex). Sin ella, IoT responde 503. |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` | Envío del correo de activación. |

Los valores reales viven en el `.env` local y nunca deben commitearse.

## Pruebas

```bash
npm test                  # unitarias con node:test (4 casos)
npm run test:integration  # requiere emuladores de Firebase (12 casos)
```

Las de integración rechazan ejecutarse sin emuladores (protección para no tocar
producción) y vacían `SMTP_*` para no enviar correos reales:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
PATH=/usr/lib/jvm/java-21-openjdk-amd64/bin:$PATH \
  firebase emulators:exec --only auth,firestore --project demo-bovisense \
  "npm --prefix backend run test:integration"
```

Detalle en [`docs/codebase/TESTING.md`](../docs/codebase/TESTING.md).

## Despliegue

`api/index.js` re-exporta la app de Express y `vercel.json` enruta todo el
tráfico a esa función (`maxDuration: 30`). La variable `VERCEL=1` activa
`trust proxy` para que el rate limit vea la IP real. Guía en
[`docs/arquitectura/despliegue.md`](../docs/arquitectura/despliegue.md).

## Notas de diseño

- Idempotencia: altas/ediciones de usuario usan huella + lease
  (`OperacionesUsuarios`); los comandos IoT usan ticket (`IotCommands`).
- El guardado de un conteo es transaccional, exige la trama final firmada y
  deduplica reintentos; la alerta por diferencia se genera en el mismo paso.
- Conviven colecciones heredadas (`Conteos`, `Alertas` y `ConfiguracionSistema`
  en la raíz) con las subcolecciones por usuario. El listado deduplica por
  identidad; el contador del panel aún no (hallazgo C-14).
- `src/routes/usuarioRoute.js` está duplicado y **no** montado (código muerto):
  las rutas activas son `usuarioRoutes.js`.
