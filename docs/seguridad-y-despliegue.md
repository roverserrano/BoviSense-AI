# Seguridad y despliegue de BoviSense

## Cambios incompatibles del protocolo IoT

La app, el backend, el firmware ESP32 y `jetson/lora_jetson_rx.py` forman una sola version compatible. Deben desplegarse juntos. La app ya no acepta `CMD:`, `RESP:` ni resultados de conteo introducidos por el cliente.

El backend firma comandos `C1` con HMAC-SHA256 y Jetson responde con tramas `R1` firmadas. Cada solicitud tiene identificador aleatorio, expiracion y sesion. Jetson conserva solicitudes y resultados en SQLite para impedir reejecuciones despues de un reinicio. ESP32 solo transporta tramas opacas: nunca almacena la clave.

## Clave compartida

Genere una clave diferente por instalacion (no la incluya en Git):

```bash
openssl rand -hex 32
```

Configure exactamente el mismo valor de 64 caracteres hexadecimales:

- Backend: variable `IOT_SHARED_SECRET`.
- Servicio Jetson: variable `IOT_SHARED_SECRET`.

Configure tambien `IOT_DEVICE_ID=jetson-01` en el backend si usa el identificador predeterminado. Los relojes del backend y Jetson deben usar NTP; las tramas expiran en 60 segundos.

## Backend

Variables obligatorias:

- `GOOGLE_APPLICATION_CREDENTIALS` o `FIREBASE_SERVICE_ACCOUNT_JSON`.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` y `SMTP_FROM`.
- `IOT_SHARED_SECRET`.
- `CORS_ORIGINS` solo si existe un cliente web autorizado. La app nativa no envia `Origin`.

Requisitos: Node.js 22 a 24. Para produccion el backend debe publicarse bajo
HTTPS: la app solo acepta HTTP para hosts de desarrollo local (bucle local y
rangos privados `10/8`, `172.16/12`, `192.168/16`); cualquier otro destino debe
ser `https://`. Antes de desplegar:

```bash
cd backend
npm ci
npm test
npm audit
```

El alta crea una credencial aleatoria interna y envia un enlace de Firebase para establecer la contraseña. Si SMTP falla, la cuenta permanece recuperable mediante "Recuperar contraseña" y la respuesta administrativa lo indica.

## Firestore

Las reglas nuevas permiten a la app leer solamente su propio perfil activo. Todas las escrituras y los demas datos pasan por la API con Firebase Admin.

Primero verifique con emuladores. El despliegue a produccion es una accion separada y deliberada:

```bash
firebase emulators:exec --only auth,firestore --project demo-bovisense "npm --prefix backend run test:integration"
firebase deploy --only firestore:rules --project aplicacion-cabfa
```

No se desplegaron reglas ni datos reales durante esta correccion.

## Jetson

Ejecute el receptor con un usuario dedicado. El directorio de estado predeterminado es `~/.local/state/bovisense`; puede cambiarse con `BOVISENSE_STATE_DIR`. Debe ser persistente y escribible solo por ese usuario. Configure NTP y reinicie el receptor despues de rotar la clave.

El proceso de conteo se inicia con una lista de argumentos, sin shell. Al recibir SIGTERM, el receptor detiene y espera al worker. Un resultado solo se firma para la sesion solicitada.

## Aplicacion movil y ESP32

En depuracion local la URL por defecto es `http://127.0.0.1:3000` y el
manifiesto Android habilita trafico en claro solo en las variantes `debug` y
`profile` (`manifestPlaceholders["usesCleartextTraffic"]`). La variante
`release` lo deja en `false`, por lo que en produccion hay que compilar con una
URL HTTPS:

```bash
flutter build apk --dart-define=API_BASE_URL=https://api.ejemplo.com
```

Grabe el firmware actualizado del puente. Tras cambiar de cuenta, pausar la app o cerrar sesion, los providers, listeners, temporizadores y conexion BLE de la sesion anterior se destruyen. Pruebe en hardware real: permisos Android 12+, fragmentacion BLE con MTU 23, perdida LoRa, reinicio de Jetson y reconsulta del conteo.

La app no incluye descubrimiento UDP ni puente Wi-Fi del ESP8266: los servicios
de esa etapa se retiraron junto con el firmware ESP8266. El unico transporte es
BLE hacia `BoviSense-Bridge`.

## Elementos pospuestos

- SEC-014: el tracker de `jetson/run_bovino.py` no fue modificado por esta fase.
- SEC-016: las credenciales y pruebas WiFi antiguas no fueron modificadas.
