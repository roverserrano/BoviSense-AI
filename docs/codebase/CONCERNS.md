# Codebase Concerns

Análisis basado en el código, la configuración y la salida del escáner
(`docs/codebase/.codebase-scan.txt`). No incluye hallazgos que dependan de
hardware, marcados como `PENDIENTE DE VERIFICACIÓN`.

## Core Sections (Required)

### 1) Top Risks (Prioritized)

| Severity | Concern | Evidence | Impact | Suggested action |
|----------|---------|----------|--------|------------------|
| Alta | **Módulo Jetson sin manifiesto de dependencias ni entorno reproducible** (no hay `requirements.txt`/`pyproject.toml`; el venv `env_detection` se construye a mano) | Búsqueda sin resultados; `jetson/lora_jetson_rx.py:49` apunta al intérprete del venv | Si se pierde la Jetson o el venv, no hay forma de reconstruir el entorno; bloquea reproducibilidad académica y despliegue | Congelar el entorno (`pip freeze`) y versionar un `jetson/requirements.txt` |
| Alta | **El estado de sesión vive solo en memoria de la Jetson y se reconcilia de forma implícita** | `backend/src/services/iotService.js:100-102`; incidente documentado en `AGENTS.md` sección 12 | Comandos dirigidos a sesiones inexistentes; pantallas bloqueadas para el usuario | Mantener la reconciliación por `IDLE` y añadir prueba de reinicio del servicio en QA |
| Alta | **Publicación Android bloqueada**: `applicationId` de ejemplo y firma debug en release | `frontend/android/app/build.gradle.kts:27,44-47` | No se puede publicar en Play ni distinguir instalaciones | Definir `applicationId` definitivo y keystore de release antes de distribuir |
| Media | **Credenciales de cliente versionadas**: `backend/google-services.json` y `frontend/android/app/google-services.json` están en el repositorio | `git ls-files`; `frontend/android/app/google-services.json` contiene `api_key` (3 apariciones) | La clave de cliente de Firebase es pública por diseño, pero su presencia no es una decisión explícita ni documentada | Decidir y documentar; si se retiran, excluirlos con `.gitignore` y distribuirlos aparte |
| Media | **Ausencia de CI/CD**: no hay pipelines automatizados | `docs/codebase/.codebase-scan.txt`, sección `CI/CD PIPELINES` | Los tests dependen de ejecución manual; el repositorio puede integrarse roto | Añadir workflow que corra `npm test`, `flutter analyze/test` y `py_compile` |
| Media | **ReID heurístico activado por defecto en el tracker** (descriptor HSV + reglas espaciales y de tamaño) | `jetson/run_bovino.py:1497-1560` (`_reid_score`), `--reid` por defecto `True` | Puede fusionar dos animales distintos y **subcontar**, el error más caro en un conteo | Validar en campo; si hay duda, usar `--no-reid` y comparar resultados |
| Media | **Colecciones heredadas duplicadas** (`Conteos`, `Alertas`, `ConfiguracionSistema` de nivel raíz frente a subcolecciones por usuario) | `backend/src/controllers/ganaderoController.js:127-221` | Consultas dobles, coste y riesgo de inconsistencias; deuda de migración | Definir plan de migración y eliminar la lectura heredada al cerrarlo |
| Baja | **Reglas de Firestore sin evidencia de despliegue** | `firestore.rules` presente; sin registro de despliegue | Si producción usa reglas antiguas, la superficie de lectura del cliente cambia | Verificar reglas activas en el proyecto Firebase |
| Baja | **`AGENTS.md` está en `.gitignore` pero versionado** | `.gitignore:8` y `git ls-files` | Confusión sobre si el archivo debe versionarse | Quitar la línea del `.gitignore` o sacar el archivo del índice |

### 2) Technical Debt

