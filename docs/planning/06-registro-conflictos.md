# 06 — Registro de conflictos

Fase 3 de la skill (`Verificación`, punto 4: *detectar instrucciones
contradictorias u obsoletas*). Cada conflicto se registra con sus versiones y
**no se resuelve por suposición**: los que requieren decisión quedan marcados
como `REQUIERE DECISIÓN`.

Estados usados en este registro: `ABIERTO`, `REQUIERE DECISIÓN`, `RESUELTO`,
`DESCARTADO`.

---

## C-01 — El receptor acepta comandos sin autenticar

| Campo | Detalle |
|-------|---------|
| Estado | **RESUELTO** (2026-10-12) |
| Severidad | Crítica |
| Versión A (código) | `jetson/lora_jetson_rx.py:1398-1459`: si la trama no empieza por `C1\|`, se evalúa un diccionario `legacy_commands` (`BRIDGE`, `ESTADO`, `PREPARARCONTEO`, `INICIARCONTEO`, `DETENERCONTEO`, `ESTADOCONTEO`, `RESULTADOCONTEO`) y se ejecuta directamente sobre el `CountSessionController`, respondiendo `RESP\|msg_id\|JETSON_COUNT\|...` **sin HMAC** |
| Versión B (documentación) | `docs/seguridad-y-despliegue.md`: «El backend firma comandos `C1` con HMAC-SHA256 y Jetson responde con tramas `R1` firmadas»; `AGENTS.md` §3 define los únicos comandos válidos como C1/R1 |
| Impacto | Un emisor LoRa con el formato correcto podría iniciar, consultar o detener conteos sin credenciales. El puente BLE no es el vector (rechaza lo que no empiece por `C1\|`, `.ino:245`), pero el enlace LoRa sí es alcanzable |
| Mitigaciones existentes | El puente filtra tramas desde BLE; las pruebas del protocolo seguro están en verde. El camino heredado **no** está cubierto por ninguna prueba |
| Decisión requerida | ¿Eliminar el camino heredado, mantenerlo tras una bandera desactivada por defecto, o autenticarlo con C1? |
| Tareas asociadas | T-01, T-02, T-03 |
| Evidencia | `jetson/lora_jetson_rx.py:1398-1459`; `.ino:245-249`; `rg -F "RESP\|" jetson/*.py` → 1 archivo |
| Resolución aplicada | Se eliminó el camino heredado completo (despacho `legacy_commands` y los helpers `build_count_response`, `build_jetson_status_response`, `clean_field`, `read_*`, más el import de `socket`). Ahora cualquier trama que no sea `C1\|` se registra y se descarta. Prueba de regresión: `test_unsigned_frames_never_execute_commands`. Pendiente desplegar el archivo actualizado en la Jetson. |

---

## C-02 — `.codex` describe la arquitectura ESP8266 como vigente

| Campo | Detalle |
|-------|---------|
| Estado | **DESCARTADO** (obsoleto, se conserva como histórico) |
| Severidad | Baja (documental) |
| Versión A (histórica) | `.codex:3-109`: hardware ESP8266 + LoRa, hotspot del teléfono, HTTP en puerto 80 (`/ping`, `/status`, `/send`), descubrimiento UDP 4210, servicios Flutter `esp8266_*` |
| Versión B (real) | El firmware ESP8266 se eliminó del repositorio (commit `7d10336`) y los servicios de la app también; el transporte actual es BLE hacia `BoviSense-Bridge` |
| Impacto | Un lector nuevo podría intentar reproducir un flujo que ya no existe |
| Evidencia | `rg -i "esp8266" frontend/lib backend/src` → sin resultados; `git show --stat 7d10336`; `comunicacion-iot/esp32/` |
| Acción | Ninguna sobre el archivo (histórico); la documentación vigente está en `docs/codebase/` y `docs/arquitectura/` |

---

## C-03 — Protocolos `CMD:` / `RESP:` documentados frente a C1/R1 implementado

| Campo | Detalle |
|-------|---------|
| Estado | **DESCARTADO** para la app; **relacionado con C-01** en la Jetson |
| Severidad | Media |
| Versión A (histórica) | `.codex:187-240` define la app enviando `CMD:<comando>` y recibiendo `JETSON_STATUS:`/`JETSON_COUNT:`; `pasos.txt:11-18,193-200` lista `CMD:PREPARARCONTEO`, `CMD:INICIARCONTEO`, etc., y pide mantener compatibilidad con `JETSON_STATUS`/`JETSON_COUNT` |
| Versión B (real) | `backend/src/services/iotProtocol.js:4` define los comandos como `H/P/S/T/Q/R` dentro de tramas C1; la app escribe `~<C1>\n` por BLE |
| Impacto | Ninguno en la app (ya migrada). En la Jetson, el camino heredado que atiende esas tramas sigue presente (C-01) |
| Evidencia | `rg -F "CMD:" frontend/lib backend/src jetson/*.py` → sin resultados; `RESP\|` presente solo en `jetson/lora_jetson_rx.py:1377` |

