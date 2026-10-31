# Instrucciones y Contexto para Agentes de BoviSense-AI

Esta carpeta centraliza los documentos históricos de contexto, bitácoras de traspaso, especificaciones de experiencia de usuario y guías de auditoría del proyecto BoviSense-AI.

## Contenido de la carpeta

| Archivo | Tipo / Propósito | Descripción |
|---|---|---|
| [`AGENTS.md`](./AGENTS.md) | Bitácora técnica y de traspaso | Historial técnico acumulativo del proyecto, arquitectura de hardware (Jetson Xavier NX/SX1278, ESP32 BLE/LoRa), protocolo de tramas firmadas (`C1`/`R1`), incidentes resueltos y checklist de QA local. |
| [`pasos.txt`](./pasos.txt) | Especificaciones de UX / Producto | Pautas de diseño para usuarios no técnicos (ganaderos), requerimientos del flujo de conteo y notas operativas. |
| [`revicion.txt`](./revicion.txt) | Marco de auditoría (25 fases) | Guía detallada para auditoría de código, seguridad (OWASP Mobile), testing, arquitectura, SRE y observabilidad. |
| [`.codex`](./.codex) | Contexto histórico IoT | Notas y registros de las primeras fases de integración del módulo de comunicación y hardware IoT. |

---
*Nota: Estos documentos se mantienen organizados aquí para evitar la dispersión de archivos en la raíz del repositorio y servir como referencia para futuras sesiones de desarrollo y auditoría.*
