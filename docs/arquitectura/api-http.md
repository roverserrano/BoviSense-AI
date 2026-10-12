# Contratos HTTP de la API

Catálogo de endpoints observados en el código. Formato de error común:
`{ "message": "<texto en español>" }` con el código HTTP correspondiente
(`backend/src/utils/validation.js:43-56`).

Autorización: `Authorization: Bearer <Firebase ID token>`. El middleware
verifica el token con revocación (`verifyIdToken(token, true)`), carga el perfil
en `Usuarios/{uid}` y exige `estado == 'activo'` y sin `operacion_pendiente`
(`backend/src/middlewares/authMiddleware.js:24,57-103`).

Cabeceras comunes: `helmet`, `Cache-Control: no-store`, `X-Request-Id` (eco o
generado) y CORS restringido a `CORS_ORIGINS` o peticiones sin `Origin`
(`backend/src/app.js:15-38`). Límite de tasa: 120 peticiones por minuto por IP;
cuerpo máximo 16 kb (`backend/src/app.js:18-22`).

## 1. Salud

### `GET /health`

| Aspecto | Detalle |
|---------|---------|
| Autorización | Ninguna |
| Respuesta 200 | `{ ok: true, service: "bovisense-ai-backend", hostname: "<host>", firebase: "ready" }` |
| Respuesta 503 | `{ ok: false, ..., firebase: "unavailable" }` |
| Comportamiento | Comprueba Firestore (`Health/probe`) y Auth (`listUsers(1)`), con caché de 15 s y timeout de 5 s |
| Evidencia | `backend/src/app.js:40-57` |

## 2. Administración de usuarios

Prefijo `/api/admin/usuarios`, protegido por `requireRoles(['administrador'])`
(`backend/src/routes/usuarioRoutes.js:35`).

### `GET /api/admin/usuarios`

| Aspecto | Detalle |
|---------|---------|
| Query | `limit` (1-100, por defecto 30), `cursor` (id del último documento) |
| Orden | Alfabético ascendente por `nombre` |
| Respuesta 200 | `{ usuarios: [ { uid, nombre, apellidos, correo, cedula_identidad, telefono, rol, estado, fecha_registro, fecha_actualizacion, operacion_pendiente } ], next_cursor: string\|null, resumen: { total, activos, inactivos, administradores } }` |
| Notas | El resumen solo se calcula en la primera página (sin `cursor`) |
| Errores | `400` límite inválido; `401` sin token; `403` sin rol o perfil bloqueado |
| Evidencia | `backend/src/controllers/usuarioController.js:38-62` |

### `POST /api/admin/usuarios`

| Aspecto | Detalle |
|---------|---------|
| Cuerpo | `request_id` (32 hex, actúa como `uid`), `nombre` (≤60), `apellidos` (≤80), `cedula_identidad` (1.000.000-99.999.999), `correo` (≤254, formato validado), `telefono` (8 dígitos), `rol` (`administrador`\|`usuario`), `estado` (`activo`\|`inactivo`) |
| Respuesta 201 | `{ usuario: {...}, activation_pending: bool, message: string }` |
| Errores | `400` payload inválido; `409` cédula ya registrada, alta ya existente u operación en curso; `503` fallo de Firebase |
| Notas | Idempotente por huella: repetir la misma petición devuelve el resultado previo (`backend/src/services/userService.js:21`). Si SMTP falla, responde 201 con `activation_pending: true` |
| Evidencia | `backend/src/controllers/usuarioController.js:45-58`, `backend/src/services/userService.js:12-108` |

### `PUT /api/admin/usuarios/:uid`

| Aspecto | Detalle |
|---------|---------|
| Cuerpo | Igual que el alta, sin `request_id` |
| Respuesta 200 | `{ usuario: {...}, message: "Usuario actualizado." }` |
| Regla propia | Un administrador no puede quitarse su rol ni desactivarse (`400`) |
| Errores | `400`, `404` usuario inexistente, `409` cédula en uso, `503` |
| Evidencia | `backend/src/controllers/usuarioController.js:60-70` |

