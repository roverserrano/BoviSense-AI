# Documentación técnica de BoviSense-AI

Índice navegable de la documentación del proyecto. Todo el contenido de esta
carpeta describe **lo que el repositorio realmente implementa**, con referencia
al archivo y línea de origen en cada afirmación relevante.

Generado: 2026-10-12 sobre la rama `dev`, commit `84dc003`. Actualizado:
2026-10-17 con la skill `code-documentation`: se agregó la sección 6, se
reverificaron los conteos de pruebas (4 unitarias de backend, 12 de integración,
32 de Flutter, 22 del receptor Jetson y 9 de tracking) y se corrigieron
referencias de línea y afirmaciones desactualizadas (por ejemplo, el estado del
CI tras `b94fcda`) en `codebase/` y `arquitectura/`.

## Cómo leer estos documentos

Marcadores usados en toda la documentación:

| Marcador | Significado |
| --- | --- |
| `PENDIENTE DE VERIFICACIÓN` | Dato que no puede confirmarse solo con el repositorio (equivale al `[TODO]` de la plantilla de la skill). Requiere revisar hardware, un servicio externo o una decisión de equipo. |
| `[ASK USER]` | Decisión que depende de la intención del equipo, no del código. |
| `Implementación real` | Comportamiento verificado en el código fuente. |
| `Configuración detectada` | Archivo de configuración presente en el repositorio; no implica que esté desplegado. |
| `Arquitectura propuesta` | Recomendación de esta documentación, **no** implementada hoy. |

### Skills del proyecto (`.agents/skills/`)

| Skill | Origen | Uso en esta documentación |
| --- | --- | --- |
| `acquire-codebase-knowledge` | github/awesome-copilot | Sección 1: conocimiento del código. |
| `architecture-blueprint-generator` | github/awesome-copilot | Sección 2: blueprint de arquitectura. |
| `bovisense-plan-consolidator` | Local del proyecto | Sección 5: planificación consolidada. |
| `code-documentation` | bytedance/deer-flow | Sección 6: documentación de código, CHANGELOG, CONTRIBUTING y README por módulo (2026-10-17). |

Se instalan con `npx skills add <repo> --skill <nombre>`; el registro de las
instaladas por el CLI está en `skills-lock.json`.

Se excluyeron del análisis los artefactos generados y dependencias:
`backend/node_modules/` (95 MB), `frontend/build/` (1,3 GB),
`frontend/.dart_tool/` (270 MB), `__pycache__/` y `*.log`.

No se incluyen secretos, tokens ni credenciales. Los valores de configuración
privada se referencian por **nombre de variable** y ruta, nunca por contenido.

## Índice

### 1. Conocimiento del código (skill `acquire-codebase-knowledge`)

| Documento | Contenido |
| --- | --- |
| [codebase/STACK.md](codebase/STACK.md) | Lenguajes, runtimes, dependencias de producción y de desarrollo, comandos clave. |
| [codebase/STRUCTURE.md](codebase/STRUCTURE.md) | Mapa de carpetas, puntos de entrada, límites entre módulos. |
| [codebase/ARCHITECTURE.md](codebase/ARCHITECTURE.md) | Estilo arquitectónico real, flujo del sistema, patrones reutilizados. |
| [codebase/CONVENTIONS.md](codebase/CONVENTIONS.md) | Convenciones de nombres, formato, importaciones, errores y logs. |
| [codebase/INTEGRATIONS.md](codebase/INTEGRATIONS.md) | Firebase, SMTP, dispositivo IoT, BLE, LoRa y archivos de estado. |
| [codebase/TESTING.md](codebase/TESTING.md) | Frameworks de prueba, disposición de tests, estrategia de aislamiento. |
| [codebase/CONCERNS.md](codebase/CONCERNS.md) | Riesgos priorizados, deuda técnica, seguridad, rendimiento. |
| [codebase/.codebase-scan.txt](codebase/.codebase-scan.txt) | Salida cruda del escaneo automatizado (evidencia bruta). |

### 2. Arquitectura (skill `architecture-blueprint-generator`)

| Documento | Contenido |
| --- | --- |
| [arquitectura/blueprint.md](arquitectura/blueprint.md) | Blueprint de arquitectura: detección de estilo, componentes, capas, decisiones y guía de extensión. |
| [arquitectura/modulos.md](arquitectura/modulos.md) | Módulo por módulo: responsabilidad, entradas, salidas, contratos públicos y dependencias. |
| [arquitectura/diagramas.md](arquitectura/diagramas.md) | Diagramas C4 (contexto y contenedores), de componentes, de secuencia y de despliegue en Mermaid. |

### 3. Contratos y operación