---

## C-04 — Credenciales en texto claro en archivos locales

| Campo | Detalle |
|-------|---------|
| Estado | **PARCIAL** (archivos limpiados el 2026-10-12; falta rotar) |
| Severidad | Crítica |
| Hallazgo | `pasos.txt` contiene dos credenciales en claro (un token personal de GitHub y una clave de API de un proveedor de LLM) en su bloque de contenido ajeno; `.codex` contiene la contraseña del hotspot heredado |
| Contradicción | `revicion.txt` Fase 10 exige «no exponer secretos»; `AGENTS.md` §6.7 pide rotar credenciales expuestas; `docs/seguridad-y-despliegue.md` advierte de no incluir claves en Git |
| Mitigación existente | Ambos archivos están **ignorados por Git** (`.gitignore:2,6`) y no están versionados |
| Impacto | Si el árbol de trabajo se comparte (zip, respaldo, captura), las credenciales quedan expuestas y activas |
| Decisión requerida | Rotar las credenciales y decidir cómo limpiar los archivos locales conservando su contenido útil |
| Tareas asociadas | T-04, T-05, T-21 |
| Evidencia | `pasos.txt:223-224`, `.codex:17` (referencias por ubicación, sin exponer valores); `git check-ignore -v pasos.txt .codex` |
| Resolución aplicada | Se sustituyeron las dos credenciales y la contraseña del hotspot por un marcador explícito de redacción, conservando el resto del contenido. Barrido posterior (`ghp_`, `sk-`, `AKIA`, claves privadas, 64-hex) sin hallazgos en el árbol. **La rotación en cada proveedor sigue pendiente y es acción del usuario.** |

---

## C-05 — `google-services.json` versionado frente a `.gitignore` que ignora credenciales

| Campo | Detalle |
|-------|---------|
| Estado | **RESUELTO** (2026-10-12) |
| Severidad | Media |
| Versión A | `.gitignore:4-5` ignora la cuenta de servicio y `backend/google-services.json` |
| Versión B (real) | `git ls-files` muestra `backend/google-services.json` y `frontend/android/app/google-services.json` **versionados** (la regla no aplica a archivos ya rastreados) |
| Aclaración técnica | Ese archivo contiene configuración pública del cliente Firebase (id y número de proyecto, `api_key` de cliente), que Google trata como no secreta; el archivo sensible es la cuenta de servicio, que sí está fuera |
| Impacto | No es una fuga de secreto de servidor, pero es una decisión implícita que conviene documentar |
| Decisión requerida | ¿Se conservan versionados o se retiran del repositorio? |
| Tareas asociadas | T-06, T-07 |
| Evidencia | `git ls-files \| rg "google-services"`; `git check-ignore -v` |
| Resolución aplicada | Se conservan versionados: son configuración pública de cliente Firebase (el archivo sensible, la cuenta de servicio, sigue fuera de Git). Se documentó la decisión como comentario en `.gitignore`. |

---

## C-06 — Regla de `.gitignore` sobre un archivo versionado

| Campo | Detalle |
|-------|---------|
| Estado | **RESUELTO** (2026-10-12) |
| Severidad | Baja |
| Hallazgo | `.gitignore:8` ignora `AGENTS.md`, pero `AGENTS.md` está versionado desde el commit `7d10336` (una regla de ignore no afecta a archivos ya rastreados) |
| Impacto | Confusión sobre si el documento de traspaso debe versionarse |
| Decisión requerida | Quitar la regla o sacar el archivo del índice |
| Tareas asociadas | T-07 |
| Evidencia | `.gitignore:8`; `git ls-files \| rg AGENTS.md` |
| Resolución aplicada | Se eliminaron de `.gitignore` las reglas sin efecto (`AGENTS.md` y `/backend/google-services.json`) y se añadió una nota explicando qué se versiona a propósito. Verificado: ningún archivo versionado queda ignorado. |

---

## C-07 — ReID: la especificación lo prohíbe, el código lo activa por defecto