### `DELETE /api/admin/usuarios/:uid`

| Aspecto | Detalle |
|---------|---------|
| Respuesta 200 | `{ message: "Usuario eliminado." }` |
| Regla propia | No se puede eliminar la propia cuenta (`400`) |
| Efectos | Borra la cuenta de Auth, el documento y subcolecciones, y limpia `IotSessions`/`IotCommands` del usuario |
| Evidencia | `backend/src/controllers/usuarioController.js:72-79`, `backend/src/services/userService.js:40-52` |

## 3. Operación de ganadero

Prefijo `/api/ganadero`, protegido por `requireRoles(['usuario','ganadero'])`
(`backend/src/routes/ganaderoRoutes.js:8`).

### `GET /api/ganadero/dashboard`

| Aspecto | Detalle |
|---------|---------|
| Respuesta 200 | `{ configuracion, dispositivo, conteos_recientes, alertas_recientes, ultimo_conteo, cantidad_conteos, alertas_pendientes, ultima_diferencia }` |
| Notas | Los conteos y alertas recientes se leen de la subcolección del usuario y, en paralelo, de las colecciones heredadas `Conteos`/`Alertas`, deduplicando por id |
| Evidencia | `backend/src/controllers/ganaderoController.js:267-300` |

### `GET /api/ganadero/configuracion` / `PUT /api/ganadero/configuracion`

| Aspecto | Detalle |
|---------|---------|
| Cuerpo `PUT` | `{ nombre_finca: string (≤120), cantidad_esperada: int ≥1 }` |
| Respuesta 200 | `{ configuracion: { id, nombre_finca, cantidad_esperada, fecha_actualizacion } }` (+ `message` en `PUT`) |
| Notas | La lectura cae a la colección heredada `ConfiguracionSistema` si no existe el documento nuevo |
| Evidencia | `backend/src/controllers/ganaderoController.js:302-322` |

### `GET /api/ganadero/dispositivo`

| Aspecto | Detalle |
|---------|---------|
| Respuesta 200 | `{ dispositivo: {...} \| null }`; devuelve `null` si el documento es el marcador de posición |
| Evidencia | `backend/src/controllers/ganaderoController.js:222-232,324-327` |

### `POST /api/ganadero/conteos`

| Aspecto | Detalle |
|---------|---------|
| Cuerpo | `{ session_id: <32 hex>, proof: <trama R1 firmada> }` |
| Respuesta 201 | `{ conteo: { id, fecha_hora_inicio, fecha_hora_fin, cantidad_detectada, cantidad_esperada, diferencia, estado_conteo, origen, resumen }, message }` |
| Respuesta 200 | Igual pero con `message: "El conteo ya estaba guardado."` (idempotente) |
| Errores | `400` sin prueba final válida o fechas inválidas; `403` sesión ajena; `409` resultado contradictorio |
| Regla | La cantidad **nunca** la aporta el cliente: se toma de la sesión firmada (`data.count`) |
| Efectos | Crea el conteo, crea alerta si `diferencia != 0` y actualiza el documento del dispositivo |
| Evidencia | `backend/src/controllers/ganaderoController.js:329-368` |

### `GET /api/ganadero/conteos`

| Aspecto | Detalle |
|---------|---------|
| Query | `limit` (1-50, por defecto 30), `cursor` (fecha ISO del último registro) |
| Respuesta 200 | `{ conteos: [...], next_cursor: string\|null }` |
| Notas | Paginación por valor de `fecha_hora_inicio`, mezclando subcolección y colección heredada, sin partir grupos con la misma fecha |
| Evidencia | `backend/src/controllers/ganaderoController.js:371-380,175-210` |

### `GET /api/ganadero/conteos/:id`

| Aspecto | Detalle |
|---------|---------|
| Respuesta 200 | `{ conteo: {...} }` |
| Errores | `404` si no existe o no pertenece al usuario |
| Evidencia | `backend/src/controllers/ganaderoController.js:382-388` |

