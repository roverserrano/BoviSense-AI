# Planificación consolidada de BoviSense-AI

Documentos generados con la skill `bovisense-plan-consolidator` el 2026-10-12,
sobre la rama `dev` (commit `84dc003`) y con los cambios locales presentes en ese
momento.

Esta carpeta **centraliza** la planificación dispersa en los documentos
históricos del proyecto sin alterarlos, sin modificar código y sin inventar
requisitos.

## Estado: APROBADO Y EN EJECUCIÓN (2026-10-12)

El plan fue aprobado por el usuario. Se ejecutaron los bloques que no requieren
hardware: cierre del acceso sin autenticar del receptor (F1), higiene de secretos
y configuración (F2), cobertura de pruebas faltante (F6) e integración continua
(F7). Siguen bloqueadas las fases que dependen del equipo físico (F4, F5) y las
que requieren una decisión del usuario (F3, F8).

| Fase | Estado |
|------|--------|
| F0 consolidación | Completada |
| F1 protocolo sin autenticar | Completada en repositorio; **falta desplegar el receptor en la Jetson** |
| F2 secretos y configuración | Archivos limpios y `.gitignore` coherente; **falta rotar las credenciales** (acción del usuario) |
| F3 publicación Android | PENDIENTE_APROBACION (`applicationId` y firma) |
| F4, F5 hardware y tracking real | BLOQUEADAS (requieren equipo y vídeo) |
| F6 pruebas faltantes | Completada (T-13, T-14, T-15) |
| F7 CI/CD | Workflow añadido; sin verificar en GitHub |
| F8 decisiones de producto | PENDIENTE_APROBACION |

## Índice

| Documento | Contenido |
|-----------|-----------|
| [01-inventario-fuentes.md](01-inventario-fuentes.md) | Qué documentos existen, tipo, tamaño, vigencia verificada y qué archivos solicitados no existen |
| [02-estado-actual.md](02-estado-actual.md) | Estado real por módulo, distinguiendo implementación, validación automática y verificación en hardware |
| [03-catalogo-requisitos.md](03-catalogo-requisitos.md) | 56 requisitos con ID, fuente, estado y evidencia (34 validados, 12 implementados sin validar); más 6 descartados |
| [04-plan-maestro.md](04-plan-maestro.md) | 9 fases (F0-F8) con prioridad, dependencias y criterios de aceptación verificables |
| [05-backlog-ejecucion.md](05-backlog-ejecucion.md) | 22 tareas (T-01…T-22) con objetivo, requisito, estado, dependencias, componentes, criterios, pruebas, restricciones y evidencia |
| [06-registro-conflictos.md](06-registro-conflictos.md) | 14 conflictos (C-01…C-14): 4 resueltos, 1 parcial, 1 diferido, 2 con decisión pendiente, 3 abiertos, 3 históricos |
| [07-matriz-trazabilidad.md](07-matriz-trazabilidad.md) | Trazabilidad requisito ↔ fuente ↔ tarea ↔ código ↔ prueba |

Documentación relacionada (no forma parte de esta consolidación, pero se usa como
evidencia): [../codebase/](../codebase/) y [../arquitectura/](../arquitectura/).

## Marcadores y estados

- Estados de tarea y requisito: `PROPUESTA`, `PENDIENTE_APROBACION`,
  `APROBADA`, `EN_PROGRESO`, `IMPLEMENTADA_SIN_VALIDAR`, `VALIDADA`,
  `BLOQUEADA`, `DESCARTADA`.
- `VALIDADA` exige prueba automatizada o registro de ejecución documentado; no
  se usa para código meramente escrito.
- `PROPUESTA` señala recomendaciones técnicas que **no** son requisitos
  aprobados.

## Qué falta y de quién depende

| Bloque | Estado | Requiere |
|--------|--------|----------|
| F1 (protocolo sin autenticar) | Código corregido y probado | Copiar `lora_jetson_rx.py` a la Jetson y reiniciar el servicio |
| F2 (secretos expuestos) | Archivos limpios, `.gitignore` coherente | **Rotar** las credenciales (GitHub, proveedor de LLM, hotspot) |
| F3 (publicación Android) | Pendiente | Decisión del `applicationId` y firma de release |
| F4, F5 (hardware y tracking) | Bloqueadas | Acceso físico a Jetson, ESP32, cámara, vídeo aéreo y teléfono |
| F6 (pruebas faltantes) | Completada | — |
| F7 (CI/CD) | Workflow añadido | Primera ejecución en GitHub |
| F8 (decisiones de producto) | Pendiente | Respuestas del usuario (offline, push, migración, duración de sesión) |

## Límites de este análisis

- No se modificó código fuente, ni documentos históricos, ni configuraciones.
- No se ejecutaron despliegues ni comandos destructivos.
- No se expusieron credenciales: los hallazgos de secretos se referencian por
  ubicación y tipo.
- No se resolvió ningún conflicto por suposición.
