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
- Gestión completa de usuarios.
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

## Requisitos

- Flutter SDK 3.10+ (recomendado canal estable).
- Node.js 22 a 24.
- Proyecto Firebase configurado (Auth + Firestore).
- Cuenta SMTP válida para envío de credenciales.
- `IOT_SHARED_SECRET` (64 hexadecimales) idéntico en backend y Jetson, si se va
  a usar el flujo de conteo real.
- (Opcional) hardware IoT para pruebas de campo.

## Documentación

| Documento | Contenido |
| --- | --- |
| [docs/README.md](docs/README.md) | Índice de la documentación técnica: arquitectura, API HTTP, integraciones IoT, despliegue y planificación. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Cómo contribuir: entorno local, pruebas y convenciones. |
| [CHANGELOG.md](CHANGELOG.md) | Historial de cambios por fecha y commit. |
| [docs/arquitectura/desarrollo.md](docs/arquitectura/desarrollo.md) | Preparar y ejecutar cada módulo en local. |
| [docs/arquitectura/despliegue.md](docs/arquitectura/despliegue.md) | Despliegue: backend, app Android, Jetson y ESP32. |

---

BoviSense está diseñado para resolver una necesidad concreta del campo: tomar decisiones con datos confiables, en el momento correcto y con una operación simple para el usuario final.