| Campo | Detalle |
|-------|---------|
| Estado | **DIFERIDO** a la medición de F5 (2026-10-12) |
| Severidad | Media |
| Versión A (especificación) | `jetson/tracking.md` (sección ReID): «NO implementar todavía un modelo ReID adicional… Deja la arquitectura preparada, pero NO la implementes ahora» |
| Versión B (implementación) | `jetson/run_bovino.py:1497-1560` implementa `_reid_score` con descriptores HSV y reglas espaciales y de tamaño; `--reid` está activo por defecto |
| Análisis | No es un ReID con CNN (cumple la prohibición literal), pero sí una heurística de identidad que puede fusionar dos animales distintos y **subcontar** |
| Decisión requerida | ¿Se mantiene activado por defecto, se desactiva en campo, o se documenta como experimental? |
| Tareas asociadas | T-11, T-12 |
| Evidencia | `jetson/run_bovino.py:1497-1560,2540` (`--reid`); `jetson/tracking.md` |
| Decisión provisional | No se cambia el comportamiento por defecto: activar o desactivar el ReID altera el conteo y debe decidirse con datos. En su lugar, el arranque ahora imprime explícitamente el riesgo de subconteo y sugiere comparar con `--no-reid`. La decisión final corresponde a F5 (comparativa de trackers con vídeo real). |

---

## C-08 — Doble fuente de datos: subcolecciones por usuario y colecciones heredadas

| Campo | Detalle |
|-------|---------|
| Estado | **REQUIERE DECISIÓN** |
| Severidad | Media |
| Versión A (modelo documentado) | `docs/arquitectura/api-http.md` y `AGENTS.md` describen los datos del usuario bajo `Usuarios/{uid}/…` |
| Versión B (implementación) | `backend/src/controllers/ganaderoController.js:127-221` lee además las colecciones de nivel raíz `Conteos`, `Alertas` y `ConfiguracionSistema`, y fusiona resultados por id |
| Impacto | Cada lectura de historial y alertas hace dos consultas; riesgo de inconsistencias durante una migración |
| Decisión requerida | ¿Se migran los datos y se retira la compatibilidad, o se documenta como deuda aceptada? |
| Tareas asociadas | T-14, T-18 |
| Evidencia | `ganaderoController.js:127-221`; `docs/arquitectura/api-http.md` |

---

## C-09 — `pasos.txt` mezcla requisitos del proyecto con contenido ajeno

| Campo | Detalle |
|-------|---------|
| Estado | **REQUIERE DECISIÓN** (menor) |
| Severidad | Baja |
| Hallazgo | El archivo contiene, además de la instrucción de UX del módulo ganadero (líneas 1-220), un pedido de landing page en Next.js (líneas 229-278) y el comando `pkill -x cloudflared` (línea 281) |
| Riesgo | Un agente futuro podría interpretar ese contenido como parte del proyecto o ejecutar el comando |
| Decisión requerida | ¿Se archiva por separado, se conserva íntegro o se limpia? |
| Tareas asociadas | T-21 |
| Evidencia | `pasos.txt:229-281` |

---

## C-10 — Parámetros históricos obsoletos que contradicen el código vigente

| Campo | Detalle |
|-------|---------|
| Estado | **DESCARTADO** (histórico) |
| Severidad | Media (induce a error al diagnosticar) |
| Contradicciones | (1) SPI 500 kHz (`.codex:271`) vs 10 kHz (`jetson/lora_jetson_rx.py:22`); (2) TX 2 dBm (`.codex:278`) vs 17 dBm (`:42`); (3) fuente `http://192.168.1.4:8080/video` (`.codex:309`) vs `csi://0` (`:52`); (4) ruta `~/Documents/lora/lora_jetson_rx.py` (`.codex:158`) vs `/home/cow/Documents/Script/` (`:48-51`); (5) RST por GPIO desactivado en el script (`.codex:286`) vs RST puenteado a 3.3 V (`AGENTS.md` §4) |
| Impacto | Diagnósticos equivocados si se sigue el documento histórico |
| Acción | Ninguna sobre el archivo; la referencia vigente es `AGENTS.md` §4 y `comunicacion-iot/hardware/pinout-sugerido.md` |
| Evidencia | Las rutas y líneas citadas |

---

## C-11 — Falta el informe de la auditoría solicitada

| Campo | Detalle |
|-------|---------|
| Estado | **ABIERTO** |
| Severidad | Media (trazabilidad académica) |
| Hallazgo | `revicion.txt` pide una auditoría completa con informe (fases 1-25, formato de hallazgos y validación final) y prohíbe corregir antes de autorizar. En el repositorio **no existe** un archivo de resultados de esa auditoría |
| Evidencia disponible | Los resultados están dispersos: `AGENTS.md` §10-§22 documenta correcciones e incidentes; `docs/codebase/CONCERNS.md` (generado el 2026-10-12) contiene el análisis de riesgos |
| Impacto | No hay un entregable único con severidades, evidencia y estado de cada hallazgo |
| Decisión requerida | ¿Se acepta `docs/codebase/CONCERNS.md` como informe, o se debe producir uno nuevo siguiendo el formato de `revicion.txt`? |
| Tareas asociadas | T-19 (decisión), posible tarea nueva de informe |
| Evidencia | `revicion.txt:1480-1530` (validación final y formato); ausencia de informe en `find . -name "*.md"` |

