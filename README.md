# BoviSense

Sistema integral para gestión ganadera con enfoque en conteo asistido por IoT, trazabilidad operativa y control de usuarios por roles.

## ¿Qué hace la aplicación?

BoviSense conecta tres mundos en una sola experiencia:

1. Operación de campo (ganadero): configuración de finca, conexión al equipo, ejecución de conteos y consulta de historial.
2. Gestión administrativa: alta, edición y baja de usuarios con control de roles/estado.
3. Integración técnica: backend con Firebase + API REST y puente con dispositivos ESP32/Jetson para el flujo de conteo.

El objetivo es claro: reducir errores manuales en conteos, detectar diferencias contra lo esperado y generar alertas accionables.

## Funcionalidades principales

### Módulo Administrador
- Gestión completa de usuarios (`crear`, `editar`, `eliminar`).
- Asignación de rol (`administrador` o `usuario`) y estado (`activo` o `inactivo`).
- Generación automática de contraseña inicial y envío de credenciales por correo SMTP.
- Búsqueda y filtros por estado/rol.

### Módulo Ganadero
- Dashboard operativo con métricas rápidas:
  - conteos totales
  - alertas pendientes
  - últimos conteos y alertas
- Configuración de finca (nombre + cantidad esperada de ganado).
- Flujo guiado de conteo desde la app:
  - conexión al equipo
  - verificación de estado
  - inicio/parada del conteo
  - guardado del resultado final
- Historial de conteos con detalle por sesión.
- Gestión de alertas (incluye marcado como leída).

### Seguridad y acceso
- Autenticación con Firebase Authentication.
- Autorización por roles en backend.
- Bloqueo de acceso para usuarios inactivos.
- Cambio y recuperación de contraseña desde la app.

## Arquitectura del sistema

```text
Flutter App (MVVM + Provider)
   |
   |  HTTP local de depuracion / HTTPS + Firebase ID Token
   v
Node.js/Express API
   |
   +--> Firebase Auth (validación de identidad)
   +--> Cloud Firestore (Usuarios, Configuración, Conteos, Alertas)
   +--> SMTP (envío de credenciales)
   |
   +--> Flujo IoT firmado C1/R1
          App --BLE--> ESP32 --LoRa 433 MHz--> Jetson SX1278
          (la app solo muestra la respuesta despues de verificarla en el backend)
```

## Stack tecnológico

- Frontend: Flutter, Provider, Firebase (Auth + Firestore), HTTP.
- Backend: Node.js, Express, Firebase Admin SDK, Nodemailer.
- IoT/Bridge: puente ESP32 BLE y LoRa 433 MHz hacia la Jetson, con comandos
  firmados HMAC-SHA256 (`C1`) y respuestas firmadas (`R1`). El puente no conoce
  la clave compartida.

## Estructura del repositorio

```text
.
├── frontend/          # App Flutter
├── backend/           # API REST y lógica de negocio
├── comunicacion-iot/  # Sketches y documentación de integración IoT
└── jetson/            # Scripts desplegables para ejecución en Jetson
```

## API principal (resumen)

### Administración (`/api/admin/usuarios`) [requiere rol administrador]
- `GET /` listar usuarios
- `POST /` crear usuario
- `PUT /:uid` actualizar usuario
- `DELETE /:uid` eliminar usuario

### Ganadero (`/api/ganadero`) [requiere rol usuario/ganadero]
- `GET /dashboard`
- `GET /configuracion`
- `PUT /configuracion`
- `GET /dispositivo`
- `POST /conteos` (exige la prueba final firmada de la sesión)
- `GET /conteos`
- `GET /conteos/:id`
- `GET /alertas`
- `PUT /alertas/:id/leer`
- `POST /iot/comandos` (emite la trama `C1` firmada)
- `POST /iot/respuestas` (verifica la trama `R1` firmada)

## Requisitos

- Flutter SDK 3.10+ (recomendado canal estable).
- Node.js 22 a 24.
- Proyecto Firebase configurado (Auth + Firestore).
- Cuenta SMTP válida para envío de credenciales.
- `IOT_SHARED_SECRET` (64 hexadecimales) idéntico en backend y Jetson, si se va
  a usar el flujo de conteo real.
- (Opcional) hardware IoT para pruebas de campo.

## Configuración y ejecución

### 1) Backend

Entrar al backend:

```bash
cd backend
```

Instalar dependencias:

```bash
npm install
```

Crear `backend/.env` con variables necesarias:

```env
PORT=3000
GOOGLE_APPLICATION_CREDENTIALS=./ruta/a/service-account.json

SMTP_HOST=smtp.tu-proveedor.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=tu_usuario
SMTP_PASS=tu_password
SMTP_FROM="BoviSense <no-reply@tu-dominio.com>"

IOT_DEVICE_ID=jetson-01
IOT_SHARED_SECRET=<64 hexadecimales, nunca en Git>
```

Iniciar servidor:

```bash
npm run dev
```

Prueba rápida:

```bash
GET http://localhost:3000/health
```

### 2) Frontend

Entrar al frontend:

```bash
cd frontend
```

Instalar dependencias:

```bash
flutter pub get
```

Configurar URL del backend en:

`frontend/lib/core/config/app_config.dart` (valor por defecto
`http://127.0.0.1:3000`) o al compilar:

**Telefono fisico por USB (recomendado).** `127.0.0.1` dentro del telefono es
el telefono, no la laptop, asi que hay que publicar el puerto del backend con
`adb reverse`. El script ya lo hace y luego arranca la app:

```bash
bash run_usb.sh
```

Equivale a:

```bash
adb reverse tcp:3000 tcp:3000
flutter run
```

**Telefono en la misma red WiFi.** Compilar apuntando a la IP de la laptop
(`ip -4 addr`), no a `127.0.0.1`:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
```

Solo se acepta HTTP para hosts locales (bucle local y rangos privados); en
release el trafico en claro queda bloqueado por el manifiesto Android.

### Si la app muestra un error de conexion

1. Confirmar que el backend responde: `curl http://127.0.0.1:3000/health`.
2. Confirmar el tunel USB: `adb reverse --list` debe mostrar `tcp:3000 tcp:3000`.
   Si no aparece, `adb reverse` se pierde al desconectar el cable o reiniciar el
   telefono; volver a ejecutar `bash run_usb.sh`.
3. Confirmar que el telefono tiene internet propio (WiFi o datos): Firebase Auth
   y Firestore no pasan por `adb reverse`.

Ejecutar app:

```bash
flutter run
```

## Flujo operativo recomendado

1. Registrar usuarios desde módulo administrador.
2. Configurar finca (cantidad esperada).
3. Conectar equipo de conteo.
4. Ejecutar conteo y guardar resultado.
5. Revisar diferencia y alertas.
6. Consultar historial para seguimiento operativo.

## Estado del proyecto

- Aplicación funcional en fase final de integración.
- Frontend y backend productivos para pruebas operativas.
- Integración IoT disponible con rutas de validación en `comunicacion-iot/` y scripts en `jetson/`.

## Notas importantes

- El mensaje de `packages have newer versions incompatible with dependency constraints` en Flutter es una advertencia, no un error de compilación.
- La app usa token de Firebase para consumir la API; si el backend rechaza acceso, revisar primero credenciales de Firebase Admin y estado/rol del usuario.

---

BoviSense está diseñado para resolver una necesidad concreta del campo: tomar decisiones con datos confiables, en el momento correcto y con una operación simple para el usuario final.