| Documento | Contenido |
| --- | --- |
| [arquitectura/api-http.md](arquitectura/api-http.md) | Catálogo de endpoints HTTP con contrato real: entrada, salida, códigos de error y autorización. |
| [arquitectura/integraciones-iot.md](arquitectura/integraciones-iot.md) | Interacción app, ESP32, LoRa, Jetson y backend, con evidencia. |
| [arquitectura/flujos-datos.md](arquitectura/flujos-datos.md) | Flujos extremo a extremo: login, alta de usuario, sesión de conteo, alerta. |
| [arquitectura/despliegue.md](arquitectura/despliegue.md) | Configuración de Vercel, build y ejecución en Android, y servicio de la Jetson. |
| [arquitectura/desarrollo.md](arquitectura/desarrollo.md) | Entorno local, comandos por módulo, pruebas y flujo de trabajo recomendado. |

### 4. Documentación previa (se conserva)

| Documento | Contenido |
| --- | --- |
| [seguridad-y-despliegue.md](seguridad-y-despliegue.md) | Protocolo IoT, clave compartida, requisitos de despliegue y reglas de Firestore. Documento preexistente, no modificado. |
| [../.agents/Instrucciones/AGENTS.md](../.agents/Instrucciones/AGENTS.md) | Bitácora de traspaso del proyecto: estado, incidentes resueltos y decisiones acumuladas. |
| [../README.md](../README.md) | Presentación del producto para lectores no técnicos. |
| [../comunicacion-iot/docs/](../comunicacion-iot/docs/) | Documentos del protocolo C1/R1 y pinout del hardware. |

### 5. Planificación consolidada (skill `bovisense-plan-consolidator`)

| Documento | Contenido |
| --- | --- |
| [planning/README.md](planning/README.md) | Entrada de la planificación consolidada y estado de aprobación. |
| [planning/01-inventario-fuentes.md](planning/01-inventario-fuentes.md) | Inventario de documentos históricos, vigencia y archivos inexistentes. |
| [planning/02-estado-actual.md](planning/02-estado-actual.md) | Estado verificado por módulo (implementación, validación y hardware). |
| [planning/03-catalogo-requisitos.md](planning/03-catalogo-requisitos.md) | Catálogo de requisitos con estado y evidencia. |
| [planning/04-plan-maestro.md](planning/04-plan-maestro.md) | Fases, prioridades, dependencias y criterios de aceptación. |
| [planning/05-backlog-ejecucion.md](planning/05-backlog-ejecucion.md) | Tareas de ejecución con todos sus campos. |
| [planning/06-registro-conflictos.md](planning/06-registro-conflictos.md) | Conflictos detectados y decisiones requeridas. |
| [planning/07-matriz-trazabilidad.md](planning/07-matriz-trazabilidad.md) | Matriz requisito ↔ fuente ↔ tarea ↔ código ↔ prueba. |

### 6. Documentación de código (skill `code-documentation`, 2026-10-17)

| Documento | Contenido |
| --- | --- |
| [../CHANGELOG.md](../CHANGELOG.md) | Historial de cambios por fecha y commit (Keep a Changelog). |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Guía para contribuir: entorno, pruebas, convenciones y flujo de trabajo. |
| [../backend/README.md](../backend/README.md) | Módulo backend: responsabilidades, endpoints, variables y pruebas. |
| [../frontend/README.md](../frontend/README.md) | Módulo app Flutter: flujo, ejecución USB/WiFi y notas de Android. |
| [../jetson/README.md](../jetson/README.md) | Módulo Jetson: archivos desplegables, despliegue y pruebas sin hardware. |

## Resumen ejecutivo del sistema

BoviSense-AI es un sistema de conteo de bovinos con cuatro piezas desplegables
independientes:

```text
App Flutter (Android)  --HTTP/JSON-->  Backend Node.js (Express)
        |                                      |
        | BLE                                  | Firebase Admin
        v                                      v
  ESP32 (puente BLE<->LoRa)            Firebase Auth + Firestore
        | LoRa 433 MHz
        v
  Jetson Orin Nano (receptor + detector TensorRT)
```

El conteo se autoriza con tramas firmadas **C1/R1** (HMAC-SHA256) emitidas por el
backend y verificadas por la Jetson; la app solo muestra un resultado después de
que el backend valide la firma. Detalle en
[arquitectura/integraciones-iot.md](arquitectura/integraciones-iot.md).

## Estado de verificación

| Aspecto | Estado |
| --- | --- |
| Análisis estático y pruebas automatizadas | Ejecutables y en verde (ver [codebase/TESTING.md](codebase/TESTING.md)). |
| Validación de campo (cámara, radio, altitud, batería) | PENDIENTE DE VERIFICACIÓN: requiere hardware. |
| Despliegue en Vercel | Configuración detectada (`backend/vercel.json`, `backend/api/index.js`); PENDIENTE DE VERIFICACIÓN si el despliegue está activo. |
| Reglas de Firestore | Configuración detectada (`firestore.rules`); no hay evidencia de despliegue a producción. |
| Firmware del ESP32 grabado en el prototipo | PENDIENTE DE VERIFICACIÓN: no puede comprobarse desde el repositorio. |
