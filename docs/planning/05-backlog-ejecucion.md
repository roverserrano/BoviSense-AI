# 05 — Backlog de ejecución

Fase 5 de la skill. Cada tarea incluye los campos obligatorios: ID, objetivo,
requisito de origen, estado, dependencias, componentes afectados, criterios de
aceptación, pruebas necesarias, restricciones y evidencia.

**Ninguna tarea de este backlog está autorizada todavía.** La ejecución requiere
la aprobación explícita del plan (ver `README.md` de esta carpeta).

## Bloque A — Seguridad del protocolo (P0)

### T-01 — Decidir el tratamiento del camino de comandos no autenticado
- **Objetivo:** definir si el receptor elimina el camino heredado, lo deja tras una bandera desactivada o lo autentica con C1.
- **Requisito de origen:** R-IOT-06 (`S1` Fase 5, `S6`).
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** ninguna.
- **Componentes:** `jetson/lora_jetson_rx.py`.
- **Criterios de aceptación:** decisión registrada en `06-registro-conflictos.md` con la opción elegida y su justificación.
- **Pruebas necesarias:** ninguna en esta tarea (es de decisión).
- **Restricciones:** no modificar código en esta tarea; no ejecutar sobre el equipo real.
- **Evidencia:** `jetson/lora_jetson_rx.py:1398-1459`.

### T-02 — Aplicar la decisión de T-01 al receptor
- **Objetivo:** que una trama sin firma no pueda iniciar, detener ni consultar conteos.
- **Requisito de origen:** R-IOT-06.
- **Estado:** **VALIDADA** (ejecutada el 2026-10-12; pendiente desplegar el archivo en la Jetson).
- **Dependencias:** T-01.
- **Componentes:** `jetson/lora_jetson_rx.py`; si se opta por autenticar, `jetson/secure_protocol.py`.
- **Criterios de aceptación:** una trama `INICIARCONTEO` sin firma no produce efectos; el flujo C1/R1 sigue funcionando; `python3 -m py_compile` y `unittest` en verde.
- **Pruebas necesarias:** caso nuevo en `jetson/test_secure_protocol.py`.
- **Restricciones:** conservar el comportamiento documentado en `S6`; no tocar el hardware; desplegar solo con autorización.
- **Evidencia:** `jetson/lora_jetson_rx.py:1398-1459`, `.ino:245-249` (el puente solo acepta `C1|` desde BLE).

### T-03 — Prueba de rechazo de tramas sin firma
- **Objetivo:** impedir que esta brecha reaparezca.
- **Requisito de origen:** R-X-04, R-IOT-06.
- **Estado:** **VALIDADA** (`test_unsigned_frames_never_execute_commands`; receptor en 22/22).
- **Dependencias:** T-02.
- **Componentes:** `jetson/test_secure_protocol.py`.
- **Criterios de aceptación:** el caso falla si se reintroduce el camino heredado.
- **Pruebas necesarias:** `python3 -m unittest test_secure_protocol.py`.
- **Restricciones:** pruebas sin hardware (el SX1278 ya se sustituye por dobles).
- **Evidencia:** patrón existente en `jetson/test_secure_protocol.py` (clase `FakeSpi`).

## Bloque B — Secretos y configuración (P0/P1)

### T-04 — Rotar las credenciales expuestas
- **Objetivo:** invalidar las credenciales que están en claro en archivos locales.
- **Requisito de origen:** R-X-03 (`S1` Fase 10).
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** acción directa del usuario en cada proveedor.
- **Componentes:** cuentas externas (GitHub, proveedor de LLM) y contraseña del hotspot.
- **Criterios de aceptación:** las credenciales antiguas quedan revocadas; las nuevas no se escriben en ningún archivo del proyecto.
- **Pruebas necesarias:** verificación manual de acceso con la credencial antigua (debe fallar).
- **Restricciones:** no registrar los valores nuevos en el repositorio, en tickets ni en la documentación.
- **Evidencia:** `pasos.txt:223-224` (tipo de credencial, sin valor), `.codex:17`; ambos ignorados por Git.

### T-05 — Limpiar los bloques con credenciales de los archivos locales
- **Objetivo:** dejar los archivos locales sin secretos operativos.
- **Requisito de origen:** R-X-03.
- **Estado:** **VALIDADA** (credenciales redactadas el 2026-10-12; falta que el usuario rote las claves, tarea T-04).
- **Dependencias:** T-04.
- **Componentes:** `pasos.txt`, `.codex` (archivos locales, ignorados por Git).
- **Criterios de aceptación:** `rg` sobre el árbol de trabajo no encuentra credenciales; el contenido útil de los documentos se conserva.
- **Pruebas necesarias:** búsqueda de patrones de credencial conocidos (por tipo, sin imprimir valores).
- **Restricciones:** la skill prohíbe alterar documentos históricos durante la consolidación; esta tarea requiere autorización explícita y debe acordarse la conservación del resto del contenido.
- **Evidencia:** `git check-ignore -v pasos.txt .codex`.

