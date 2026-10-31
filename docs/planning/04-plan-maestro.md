# 04 — Plan maestro

Fase 5 de la skill. Organiza el trabajo en fases con prioridad, dependencias y
criterios de aceptación **verificables**. Ninguna fase se ejecuta sin
aprobación explícita (Fase 6 de la skill, sección *Control*).

## 1. Criterios de prioridad

| Prioridad | Criterio |
|-----------|----------|
| P0 (crítica) | Afecta a la seguridad del sistema o a la validez del conteo |
| P1 (alta) | Bloquea la entrega académica o la publicación |
| P2 (media) | Reduce riesgo operativo o deuda técnica |
| P3 (baja) | Mejora de calidad o de experiencia, no bloqueante |

## 2. Fases

### F0 — Consolidación y aprobación (P0, esta entrega)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Centralizar la planificación y obtener autorización para ejecutar |
| Requisitos cubiertos | R-X-01, R-X-02, R-X-05, R-X-09 |
| Entregable | `docs/planning/01..07` + índice |
| Dependencias | Ninguna |
| Criterios de aceptación | Los siete documentos existen con las secciones requeridas; toda afirmación tiene evidencia; el usuario aprueba el plan |
| Estado | **PENDIENTE_APROBACION** |

### F1 — Cerrar el acceso no autenticado al receptor (P0, crítico)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Que la Jetson ejecute comandos **solo** con tramas C1 firmadas |
| Problema | `jetson/lora_jetson_rx.py:1398-1459` acepta tramas sin `C1\|` (`BRIDGE`, `ESTADO`, `INICIARCONTEO`, …) y responde `RESP\|...\|JETSON_COUNT\|...` sin HMAC |
| Requisitos cubiertos | R-IOT-06, R-IOT-02, S1 Fase 5 |
| Dependencias | Decisión del usuario sobre el conflicto `C-01` |
| Opciones | (a) eliminar el camino heredado; (b) mantenerlo tras una bandera desactivada por defecto; (c) autenticarlo con C1 |
| Criterios de aceptación | Una trama sin firma no provoca ninguna acción de conteo; `python3 -m unittest test_secure_protocol.py` sigue en verde; se añade un caso que pruebe que una trama heredada se rechaza |
| Pruebas necesarias | Caso nuevo en `jetson/test_secure_protocol.py` que envíe una trama `INICIARCONTEO` sin firma y verifique que no se ejecuta |
| Riesgo de no hacerlo | Cualquier emisor LoRa con el formato correcto podría iniciar o detener conteos sin autenticación |

### F2 — Higiene de secretos y credenciales (P0/P1)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Eliminar credenciales expuestas y decidir el tratamiento de los archivos de configuración versionados |
| Alcance | (1) credenciales en claro en `pasos.txt:223-224` y contraseña de hotspot en `.codex:17` (archivos locales ignorados por Git); (2) dos `google-services.json` versionados (`git ls-files`) |
| Requisitos cubiertos | R-X-03, S1 Fase 10, `C-04` |
| Dependencias | Acción del usuario en GitHub, proveedor de LLM y hotspot |
| Criterios de aceptación | Credenciales rotadas; en el repositorio no queda ningún archivo con secretos operativos (más allá de la configuración pública de cliente de Firebase, si se decide conservarla); `.gitignore` coherente con lo versionado |
| Pruebas necesarias | `git ls-files` + `git check-ignore -v` sobre cada archivo sensible |
| Riesgo de no hacerlo | Uso indebido de credenciales activas; hallazgo crítico en la evaluación de seguridad del proyecto de grado |

### F3 — Preparar la publicación Android (P1)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Dejar el proyecto Android publicable |
| Alcance | `applicationId` definitivo, keystore y firma de release, comprobación de `usesCleartextTraffic=false` |
| Requisitos cubiertos | R-FLUTTER-13 |
| Dependencias | Decisión del usuario sobre el identificador de paquete; si cambia, actualizar `google-services.json` y el registro en Firebase |
| Criterios de aceptación | `flutter build apk --release --dart-define=API_BASE_URL=https://<host>` produce un artefacto firmado con el `applicationId` acordado y sin tráfico en claro |
| Pruebas necesarias | Build de release + verificación del manifiesto fusionado |
| Riesgo de no hacerlo | No se puede distribuir ni evaluar la app fuera del entorno de depuración |

