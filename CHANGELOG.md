# Changelog

Todos los cambios relevantes de BoviSense-AI. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado
proyectado es [SemVer](https://semver.org/lang/es/).

Nota: el proyecto todavía no publica versiones etiquetadas (`git tag` está
vacío). Las entradas se agrupan por fecha y citan el commit final del bloque,
en la rama `dev`. Las fechas están en formato ISO.

## [No publicado] — cambios locales al 2026-10-17

### Añadido

- Documentación de código generada con la skill `code-documentation`:
  `CHANGELOG.md`, `CONTRIBUTING.md`, `backend/README.md`, `frontend/README.md`
  (reemplaza la plantilla de Flutter) y enlaces de documentación en el README
  raíz.
- `jetson/tracking.md`: especificación del seguimiento MOT para `run_bovino.py`
  (trabajo propuesto, pendiente de implementación).
- Skills del proyecto centralizadas en `.agents/skills/` y registro de las
  instaladas por CLI en `skills-lock.json`.

### Cambiado

- `AGENTS.md` se movió a `.agents/Instrucciones/` junto con las notas
  históricas (`pasos.txt`, `revicion.txt`, `.codex`) y un índice de la carpeta.
- README raíz reducido a presentación de producto; el detalle técnico vive en
  `docs/`.
- Correcciones de desfase en `docs/codebase/*` y `docs/arquitectura/*`:
  referencias de línea reverificadas contra `b94fcda`, estado del CI y conteos
  de pruebas al día.

### Corregido (mejoras del Informe de Auditoría, 2026-10-17)

- **Replay del protocolo IoT (BOV-HIGH-001):** verificar de nuevo una respuesta
  ya cacheada devuelve el resultado sin reaplicar transiciones; antes un `IDLE`
  antiguo podía liberar la reserva de la sesión activa, incluso de otro
  usuario. La liberación por `IDLE` queda limitada a la sesión o al lease
  propio.
- **Cierre forzado del conteo (BOV-HIGH-004):** si el worker no responde al
  cierre y hay que usar `SIGKILL`, la Jetson responde `ERROR` sin conteo
  (detalle `forced_termination`) en lugar de un `STOPPED` guardable; el backend
  no emite prueba terminal ni permite registrar ese conteo.
- **`H` tras finalizar una sesión (BOV-HIGH-002):** el receptor responde
  disponibilidad (`READY`/`RUNNING`) sin arrastrar el último `STOPPED` ni
  filtrar el conteo en curso; antes el backend rechazaba la trama ("Fecha de
  finalización inválida") y la app quedaba bloqueada.
- **Recuperación durable del resultado (BOV-HIGH-003, lado receptor):** el
  final se persiste en SQLite antes de responder y `R`/`T` lo recuperan tras un
  reinicio del receptor, con la fecha de cierre original.
- **Cierre limpio ante `SIGTERM` (BOV-HIGH-006):** el receptor detiene el
  worker y cierra el SPI antes de salir, en vez de dejar procesos huérfanos.
- **Paginación con fechas iguales (BOV-MED-001):** cursor compuesto
  (fecha, id) en la subcolección y en la colección heredada; los grupos más
  grandes que la página ya no pierden registros.
- **Cola de comandos BLE (BOV-MED-003):** la sesión y la conexión se capturan
  al encolar, la cola se invalida al desconectar/reconectar y el ticket se pide
  con `session_id` explícito cuando se conoce.

## [2026-10-12] — `b94fcda`

"Aplica el plan consolidado: cierra comandos sin firma y refuerza pruebas, CI y
documentacion". Ejecuta las fases de `docs/planning/` que no requieren hardware.

### Seguridad

- El receptor de la Jetson dejó de aceptar el protocolo heredado sin firma
  (`BRIDGE|…`, `CMD:…`): solo se procesan tramas `C1|` con HMAC-SHA256 válido
  (hallazgo crítico C-01). Prueba de regresión incluida.
- Redacción de credenciales en claro en notas locales; queda pendiente la
  rotación por parte del usuario.

### Añadido

- Integración continua: `.github/workflows/ci.yml` con cuatro jobs (backend
  unitario, integración con emuladores de Firebase, Flutter y Jetson).
- `jetson/test_tracking_logic.py`: 9 casos de lógica de tracking (filtros,
  identidad, fábrica de trackers y compensación de movimiento global).
- Pruebas de integración del backend para colecciones heredadas, límites de
  cuerpo y JSON inválido (12 casos en total).
- Aviso explícito al arrancar el worker sobre el riesgo del ReID heurístico
  (puede fusionar animales y subcontar).

### Cambiado

- Límite de tasa configurable con `RATE_LIMIT_MAX` (120 solicitudes por minuto
  por defecto).

### Documentación

- `docs/planning/*` con el estado de ejecución del plan; `docs/codebase/`,
  `docs/arquitectura/despliegue.md` y `AGENTS.md` actualizados.

## [2026-09-21/22] — `afa09a1`, `d3fbb66`, `7d10336`, `8981985`, `84dc003`

### Añadido

- Backend reestructurado en servicios (`iotService`, `iotProtocol`,
  `userService`, `mailService`) y utilidades (`pagination`, `validation`,
  `passwordGenerator`), con pruebas unitarias y de integración.
- Protocolo IoT firmado C1/R1 (HMAC-SHA256) entre backend y Jetson, con
  tickets idempotentes, leases de dispositivo y antirreplay en SQLite.
- `frontend/run_usb.sh`: publica el backend local por `adb reverse` para el
  teléfono conectado por USB.
- Guardado de conteos respaldado por la prueba final firmada; alertas por
  faltante/excedente.
- Alertas visibles y marcables, paginación real del historial y del listado de
  usuarios, y resumen del sistema en el panel de administración.

### Corregido

- Sondeo del conteo que podía quedarse congelado; acción manual
  "Actualizar conteo" y cola de comandos que serializa el envío.
- Estado pegado tras guardar un conteo: confirmación antes de descartar un
  resultado y limpieza del estado al guardar.
- Mensajes de conexión Bluetooth: pedir activarlo, distinguir permiso
  denegado, "Bluetooth ocupado" (audífonos/parlantes) y equipo no encontrado.
- Sesión de conteo obsoleta tras reiniciar la Jetson: el equipo responde
  `IDLE` y el backend libera el lease en lugar de mostrar una falla.
- Búsqueda y filtros del administrador ciegos a la paginación; orden
  alfabético real; autoprotección de la cuenta propia.
- Splash sin retraso artificial, errores de login dentro de la tarjeta y
  confirmación al cerrar sesión o salir de la app.

### Cambiado

- Se retiró `backend/node_modules/` del repositorio.

### Documentación

- `AGENTS.md` como bitácora de traspaso (estado, incidentes y decisiones).

## [2026-05-02] — `b3f7f93` … `082a804`

### Añadido

- Exportación de Express para serverless en Vercel (`backend/api/index.js`).

### Cambiado

- Mejoras de experiencia de usuario: navegación, tarjetas más compactas,
  icono, mensajes de soporte y envío de credenciales por correo.

## [2026-04-18/24] — `9aa67bd` … `4a929b4`

### Añadido

- Comunicación teléfono ↔ ESP8266 (sketch `.ino`); migración a ESP32 y de WiFi
  a Bluetooth (BLE).
- Enlace app ↔ ESP32 → LoRa → Jetson y obtención del estado del dispositivo.
- Script de comunicación y conteo en Jetson Orin Nano.
- Botones de envío/recepción del conteo; el flujo simulado se reemplazó por
  conteo real por LoRa.
- Cambio de nombre de la aplicación, splash screen y refactor de la interfaz
  de login, cambio de contraseña y diseño de administración.

## [2026-03-24/31] — `04f0281` … `0f92aaa`

### Añadido

- Commit inicial: app Flutter + backend Node.js + Firebase Auth.
- README del proyecto.