### T-06 — Decidir el tratamiento de los `google-services.json` versionados
- **Objetivo:** definir si la configuración pública del cliente Firebase permanece en el repositorio.
- **Requisito de origen:** R-X-03, conflicto `C-05`.
- **Estado:** **VALIDADA** (decisión: se conservan versionados; documentado en `.gitignore` y en `C-05`).
- **Dependencias:** ninguna.
- **Componentes:** `.gitignore`, `backend/google-services.json`, `frontend/android/app/google-services.json`.
- **Criterios de aceptación:** decisión registrada; si se retiran, quedan ignorados y se documenta el canal de distribución; si se conservan, se justifica por escrito.
- **Pruebas necesarias:** `git ls-files` + `git check-ignore -v`.
- **Restricciones:** no exponer los valores; no romper el build de Android ni la inicialización del backend.
- **Evidencia:** `git ls-files` muestra ambos archivos; `.gitignore` ignora el resto de credenciales.

### T-07 — Coherencia de `.gitignore` con archivos versionados
- **Objetivo:** eliminar reglas que no tienen efecto y evitan entender qué se versiona.
- **Requisito de origen:** R-X-03, conflicto `C-06`.
- **Estado:** **VALIDADA** (reglas sin efecto eliminadas; verificado que ningún versionado queda ignorado).
- **Dependencias:** T-06.
- **Componentes:** `.gitignore`.
- **Criterios de aceptación:** ninguna regla del `.gitignore` apunta a un archivo versionado, salvo decisión explícita documentada.
- **Pruebas necesarias:** `git ls-files --ignored --exclude-standard` y revisión cruzada.
- **Restricciones:** no eliminar archivos del repositorio sin autorización (por ejemplo, `AGENTS.md`).
- **Evidencia:** `.gitignore:8` ignora `AGENTS.md`, que está versionado.

## Bloque C — Publicación Android (P1)

### T-08 — Definir `applicationId` y firma de release
- **Objetivo:** poder generar un APK/AAB distribuible.
- **Requisito de origen:** R-FLUTTER-13 (`S2` §6.5, §21.5).
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** decisión del identificador de paquete; si cambia, actualizar `google-services.json` y el registro en Firebase.
- **Componentes:** `frontend/android/app/build.gradle.kts`, `frontend/android/app/google-services.json`.
- **Criterios de aceptación:** build de release firmado con el identificador acordado, sin tráfico en claro.
- **Pruebas necesarias:** `flutter build apk --release --dart-define=API_BASE_URL=https://<host>` y verificación del manifiesto fusionado.
- **Restricciones:** no publicar en ninguna tienda; no alterar el proyecto Firebase de otros entornos.
- **Evidencia:** `frontend/android/app/build.gradle.kts:27,34-42,44-47`.

## Bloque D — Validación en hardware (P1/P2, bloqueadas)

### T-09 — Ejecutar el checklist de validación en campo
- **Objetivo:** validar el flujo completo en el equipo real.
- **Requisito de origen:** R-JETSON-10, R-X-07 (`S2` §21).
- **Estado:** BLOQUEADA (requiere acceso físico).
- **Dependencias:** servicio de la Jetson actualizado con los archivos del repositorio.
- **Componentes:** Jetson, ESP32, cámara CSI, teléfono Android, backend local.
- **Criterios de aceptación:** registro fechado con versión de cada archivo desplegado; sesión `H→S→Q→T→R` completada con conteo guardado; latencias por tramo medidas.
- **Pruebas necesarias:** checklist de `AGENTS.md` §21 y trazas por `request_id`.
- **Restricciones:** no tocar cableado; no forzar RST; un único propietario del SPI; sin despliegues públicos.
- **Evidencia:** `AGENTS.md` §6.1, §6.2, §8, §21.

### T-10 — Verificar la versión de firmware del ESP32 grabada
- **Objetivo:** saber si el prototipo ejecuta el sketch del repositorio.
- **Requisito de origen:** R-IOT-07 (`S2` §6.3).
- **Estado:** BLOQUEADA (requiere acceso al prototipo).
- **Dependencias:** ninguna.
- **Componentes:** `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/`.
- **Criterios de aceptación:** cadena de versión del firmware comparada con la del repositorio y registrada con fecha.
- **Pruebas necesarias:** monitor serie y verificación de la trama de arranque.
- **Restricciones:** no reflashear sin autorización; registrar el binario usado si se reflashea.
- **Evidencia:** `.ino:31-47,384-386` (salida por serie).

