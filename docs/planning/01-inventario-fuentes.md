# 01 — Inventario de fuentes de planificación

Fase 1 de la skill `bovisense-plan-consolidator`. Registra los documentos que
contienen decisiones, requisitos, tareas o instrucciones para el proyecto, con
su estado de vigencia verificado contra el código actual. **Ningún archivo
original fue modificado.**

Análisis realizado el 2026-10-12 sobre la rama `dev` (último commit `84dc003`)
con cambios locales pendientes en `AGENTS.md`, `README.md` y
`jetson/run_bovino.py`.

## 1. Aclaraciones sobre los archivos solicitados

La instrucción mencionó archivos que no existen con ese nombre exacto. Se
verificó el sistema de archivos:

| Solicitado | Realidad verificada |
|------------|---------------------|
| `revision.txt` | No existe. El archivo real es `revicion.txt` (sinónimo con errata ortográfica). |
| `agent.md` | No existe. Los equivalentes son `AGENTS.md` (raíz), el archivo `.codex` y `backend/.codex`. |
| `pasos/` (directorio) | No existe. El archivo real es `pasos.txt`. |
| `.codex/` (directorio) | Es un **archivo** `.codex` de 402 líneas, no un directorio. Existe además `backend/.codex`, que está **vacío** (0 bytes). |

## 2. Fuentes analizadas

| ID | Archivo | Tipo | Tamaño | Vigencia verificada | Uso en esta consolidación |
|----|---------|------|--------|---------------------|---------------------------|
| S1 | `revicion.txt` | Prompt de auditoría en 25 fases (read-only) | 1541 líneas | **Vigente como proceso**; su contenido es una instrucción, no un informe | Requisitos de proceso, seguridad y calidad |
| S2 | `AGENTS.md` | Bitácora de traspaso con 22 secciones y registro de sesiones | 928 líneas | **Vigente**; es la fuente más completa del estado real | Requisitos, decisiones, incidentes y tareas |
| S3 | `.codex` | Contexto histórico del proyecto (dos etapas) | 402 líneas | **Parcialmente obsoleta**: la primera mitad describe ESP8266 + hotspot + descubrimiento UDP/HTTP; la segunda, ESP32 BLE con protocolo `CMD:`/`RESP:` | Requisitos históricos y detección de contradicciones |
| S4 | `pasos.txt` | Instrucción de reorganización UX del módulo ganadero + contenido ajeno al proyecto + credenciales expuestas | 282 líneas | **Parcialmente vigente**: los requisitos de UX siguen siendo válidos; el protocolo que menciona (`CMD:`, `JETSON_COUNT:`) está obsoleto | Requisitos de UX, seguridad (fuga de credenciales) |
| S5 | `jetson/tracking.md` | Especificación técnica del tracking de conteo | 1111 líneas | **Vigente**; describe la tarea de tracking implementada en `run_bovino.py` | Requisitos del módulo Jetson |
| S6 | `docs/seguridad-y-despliegue.md` | Documento de seguridad y despliegue | 87 líneas | **Vigente** | Requisitos de protocolo, secretos y despliegue |
| S7 | `README.md` | Presentación del producto | 55 líneas (tenía 190 en el commit anterior) | **Modificado localmente sin commitear**: se eliminaron las secciones de arquitectura, stack, estructura y API | Contexto de producto; el detalle técnico vive ahora en `docs/` |
| S8 | `comunicacion-iot/docs/*`, `comunicacion-iot/hardware/*` | Documentación de protocolo y hardware | 7 archivos | **Vigente** (reescrita para C1/R1 en el commit `7d10336`) | Requisitos de hardware y protocolo |
| S9 | `docs/codebase/*`, `docs/arquitectura/*` | Documentación técnica generada el 2026-10-12 | 15 archivos, ~2500 líneas | **Derivada del código**, no fuente original de requisitos | Verificación y trazabilidad (se usa como evidencia, nunca como requisito) |
| S10 | Historial Git (`git log`) | Registro de cambios | 20+ commits | **Evidencia objetiva** | Verificación de qué se implementó y cuándo |
| S11 | `frontend/README.md` | Plantilla por defecto de Flutter | 8 líneas | **Sin valor de planificación** | Descartada (documentación engañosa, ver conflictos) |
| S12 | `.agents/skills/*`, `skills-lock.json` | Skills de análisis instaladas | 3 skills | **Herramientas**, no planificación | Metodología del análisis |
| S13 | `backend/.codex` | Archivo vacío | 0 bytes | Sin contenido | Descartada |

## 3. Fuentes complementarias revisadas

Además de los documentos de planificación, se contrastó el contenido con:

| Fuente | Qué aporta | Evidencia |
|--------|-----------|-----------|
| Código fuente | Comportamiento real por módulo | `backend/src/**`, `frontend/lib/**`, `jetson/*.py`, `comunicacion-iot/esp32/**` |
| Pruebas | Qué está verificado automáticamente | `backend/test/**`, `frontend/test/**`, `jetson/test_secure_protocol.py` |
| Configuración | Despliegue y seguridad | `backend/vercel.json`, `firestore.rules`, `firebase.json`, `frontend/android/**`, `.gitignore` |
| `docs/codebase/.codebase-scan.txt` | Evidencia bruta del escaneo automatizado | Generado con la skill `acquire-codebase-knowledge` |

## 4. Exclusiones aplicadas

- `backend/node_modules/` (95 MB), `frontend/build/` (1,3 GB),
  `frontend/.dart_tool/` (270 MB), `__pycache__/`, `*.log`.
- Archivos binarios (íconos, imágenes del splash, `logoApp.png`).
- Credenciales: se referencian por ubicación y tipo, **nunca por valor**.

## 5. Hallazgo de seguridad en las fuentes (sin exponer valores)

`pasos.txt` contiene, en su bloque de contenido ajeno al proyecto,
**dos credenciales en texto claro**: una de tipo token personal de GitHub y otra
de tipo clave de API de un proveedor de LLM (líneas 223-224 del archivo). El
archivo está **ignorado por Git** (`.gitignore:6`), por lo que no está en el
repositorio remoto, pero permanece en el árbol de trabajo local.

`​.codex` contiene además la **contraseña del hotspot heredado** (línea 17), y
también está ignorado por Git (`.gitignore:2`).

Acción recomendada: rotar ambas credenciales y la clave del hotspot, y limpiar
esos bloques de los archivos locales. La skill prohíbe modificar documentos
históricos durante la consolidación, por lo que **no se alteraron**; queda
registrado como conflicto `C-04` y tarea `T-06`.

## 6. Evidencia

- `find`/`ls` sobre la raíz para verificar existencia y tamaño de cada fuente.
- `git check-ignore -v pasos.txt .codex revicion.txt` → los tres están ignorados.
- `git ls-files` → ninguno de los tres está versionado.
- `git log --oneline -20` y `git diff --stat README.md` para el estado del commit
  y de los cambios locales.