### F4 — Validación funcional en hardware (P1, bloqueada)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Confirmar el flujo completo en el equipo real |
| Alcance | Cámara CSI y detector, sesión `H→S→Q→T→R`, guardado, alertas, cuatro escenarios de Bluetooth, reconexión, latencias |
| Requisitos cubiertos | R-JETSON-10, R-IOT-07, R-X-07, `AGENTS.md` §21 |
| Dependencias | Acceso físico a Jetson, ESP32, cámara y teléfono; servicio desplegado con los archivos actuales |
| Criterios de aceptación | Registro con fecha y versión de cada archivo desplegado; sesión real completada con conteo guardado en el historial; latencias medidas por tramo |
| Pruebas necesarias | Checklist de `AGENTS.md` §21; trazas correlacionadas por `request_id` |
| Riesgo de no hacerlo | El proyecto no puede declararse validado en campo ni habilitarse el despliegue |

### F5 — Validación del tracking con video real (P2, bloqueada)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Confirmar que el tracking mantiene identidades y no sobreconta |
| Alcance | `--tracker botsort` vs `bytetrack` vs `ocsort` vs `none` sobre el mismo video |
| Requisitos cubiertos | R-JETSON-02, R-JETSON-05, R-JETSON-08, R-JETSON-12 |
| Dependencias | Instalación de `trackers`/`supervision` en el venv, video aéreo de prueba |
| Criterios de aceptación | Tabla comparativa de `TRACK_FINAL` por motor (conteo, tracks creados, recuperados, rechazos por duplicado); conclusión documentada |
| Pruebas necesarias | Ejecución de los cuatro motores con el mismo `--source` y `--no-display` |
| Riesgo de no hacerlo | La elección de tracker no estaría respaldada por datos propios |

### F6 — Cerrar brechas de cobertura de pruebas (P2)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Cubrir con pruebas lo que hoy solo está verificado a mano |
| Alcance | Contador de identidad del worker (R-JETSON-05), publicación de hooks (R-JETSON-08), compatibilidad heredada del backend (R-NODE-09), trazas y límites (R-NODE-10/11), rechazo de tramas sin firma (F1) |
| Dependencias | F1 para el caso del protocolo |
| Criterios de aceptación | Nuevas pruebas en verde y documentadas en `docs/codebase/TESTING.md` |
| Pruebas necesarias | `backend npm test`, `flutter test`, `python3 -m unittest` |
| Riesgo de no hacerlo | Regresiones silenciosas en las rutas de conteo |

### F7 — CI/CD y documentación viva (P3)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Que las pruebas se ejecuten automáticamente y la documentación no se degrade |
| Alcance | Workflow que corra `npm test`, `flutter analyze/test` y `py_compile`; referencia obligatoria a `docs/` en cada cambio |
| Requisitos cubiertos | R-X-08, R-X-05 |
| Dependencias | Ninguna |
| Criterios de aceptación | Un push a `dev` ejecuta las tres suites y falla si alguna cae |
| Riesgo de no hacerlo | Regresiones que llegan a `main` sin detección |

### F8 — Decisiones de producto pendientes (P3)

| Aspecto | Detalle |
|---------|---------|
| Objetivo | Resolver las preguntas `[ASK USER]` que no dependen del código |
| Alcance | Modo sin conexión, notificaciones push, migración de colecciones heredadas, duración de sesión, mosaicos de detección, versión del firmware |
| Requisitos cubiertos | R-FLUTTER-12, R-JETSON-11, R-JETSON-12, R-NODE-09 |
| Dependencias | Respuestas del usuario |
| Criterios de aceptación | Cada pregunta resuelta se convierte en requisito aprobado o se descarta explícitamente |
| Riesgo de no hacerlo | Trabajo sin prioridad clara y decisiones tomadas por defecto |

## 3. Orden recomendado y dependencias

```text
F0 (aprobacion)
  |
  +--> F1 (protocolo)  -----> F6 (pruebas, parcial)
  +--> F2 (secretos)
  +--> F3 (publicacion)
  +--> F4 (hardware) ---------> habilita despliegue
  |        |
  |        +--> F5 (tracking con video)
  +--> F7 (CI/CD)
  +--> F8 (decisiones de producto)
```

F1 y F2 son las únicas fases con riesgo crítico y **no requieren hardware**; se
pueden ejecutar de inmediato una vez aprobadas. F4 y F5 son las que consumen más
tiempo y dependen del equipo físico.

## 4. Fuera de alcance de este plan

- No se planifica despliegue a producción ni hospedaje (R-X-07 vigente).
- No se planifica reentrenar el modelo de detección ni cambiar el engine.
- No se planifica reemplazar el detector ni el protocolo.
- Las recomendaciones marcadas como `PROPUESTA` en el catálogo no forman parte de
  las fases hasta que se aprueben.

## 5. Evidencia

- Requisitos y estados: `03-catalogo-requisitos.md`.
- Hallazgos que originan F1, F2 y F6: `06-registro-conflictos.md`.
- Trazabilidad requisito ↔ tarea ↔ código ↔ prueba: `07-matriz-trazabilidad.md`.