### T-11 — Instalar y verificar la librería de tracking en la Jetson
- **Objetivo:** confirmar qué motor de tracking se ejecuta realmente.
- **Requisito de origen:** R-JETSON-02 (`S5`).
- **Estado:** BLOQUEADA (requiere acceso a la Jetson).
- **Dependencias:** decisión sobre el uso de `--reid` (`C-07`).
- **Componentes:** venv `env_detection`, `jetson/run_bovino.py`.
- **Criterios de aceptación:** el log de arranque informa el motor efectivo (`roboflow_botsort` y no `internal_persistent`) y las versiones instaladas.
- **Pruebas necesarias:** ejecución con `--no-display` y lectura de las líneas `[TRACKER]`.
- **Restricciones:** no romper el entorno NVIDIA existente (verificar `pip show torch` antes de instalar).
- **Evidencia:** `jetson/run_bovino.py:1438-1448,1973-1978`; `jetson/tracking.md` (sección de dependencias).

### T-12 — Comparativa de trackers con video aéreo real
- **Objetivo:** respaldar con datos propios la elección de tracker.
- **Requisito de origen:** R-JETSON-02, R-JETSON-12 (`S5`).
- **Estado:** BLOQUEADA (requiere video y equipo).
- **Dependencias:** T-11.
- **Componentes:** `jetson/run_bovino.py`.
- **Criterios de aceptación:** tabla comparativa por motor (`botsort`, `bytetrack`, `ocsort`, `none`) con `unique_bovines`, `tracks_created`, `tracks_recovered` y rechazos por duplicado.
- **Pruebas necesarias:** cuatro ejecuciones con el mismo `--source` y `--no-display`.
- **Restricciones:** no modificar el detector ni el engine.
- **Evidencia:** `--tracker` en `jetson/run_bovino.py:2514`; `TRACK_FINAL` en `summary_fields`.

## Bloque E — Cobertura de pruebas (P2)

### T-13 — Prueba automatizada del anti doble conteo del worker
- **Objetivo:** que «un track no cuenta dos veces» deje de depender de una prueba manual.
- **Requisito de origen:** R-JETSON-05 (`S5`).
- **Estado:** **VALIDADA** (`jetson/test_tracking_logic.py`, 9 casos en verde).
- **Dependencias:** ninguna (puede hacerse sin hardware).
- **Componentes:** `jetson/run_bovino.py`, nuevo archivo de pruebas.
- **Criterios de aceptación:** una prueba con detecciones sintéticas verifica que dos frames del mismo objeto producen un solo conteo y que un objeto nuevo sí incrementa.
- **Pruebas necesarias:** `python3 -m unittest` sobre el nuevo caso.
- **Restricciones:** no introducir dependencias nuevas; el detector no debe instanciarse en la prueba.
- **Evidencia:** verificación manual realizada el 2026-10-12 (harness descrito en `03-catalogo-requisitos.md`, fila R-JETSON-05).

### T-14 — Pruebas de compatibilidad con colecciones heredadas
- **Objetivo:** fijar el comportamiento del backend con datos de la etapa anterior.
- **Requisito de origen:** R-NODE-09.
- **Estado:** **VALIDADA** (caso de integración añadido; hallazgo derivado `C-14`).
- **Dependencias:** ninguna.
- **Componentes:** `backend/test/integration/api.test.js`, `backend/src/controllers/ganaderoController.js`.
- **Criterios de aceptación:** caso de integración que crea un conteo y una alerta en las colecciones de nivel raíz y verifica que aparecen en el historial sin duplicarse.
- **Pruebas necesarias:** integración con emuladores.
- **Restricciones:** no modificar la lógica de compatibilidad en esta tarea.
- **Evidencia:** `ganaderoController.js:127-221`.

### T-15 — Pruebas de trazas, límite de tasa y tamaño de cuerpo
- **Objetivo:** cubrir límites del backend hoy sin prueba.
- **Requisito de origen:** R-NODE-10, R-NODE-11.
- **Estado:** **VALIDADA** (casos añadidos; límite configurable con `RATE_LIMIT_MAX`).
- **Dependencias:** ninguna.
- **Componentes:** `backend/test/`, `backend/src/app.js`.
- **Criterios de aceptación:** casos que verifiquen `X-Request-Id`, `413` por cuerpo grande y `400` por JSON inválido.
- **Pruebas necesarias:** integración con emuladores.
- **Restricciones:** no relajar los límites para que pasen las pruebas.
- **Evidencia:** `backend/src/app.js:18-22,27-38,62-68`.

## Bloque F — Proceso y despliegue (P2/P3)