| Debt item | Why it exists | Where | Risk if ignored | Suggested fix |
|-----------|---------------|-------|-----------------|---------------|
| Archivo de rutas duplicado y no usado | Refactor a medias entre dos middlewares de autorización | `backend/src/routes/usuarioRoute.js` vs `usuarioRoutes.js`; `backend/src/app.js:59` | Editar el archivo equivocado no tiene efecto | Eliminar `usuarioRoute.js` |
| Indirección redundante de middleware | `profileAuthMiddleware` solo reexporta `requireRoles` | `backend/src/middlewares/profileAuthMiddleware.js:1-5` | Capas extra sin valor | Importar directamente desde `authMiddleware` |
| Protocolo JSON/WebSocket obsoleto | Restos de la etapa ESP8266 | `comunicacion-iot/shared/protocol.py`, `constants.py`, `message_examples.json` | Confusión sobre el protocolo vigente | Eliminar o marcar como histórico (una parte ya lo está en `comunicacion-iot/docs/analisis-codigos-referencia.md`) |
| README de la app genérico | Plantilla de Flutter sin personalizar | `frontend/README.md:1-5` | Documentación engañosa para nuevos colaboradores | Reescribir o eliminar |
| Andamiaje de plataformas no usadas | Generado por `flutter create` | `frontend/{ios,linux,macos,web,windows}/` | Ruido y builds accidentales | Documentar que Android es la plataforma objetivo; eliminar lo no usado |
| Prueba marcador de posición | Plantilla original | `frontend/test/widget_test.dart` | Falsa sensación de cobertura | Reemplazar por una prueba real o eliminarla |
| Paginación por cursor dependiente de fecha válida | El cursor es la fecha del último documento | `backend/src/controllers/ganaderoController.js:162-210` | Documentos sin `fecha_hora_inicio`/`fecha_hora` no son alcanzables por paginación | Validar que todos los documentos tengan fecha al escribirlos |

### 3) Security Concerns

| Risk | OWASP category (if applicable) | Evidence | Current mitigation | Gap |
|------|--------------------------------|----------|--------------------|-----|
| Clave de cliente de Firebase versionada | A02 (fallo criptográfico) / A05 (mala configuración) | `git ls-files`, `frontend/android/app/google-services.json` | Firebase asume que es pública; el acceso real lo limitan las reglas | Decisión y documentación explícitas |
| Tráfico HTTP en claro permitido en depuración | A02 | `frontend/android/app/build.gradle.kts:34-42` (release en `false`) | Bloqueado en `release`; el cliente exige HTTPS salvo host local (`api_client.dart:60-88`) | Evitar builds de release con `--dart-define` apuntando a HTTP |
| Fuga de detalle en errores | A05 | `backend/src/utils/validation.js:43-56` devuelve mensajes cortos y registra el detalle en consola | Mensajes genéricos al cliente | Revisar que ningún controlador devuelva mensajes de excepción internos (los de Firestore se traducen a `503`) |
| Bloqueo de cuenta por operación a medias | A07 (fallo de identificación) | `backend/src/middlewares/authMiddleware.js` (chequeo de `operacion_pendiente`) | Mensaje diferenciado y reintento con los mismos datos | Sin procedimiento documentado de recuperación para el administrador |
| Antirreplay dependiente de un archivo local | A04 (diseño inseguro) | `jetson/secure_protocol.py:60-70` | SQLite con expiración de solicitudes | Borrar el estado habilita reejecución; el operador no debe eliminarlo |
| Secretos en el árbol local de trabajo | A05 | `.codex` (ignorado) y `backend/.env` (ignorado) | No versionados | Rotar la clave del hotspot heredada y revisar `.codex` antes de compartir el repositorio |

No se detectaron inyecciones SQL (no hay SQL dinámico; el único SQLite es
interno con consultas parametrizadas en `jetson/secure_protocol.py:69-100`) ni
inyección de rutas en el backend (`documentId` valida el formato en
`backend/src/utils/validation.js:28-33`).

### 4) Performance and Scaling Concerns

| Concern | Evidence | Current symptom | Scaling risk | Suggested improvement |
|---------|----------|-----------------|--------------|-----------------------|
| Consultas dobles por compatibilidad heredada | `listOwnedMerged` lee subcolección + colección raíz | Dos lecturas por página de historial/alertas | Coste y latencia lineales con el histórico | Migrar y retirar la lectura heredada |
| Recarga completa del dashboard tras cada operación | `frontend/lib/viewmodels/ganadero_view_model.dart:140-142` | 3-4 peticiones después de guardar un conteo | Muchas peticiones si hay varios usuarios | Actualización optimista o recarga dirigida |
| Latencia de la API en entorno local observada | Log del backend: ~1,6 s por petición en pruebas locales (`AGENTS.md`, sección 13) | Sondeo cada ~4-7 s se percibe lento | Peor en red móvil | Medir y considerar caché o agregación de lecturas |
| Detección de objetos pequeños a 20-30 m | Modelo MobileNet SSD 640 (declarado) + `--csi-width 1920` | Recall bajo en animales de ~15-30 px | Subconteo estructural, no corregible por el tracker | Evaluar inferencia por mosaicos (tiling) con `--export-detections` para medir |
| Contador y tracker en el hilo de inferencia | `jetson/run_bovino.py` (`infer_worker`) | `PIPELINE_METRIC` reporta `tracking_ms` | GMC (ORB) puede dominar el presupuesto de cómputo | Medir con `--tracker none` vs `botsort` y ajustar `--gmc` |
| Límite de tasa global | `backend/src/app.js:18-21` (120/min por IP) | Ninguno hoy | Varios usuarios tras una misma IP podrían agotarlo | Ajustar el límite por usuario o elevar el umbral |
| Sesión de conteo acotada a 10 minutos | `jetson/lora_jetson_rx.py:62` (`COUNT_MAX_DURATION_SEC = 600`) | Ninguno hoy | Sesiones largas se cortan con `reason=timeout` | Confirmar con la operación real y parametrizar |