### `GET /api/ganadero/alertas`

| Aspecto | Detalle |
|---------|---------|
| Query | `limit` (1-50), `cursor` (fecha ISO) |
| Respuesta 200 | `{ alertas: [ { id, mensaje, fecha_hora, tipo, nivel, leida } ], next_cursor }` |
| Evidencia | `backend/src/controllers/ganaderoController.js:390-399` |

### `PUT /api/ganadero/alertas/:id/leer`

| Aspecto | Detalle |
|---------|---------|
| Respuesta 200 | `{ alerta: {...} }` con `leida: true` |
| Errores | `404` si no existe o es de otro usuario (verifica subcolección y colección heredada) |
| Evidencia | `backend/src/controllers/ganaderoController.js:401-412` |

### `POST /api/ganadero/iot/comandos`

| Aspecto | Detalle |
|---------|---------|
| Cuerpo | `{ command: "ESTADO"\|"PREPARARCONTEO"\|"INICIARCONTEO"\|"DETENERCONTEO"\|"ESTADOCONTEO"\|"RESULTADOCONTEO", request_id: <32 hex>, session_id?: <32 hex> }` |
| Respuesta 200 | `{ frame: "C1\|...\|mac", request_id, session_id, command }` |
| Errores | `400` comando no permitido o sin configuración de finca; `409` equipo ocupado por otra sesión, solicitud ya usada o vencida, o sesión fuera del equipo; `403` sesión ajena; `503` si `IOT_SHARED_SECRET` no está configurado |
| Notas | `S` abre sesión (crea `IotSessions` y lease de 900 s); si el mismo usuario ya tiene lease, `S` se convierte en `Q`. Los comandos `Q`/`T`/`R` requieren sesión válida |
| Evidencia | `backend/src/services/iotService.js:11-67`, `backend/src/controllers/ganaderoController.js:414-419` |

### `POST /api/ganadero/iot/respuestas`

| Aspecto | Detalle |
|---------|---------|
| Cuerpo | `{ frame: "R1\|request_id\|session_id\|status\|count\|timestamp\|completed_at\|mac" }` |
| Respuesta 200 | `{ status, session, count: string\|"unknown", device_id, proof: string\|null }` |
| Errores | `400` formato inválido, estado desconocido o fecha de finalización inválida; `403` respuesta ajena o firma no autenticada; `409` respuesta vencida o ticket ya respondido con otra trama |
| Reglas | `terminal` = `STOPPED`/`RESULT` con conteo ⇒ guarda `proof` en la sesión y libera el lease; `IDLE` libera el dispositivo y borra su `session_id` |
| Evidencia | `backend/src/services/iotService.js:69-103` |

## 4. Códigos de error usados en la API

| Código | Significado en este sistema | Ejemplo de mensaje |
|--------|-----------------------------|--------------------|
| `400` | Entrada inválida o regla de negocio incumplida | `Cantidad esperada debe ser un entero entre 1 y 1000000.` |
| `401` | Token ausente o inválido | `Token no proporcionado.` / `Token inválido o expirado.` |
| `403` | Rol insuficiente, perfil bloqueado, sesión ajena o firma no válida | `No tienes permisos para acceder a este recurso.` |
| `404` | Recurso inexistente o no propio (se evita filtrar existencia) | `Conteo no encontrado.` |
| `409` | Conflicto de estado (equipo ocupado, solicitud repetida, cédula duplicada) | `El equipo esta ocupado por otra sesion.` |
| `413` | Cuerpo mayor a 16 kb | `Solicitud demasiado grande.` |
| `503` | Dependencia no disponible o configuración ausente | `El equipo de conteo no esta configurado en el servidor.` |

## 5. Evidencia

- `backend/src/app.js`, `backend/src/routes/*.js`, `backend/src/controllers/*.js`,
  `backend/src/services/*.js`, `backend/src/utils/validation.js`
- `backend/test/integration/api.test.js` (verificación ejecutable de la mayoría
  de contratos descritos)