### T-16 — Verificar el estado del despliegue en Vercel
- **Objetivo:** saber si existe un backend publicado y con qué dominio.
- **Requisito de origen:** R-VERCEL-01, R-VERCEL-04.
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** decisión del usuario sobre hospedaje (`R-X-07`).
- **Componentes:** proyecto Vercel, `backend/vercel.json`.
- **Criterios de aceptación:** estado registrado (activo/inactivo, dominio, variables) sin exponer secretos.
- **Pruebas necesarias:** `GET /health` contra el dominio, si existe.
- **Restricciones:** no crear ni modificar despliegues.
- **Evidencia:** `backend/vercel.json:1-12`, `backend/api/index.js:1-3`.

### T-17 — Verificar si las reglas de Firestore están desplegadas
- **Objetivo:** confirmar la superficie real de lectura del cliente.
- **Requisito de origen:** R-X-03, `S6`.
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** acceso de lectura a la consola de Firebase.
- **Componentes:** `firestore.rules`.
- **Criterios de aceptación:** reglas activas comparadas con el archivo del repositorio.
- **Pruebas necesarias:** pruebas contra emuladores (ya existen en la suite de integración).
- **Restricciones:** no desplegar reglas sin autorización.
- **Evidencia:** `firestore.rules:1-14`, `backend/test/integration/api.test.js` (caso de reglas).

### T-18 — Decidir la migración de las colecciones heredadas
- **Objetivo:** eliminar la lectura doble y su coste.
- **Requisito de origen:** R-NODE-09, conflicto `C-08`.
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** inventario de datos reales en producción.
- **Componentes:** `backend/src/controllers/ganaderoController.js`, Firestore.
- **Criterios de aceptación:** decisión escrita; si se migra, plan de migración y retirada del código de compatibilidad en una tarea posterior.
- **Pruebas necesarias:** T-14 antes de retirar la compatibilidad.
- **Restricciones:** ninguna operación sobre datos de producción sin autorización explícita.
- **Evidencia:** `ganaderoController.js:127-221`.

### T-19 — Decidir el alcance funcional pendiente (offline, push, duración de sesión)
- **Objetivo:** cerrar las preguntas de producto que quedaron abiertas.
- **Requisito de origen:** R-FLUTTER-12, R-JETSON-11, R-JETSON-12.
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** respuesta del usuario.
- **Componentes:** app, worker.
- **Criterios de aceptación:** cada punto queda aprobado como requisito o descartado por escrito.
- **Pruebas necesarias:** no aplica.
- **Restricciones:** no convertir recomendaciones en requisitos sin aprobación.
- **Evidencia:** `docs/codebase/CONCERNS.md` §6 (`[ASK USER]`).

### T-20 — Commitear la documentación generada
- **Objetivo:** que `docs/` (codebase, arquitectura, planificación) entre al repositorio.
- **Requisito de origen:** R-X-05.
- **Estado:** PROPUESTA.
- **Dependencias:** ninguna.
- **Componentes:** `docs/`, `AGENTS.md`.
- **Criterios de aceptación:** commit con los documentos; `git status` limpio salvo los archivos locales ignorados.
- **Pruebas necesarias:** ninguna (documentación).
- **Restricciones:** no incluir `pasos.txt`, `.codex`, `revicion.txt` ni artefactos; revisar que no haya secretos en el diff.
- **Evidencia:** `git status --short` (documentación sin seguimiento).

### T-21 — Revisar el contenido ajeno en `pasos.txt`
- **Objetivo:** separar el requisito de UX del contenido no relacionado (landing page y comando de `cloudflared`).
- **Requisito de origen:** conflicto `C-09`.
- **Estado:** PENDIENTE_APROBACION.
- **Dependencias:** T-05 (limpieza de credenciales).
- **Componentes:** `pasos.txt` (archivo local).
- **Criterios de aceptación:** el archivo conserva solo el contenido del proyecto o queda archivado como histórico aparte.
- **Pruebas necesarias:** no aplica.
- **Restricciones:** no alterar documentos históricos sin autorización.
- **Evidencia:** `pasos.txt:223-281`.

### T-22 — Añadir integración continua mínima
- **Objetivo:** que las suites se ejecuten en cada push.
- **Requisito de origen:** R-X-08.
- **Estado:** IMPLEMENTADA_SIN_VALIDAR (workflow añadido; falta la primera ejecución en GitHub).
- **Dependencias:** ninguna.
- **Componentes:** `.github/workflows/` (nuevo).
- **Criterios de aceptación:** un push ejecuta `npm test`, `flutter analyze`, `flutter test` y `py_compile` de los scripts de la Jetson.
- **Pruebas necesarias:** una ejecución real del workflow.
- **Restricciones:** no incluir secretos en el workflow; usar emuladores solo si es viable en CI.
- **Evidencia:** `docs/codebase/.codebase-scan.txt` (*No CI/CD pipelines detected*).

## Evidencia

- Requisitos y estados: `03-catalogo-requisitos.md`.
- Fases y criterios: `04-plan-maestro.md`.
- Conflictos que originan tareas: `06-registro-conflictos.md`.