---

## C-12 — Divergencia entre `main` y `dev` en `app_config.dart`

| Campo | Detalle |
|-------|---------|
| Estado | **RESUELTO** |
| Severidad | Baja |
| Historial | `main` tenía la URL del backend alojado fija (`commit b55aeba`), mientras `dev` parametrizó la URL con `--dart-define` y dejó el valor local por defecto. El merge `dev → main` conflicto en ese archivo |
| Resolución aplicada | El merge tomó la versión de `dev`; `main` quedó en `e5613bc` con el mismo contenido que `dev` (`git diff dev main` sin diferencias) |
| Consecuencia a tener en cuenta | Al no quedar la URL alojada por defecto, **todo build de release debe pasar `--dart-define=API_BASE_URL=https://…`** (coherente con `R-FLUTTER-13` y T-08) |
| Evidencia | `git branch -vv` (`main e5613bc Merge branch 'dev'`); `git diff --stat dev main` vacío; `git show main:frontend/lib/core/config/app_config.dart` |

---

## C-13 — `README.md` reducido localmente sin commitear

| Campo | Detalle |
|-------|---------|
| Estado | **ABIERTO** |
| Severidad | Baja |
| Hallazgo | El `README.md` de la raíz pasó de ~190 a 55 líneas: se eliminaron las secciones de arquitectura, stack, estructura del repositorio y resumen de API. Es un cambio local sin commitear, ajeno a esta sesión |
| Interpretación | Coherente si la intención es que el detalle técnico viva en `docs/` (donde ahora existe `docs/arquitectura/`), pero es una decisión no documentada |
| Decisión requerida | ¿Se consolida la reducción (y se enlaza `docs/`) o se restaura el contenido? |
| Evidencia | `git diff --stat README.md` (`1 insertion, 182 deletions`); `rg "^#" README.md` |

---

## C-14 — El contador del panel no deduplica registros repetidos entre colecciones

| Campo | Detalle |
|-------|---------|
| Estado | **ABIERTO** (observación detectada el 2026-10-12 al escribir la prueba de T-14) |
| Severidad | Baja |
| Hallazgo | El listado de conteos y alertas deduplica por id entre la subcolección del usuario y la colección heredada, pero `obtenerDashboard` suma **documentos por colección** (`refs.conteosRef.count()` + `db.collection('Conteos').where('uid','==',uid).count()`), sin deduplicar |
| Consecuencia | Si el mismo id existe en ambas ubicaciones, el panel muestra un total mayor que el historial visible (por ejemplo 3 frente a 2) |
| Mitigación actual | La prueba `legacy collections are merged without duplicating records` fija el comportamiento real y lo documenta |
| Decisión requerida | ¿Se migran los datos (T-18) y desaparece el caso, o se cambia el contador para contar ids únicos? |
| Evidencia | `backend/src/controllers/ganaderoController.js:267-300` (contadores) frente a `:175-210` (deduplicación del listado); caso de integración citado |

## Resumen

| Estado | Conflictos |
|--------|-----------|
| RESUELTO | C-01, C-05, C-06, C-12 |
| PARCIAL | C-04 (archivos limpios, rotación pendiente) |
| DIFERIDO | C-07 (decisión con datos en F5) |
| REQUIERE DECISIÓN | C-08, C-09 |
| ABIERTO | C-11, C-13, C-14 |
| DESCARTADO (histórico) | C-02, C-03, C-10 |

## Registro de ejecución (2026-10-12)

Ejecutado tras la aprobación del plan, sin acceso a hardware:

| Tarea | Resultado |
|-------|-----------|
| T-01 / T-02 / T-03 | Camino heredado eliminado; prueba de regresión añadida; receptor en 22/22 |
| T-05 | Credenciales redactadas en `pasos.txt` y `.codex`; barrido sin hallazgos |
| T-06 / T-07 | Decisión documentada y `.gitignore` coherente (ningún versionado ignorado) |
| T-13 | Nueva suite `jetson/test_tracking_logic.py` (9 casos) |
| T-14 / T-15 | Nuevas pruebas de integración (colecciones heredadas, trazas y límites); suite en 12/12 |
| T-22 | Workflow `.github/workflows/ci.yml` con 4 jobs |
| T-04 | **Pendiente**: rotación de credenciales (acción del usuario) |
| T-09 a T-12 | **Bloqueadas**: requieren hardware |

Ningún conflicto fue resuelto por suposición. Los que requieren decisión están
detallados con sus versiones y su impacto, y aparecen como tareas
`PENDIENTE_APROBACION` en `05-backlog-ejecucion.md`.