### 5) Fragile/High-Churn Areas

| Area | Why fragile | Churn signal | Safe change strategy |
|------|-------------|--------------|----------------------|
| `jetson/run_bovino.py` (2.728 líneas) | Concentra captura, inferencia, tracker, conteo, métricas y dibujo en un archivo | Reescritura mayor reciente (tracker) y cambios locales sin commitear | Cambios con `py_compile` + harness de tracking; no tocar el detector sin video de prueba |
| `jetson/lora_jetson_rx.py` (1.706 líneas) | Radio, sesión, worker y protocolo en un solo proceso | Incidentes de SPI/LoRa documentados | Probar con `unittest` y verificar un único propietario del SPI |
| `backend/src/controllers/ganaderoController.js` | Mezcla compatibilidad heredada, paginación y transacciones | Cambios repetidos en las últimas sesiones | Cubrir con integración antes de refactorizar |
| `frontend/lib/data/services/esp32_ble_bridge_service.dart` | Orquesta BLE, API, sondeo y errores tipados | Cambios frecuentes por incidencias de campo | Probar con `flutter test` y simular escenarios de fallo |
| `AGENTS.md` (60 KB) | Bitácora acumulativa; riesgo de contradicción interna | Alta frecuencia de edición | Consolidar secciones antiguas en un apéndice histórico |

Dato del escáner: los archivos con más cambios en los últimos 90 días fueron
precisamente los del backend y la app listados arriba
(`docs/codebase/.codebase-scan.txt`, sección `HIGH-CHURN FILES`). El listado
incluye rutas de `node_modules` porque ese directorio estaba versionado en
`main`; el commit `d3fbb66` lo retiró del repositorio.

### 6) `[ASK USER]` Questions

1. `[ASK USER]` ¿Se mantiene `google-services.json` (backend y Android) versionado, o se retira del repositorio y se distribuye por otro canal?
2. `[ASK USER]` ¿El despliegue en Vercel está activo y es el destino real de la app, o el backend de la demostración será local (`adb reverse`)?
3. `[ASK USER]` ¿Las reglas de `firestore.rules` ya están desplegadas en el proyecto Firebase de producción?
4. `[ASK USER]` ¿Se migrarán las colecciones heredadas de nivel raíz (`Conteos`, `Alertas`, `ConfiguracionSistema`) y se eliminará la lectura de compatibilidad?
5. `[ASK USER]` ¿Cuál es la regla de negocio del conteo: máximo de animales simultáneos, animales únicos que pasan por el campo de visión, o ambos?
6. `[ASK USER]` ¿Se usará `--reid` en campo, aceptando el riesgo de subconteo por fusión de identidades?
7. `[ASK USER]` ¿El tope de 10 minutos por sesión (`COUNT_MAX_DURATION_SEC`) es suficiente para el paso real del ganado?
8. `[ASK USER]` ¿La app se publicará en Play Store (implica `applicationId` definitivo y firma de release) o se distribuirá como APK?
9. `[ASK USER]` ¿Se requiere funcionamiento sin conexión en la app para zonas sin cobertura?
10. `[ASK USER]` ¿Se acepta modificar la etapa de detección (por ejemplo, inferencia por mosaicos) para mejorar el recall a 20-30 m de altitud?

### 7) Evidence

- `docs/codebase/.codebase-scan.txt` (riesgos, churn, ausencia de CI/CD y de linting)
- `backend/src/`, `frontend/lib/`, `jetson/`, `comunicacion-iot/` (archivos citados en cada fila)
- `git ls-files`, `git check-ignore`, `.gitignore` (verificación de versionado de credenciales)
- `AGENTS.md` secciones 6, 8, 12 y 13 (incidentes y mediciones previas)
