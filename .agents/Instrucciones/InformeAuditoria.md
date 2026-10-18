Auditoría técnica de BoviSense-AI
Fecha: 17 de octubre de 2026
Modalidad: solo lectura
Referencia: rama dev, commit b94fcda9a67d9e45419fe98d588f987aa861c298
No se modificaron archivos, configuraciones, bases de datos ni dependencias. No se iniciaron servicios ni se interactuó con hardware.
1. Resumen ejecutivo
BoviSense-AI dispone de una implementación sustancial de aplicación móvil, backend, comunicación BLE/LoRa y procesamiento en Jetson. No es únicamente una maqueta: existen controles de autorización, transacciones, protocolo autenticado, manejo de procesos y pruebas automatizadas.
Sin embargo, el repositorio no permite acreditar un conteo bovino confiable de extremo a extremo ni una recuperación consistente ante interrupciones.
Los problemas más importantes encontrados son:
1. Una respuesta IDLE previamente verificada puede volver a procesarse y liberar la reserva de otra sesión, incluso de otro usuario. Reproducido con el servicio real y una base de datos simulada en memoria.
2. Consultar ESTADO después de terminar un conteo puede producir una respuesta que el backend rechaza. El receptor informa un estado terminal, pero el comando de consulta no lleva sesión.
3. La persistencia de resultados en SQLite no está integrada con el controlador. Existen métodos para guardar y recuperar resultados, pero no se invocan en el flujo operativo.
4. Un proceso terminado forzosamente puede entregar su último acumulado como resultado final válido. Reproducido sin ejecutar procesos reales.
5. La pérdida de cámara después de abrirla no provoca necesariamente un error terminal. Puede mantenerse un conteo aparentemente activo sin recibir imágenes.
6. La paginación pierde registros cuando un grupo suficientemente grande comparte la misma fecha. En una comprobación con 35 registros, se devolvieron 31 y los cuatro restantes quedaron inaccesibles.
7. El conteo identifica trayectorias, no garantiza individuos únicos. La reaparición después de perder una identidad puede incrementar nuevamente el acumulado.
8. No están disponibles los artefactos y resultados experimentales necesarios para validar el modelo, su entrenamiento y su precisión real.
Fortalezas verificadas:
- Firebase ID tokens verificados con comprobación de revocación.
- Roles y estado del usuario consultados en backend.
- Reglas Firestore restrictivas.
- HMAC en comandos y respuestas.
- Rechazo de comandos LoRa heredados sin firma.
- Protección persistente contra repetición de solicitudes en Jetson.
- Guardado transaccional e idempotente de conteos y alertas.
- Exclusión mutua para el acceso SPI.
- Liberación explícita de numerosos recursos Flutter, HTTP, SMTP y CUDA.
- Suites de pruebas y configuración CI existentes.
Conclusión ejecutiva: base adecuada para continuar un proyecto de grado; preparación todavía condicionada para una demostración completa y no acreditada para operación real autónoma.
2. Alcance y metodología
Estado de Git
- Directorio real: /home/spartano/Documentos/BoviSense-AI.
- Nombre visible del producto: BoviSense.
- Rama activa: dev.
- HEAD: b94fcda9a67d9e45419fe98d588f987aa861c298.
- Último commit: 12 de octubre de 2026.
- Comparación main...dev: cinco commits exclusivos de main y uno exclusivo de dev; las ramas están divergidas.
- La comparación con dev corresponde al árbol de trabajo frente a su propia referencia, sin cambiar de rama.
Cambios locales preexistentes:
- Traslado de AGENTS.md a .agents/Instrucciones/AGENTS.md.
- Modificaciones en .gitignore, README.md y docs/README.md.
- Archivos no seguidos en instrucciones, habilidades y jetson/tracking.md.
El estado Git observado al terminar coincide con el inicial.
Cobertura de inspección
Se inventariaron recursivamente los subsistemas principales. Se revisaron con mayor profundidad:
- Backend completo de rutas, controladores, autenticación, servicios y validación.
- Servicio BLE, cliente HTTP, repositorios y modelos de estado Flutter.
- Inicio de aplicación, autenticación, navegación, conteo, historial y administración.
- Receptor LoRa y protocolo seguro Python.
- Captura, TensorRT, tracking, conteo y exportación.
- Firmware ESP32.
- Reglas Firebase, manifiestos, dependencias, CI y documentación operativa.
- Pruebas existentes y parte del historial Git.
La revisión de widgets puramente visuales, proyectos nativos generados y documentación histórica fue selectiva. No se efectuó una inspección línea por línea de dependencias, binarios o archivos generados.
Verificaciones realizadas
Verificación	Resultado y alcance
git status, branch, rev-parse, log, diff, rev-list, ls-files	Identificación y comparación de solo lectura
rg, find, sed, nl, wc, lectura de manifiestos	Inventario y trazabilidad
node --check sobre fuentes backend/API	Sin errores de sintaxis reportados
node --test backend/test/security.test.js	El ejecutor reportó éxito del archivo, sin fallos
Análisis AST Python mediante python3 -B	Nueve archivos analizados, sin importar módulos del proyecto
Reejecución aislada de lógica con dobles en memoria	Reprodujo replay de IDLE, rechazo de H terminal, paginación incompleta y finalización forzada aceptada
Clase de tracking extraída mediante AST	Reaparición tras eliminación produjo una segunda identidad
Búsqueda limitada de patrones de secretos en archivos seguidos	Sin coincidencias de los patrones examinados; no certifica ausencia de secretos
Consulta de documentación oficial	Contraste de TTL Firestore y API Bluetooth Android


Los experimentos aislados no son pruebas E2E. No utilizaron Firebase real, emuladores, SQLite en disco, radio, cámara ni CUDA.
Pruebas omitidas
PENDIENTES DE VERIFICACIÓN:
- Flutter analyze/test/build: pueden generar cachés y artefactos.
- Suite completa Python: contiene creación y eliminación de directorios temporales.
- Integración backend: inicia servidor y modifica emuladores.
- Compilación ESP32.
- Arranque de servicios, pruebas de carga, firmware y hardware.
- Auditoría completa de vulnerabilidades transitivas contra una base de avisos actualizada.
- Inspección de configuración desplegada, reglas activas y políticas TTL.
- Revisión exhaustiva de secretos en todo el historial Git.
Convenciones de evidencia
- CONFIRMADO: demostrado en código o reproducido con lógica aislada.
- PROBABLE: existe una ruta causal sustentada, pero depende de condiciones no reproducidas.
- PENDIENTE DE VALIDACIÓN: faltan artefactos, configuración o pruebas físicas.
La severidad representa impacto técnico; la prioridad representa orden de intervención. No se asignan puntuaciones CVSS sin un escenario suficientemente caracterizado.
3. Inventario y arquitectura real
Referencias de archivos
Los siguientes identificadores se utilizan en las tablas y hallazgos. Las líneas indicadas posteriormente pertenecen a estos archivos:
| Ref. | Archivo |
|---|---|
| B1 | [backend/src/services/iotService.js](/home/spartano/Documentos/BoviSense-AI/backend/src/services/iotService.js:1) |
| B2 | [backend/src/controllers/ganaderoController.js](/home/spartano/Documentos/BoviSense-AI/backend/src/controllers/ganaderoController.js:1) |
| B3 | [backend/src/services/userService.js](/home/spartano/Documentos/BoviSense-AI/backend/src/services/userService.js:1) |
| B4 | [backend/src/middlewares/authMiddleware.js](/home/spartano/Documentos/BoviSense-AI/backend/src/middlewares/authMiddleware.js:1) |
| B5 | [backend/src/app.js](/home/spartano/Documentos/BoviSense-AI/backend/src/app.js:1) |
| B6 | [backend/src/services/iotProtocol.js](/home/spartano/Documentos/BoviSense-AI/backend/src/services/iotProtocol.js:1) |
| J1 | [jetson/lora_jetson_rx.py](/home/spartano/Documentos/BoviSense-AI/jetson/lora_jetson_rx.py:1) |
| J2 | [jetson/secure_protocol.py](/home/spartano/Documentos/BoviSense-AI/jetson/secure_protocol.py:1) |
| J3 | [jetson/run_bovino.py](/home/spartano/Documentos/BoviSense-AI/jetson/run_bovino.py:1) |
| F1 | [frontend/lib/data/services/esp32_ble_bridge_service.dart](/home/spartano/Documentos/BoviSense-AI/frontend/lib/data/services/esp32_ble_bridge_service.dart:1) |
| F2 | [frontend/lib/core/utils/command_queue.dart](/home/spartano/Documentos/BoviSense-AI/frontend/lib/core/utils/command_queue.dart:1) |
| F3 | [frontend/lib/data/repositories/ganadero_repository.dart](/home/spartano/Documentos/BoviSense-AI/frontend/lib/data/repositories/ganadero_repository.dart:1) |
| F4 | [frontend/lib/data/services/api_client.dart](/home/spartano/Documentos/BoviSense-AI/frontend/lib/data/services/api_client.dart:1) |
| F5 | [frontend/lib/main.dart](/home/spartano/Documentos/BoviSense-AI/frontend/lib/main.dart:1) |
| F6 | [frontend/lib/viewmodels/auth_view_model.dart](/home/spartano/Documentos/BoviSense-AI/frontend/lib/viewmodels/auth_view_model.dart:1) |
| F7 | [frontend/lib/views/ganadero/estado_dispositivo_page.dart](/home/spartano/Documentos/BoviSense-AI/frontend/lib/views/ganadero/estado_dispositivo_page.dart:1) |
| E1 | [Firmware ESP32](/home/spartano/Documentos/BoviSense-AI/comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino:1) |
| A1 | [MainActivity.kt](/home/spartano/Documentos/BoviSense-AI/frontend/android/app/src/main/kotlin/com/example/frontend/MainActivity.kt:1) |
| C1 | [build.gradle.kts](/home/spartano/Documentos/BoviSense-AI/frontend/android/app/build.gradle.kts:1) |


| Subsistema | Implementación real | Dependencias críticas |
|---|---|---|
| Aplicación | Flutter/Dart, Provider, repositorios y servicios | Firebase Auth/Firestore, HTTP, FlutterBluePlus, permisos |
| Backend | Node.js CommonJS, Express | Firebase Admin, Firestore, SMTP |
| Puente terrestre | ESP32 Arduino BLE/LoRa | BLE Arduino, biblioteca LoRa, FreeRTOS |
| Receptor Jetson | Python, acceso SX1278 por SPI | `spidev`, SQLite, filesystem, reloj |
| Worker IA | Python, captura e inferencia en hilos | OpenCV/GStreamer, TensorRT, CUDA, NumPy |
| Tracking | BoT-SORT/ByteTrack/OCSORT opcionales; fallback interno | `trackers`, `supervision`, ORB |
| Persistencia | Firestore más estado local parcial | Colecciones de usuario, tickets, sesiones, SQLite |
| Despliegue | Express local, adaptador Vercel, referencia systemd | Credenciales y configuración externas |
| CI | GitHub Actions | Node 22, Flutter estable, Python 3.10, emuladores |


Versiones resueltas destacadas del lockfile backend:
- Express 5.2.1.
- Firebase Admin 14.4.0.
- Nodemailer 10.0.10.
- Express Rate Limit 8.7.0.
- Helmet 8.3.0.
- Firestore Node 9.2.0.
- Google Auth Library 10.6.2.
- JSON Web Token 9.0.3.
- ProtobufJS 7.6.6.
El lockfile contiene 260 entradas de paquetes. Estas versiones fueron inventariadas, no certificadas como libres de vulnerabilidades.
El lockfile Flutter exige Dart >=3.10.4 y Flutter >=3.38.0, distinto del requisito impreciso “Flutter SDK 3.10+” del README.
Comunicación implementada
Flutter ── Firebase Auth ── autenticación
   │
   ├── Firestore ── lectura del perfil propio
   │
   ├── HTTP(S) ── Express ── Firebase Admin ── Firestore
   │                 │
   │                 ├── firma C1
   │                 ├── verifica R1
   │                 └── guarda sesiones, conteos y alertas
   │
   └── BLE ── ESP32 ── LoRa ── receptor Jetson
                                  │
                                  ├── SQLite: solicitudes antirreplay
                                  └── subprocess: run_bovino.py
                                          │
                                          ├── cámara/GStreamer
                                          ├── TensorRT/CUDA
                                          └── tracking → acumulado
El backend no transmite directamente al dispositivo. Flutter transporta las tramas firmadas y devuelve las respuestas al backend.
Interfaces
- BLE: servicio y características UUID coincidentes entre firmware y app.
- BLE framing: ~<trama>\n, fragmentos de 18 bytes.
- LoRa: tramas ASCII completas.
- Comandos: H, P, S, T, Q, R.
- Autenticación: HMAC-SHA256 truncado a 128 bits.
- Backend: tickets de 60 segundos; reserva inicial del dispositivo de 900 segundos.
- Worker: archivos JSON y líneas WORKER_STATUS, COUNT_UPDATE, COUNT_FINAL.
- Sesión: identificador hexadecimal de 128 bits.
Diferencias respecto al contexto preliminar
- El modelo no puede identificarse como MobileNet SSD reentrenado únicamente por este repositorio: se carga un motor externo.
- Hay varias opciones de tracking, además de un fallback interno.
- El ESP32 no autentica criptográficamente las órdenes: transporta mensajes cuya autenticidad validan los extremos.
- La operación depende de conectividad con backend/Firebase incluso para solicitar una detención normal.
- No se identificó control de vuelo, autopiloto, navegación aérea o integración MAVLink.
- El protocolo JSON de comunicacion-iot/shared/ es alternativo/histórico y no es el protocolo operativo C1/R1.
- usuarioRoute.js duplica rutas administrativas, pero el montaje vigente utiliza usuarioRoutes.js.
Puntos únicos de fallo
Backend, Firebase, teléfono, enlace BLE, puente ESP32, enlace LoRa, receptor Jetson, cámara, motor TensorRT y clave compartida son dependencias seriales del flujo completo.
El timeout local de 600 segundos limita algunas sesiones abandonadas, pero depende de que el controlador siga ejecutándose.
4. Estado funcional
“Parcialmente funcional” significa que existe un recorrido implementado, pero no se acreditó su funcionamiento desplegado completo.
| Función | Estado | Fundamento |
|---|---|---|
| Login y recuperación de contraseña | Parcialmente funcional | Integración Firebase implementada; servicios no probados |
| Autorización backend | Implementada; validación desplegada pendiente | Token, revocación, perfil, rol y estado |
| Administración de usuarios | Parcialmente funcional | Operaciones durables; riesgos de recuperación |
| Configuración de finca | Parcialmente funcional | Escritura vigente; lectura legacy inconsistente con inicio |
| Descubrimiento y conexión BLE | No verificable físicamente | Código y UUID coherentes |
| Consulta del prototipo | Defectuosa en estados terminales | BOV-HIGH-002 |
| Inicio y detención | Parcialmente funcional | Control implementado; finalización forzada ambigua |
| Captura e inferencia | No verificable físicamente | Motor externo y cámara no disponibles |
| Seguimiento | Implementado con limitaciones | Fallback y memoria temporal |
| Conteo único confiable | No demostrado | Fragmentación y reidentificación heurística |
| Resultado tras reiniciar receptor | Defectuoso | Persistencia no integrada |
| Guardado de conteo | Parcialmente funcional | Transacción e idempotencia; acepta finales degradados |
| Historial y alertas | Defectuoso en casos límite | Paginación y mezcla legacy |
| Telemetría de batería/GPS/temperatura | No implementada en el contrato C1/R1 actual | Modelos contienen campos, pero la respuesta no los transporta |
| Control de vuelo | No identificado en el repositorio | No implica que no exista fuera de él |
| Recuperación offline | No implementada integralmente | Sin bandeja persistente de sesiones/resultados en app |
| Publicación Android | Pendiente | Firma debug en release |
| Operación sostenida | No verificable | Sin ensayo de estabilidad actual |


5. Secuencia operativa
Recorrido y responsabilidades
| Paso | Responsable y evento | Entradas, salidas, validaciones y fallos |
|---|---|---|
| 1. Abrir aplicación | F5 `main`, línea 21 | Inicializa Firebase y cliente API; error lleva a pantalla de arranque fallido |
| 2. Autenticar | `auth_repository.dart`, línea 22 | Credenciales a Firebase; carga perfil desde servidor; cierra sesión si falla |
| 3. Resolver rol | B4 línea 57; `auth_gate.dart`, línea 25 | UI decide pantalla; backend vuelve a validar rol y estado |
| 4. Conectar BLE | F1 `scanAndConnect`, línea 366 | Permisos, adaptador, scan 12/13 s, conexión 12 s, servicios 10 s |
| 5. Comprobar equipo | F7 línea 95; F1 línea 729 | Solicita ticket `H`; recibir respuesta no acredita cámara/modelo listos |
| 6. Iniciar | B1 `issue`, línea 11 | Configuración, propietario y reserva; crea sesión `PENDING` y ticket |
| 7. Recibir en ESP32 | E1 `onWrite`, línea 354 | Delimita ASCII, buffer 180 bytes, cola de cuatro entradas |
| 8. Transmitir LoRa | E1 línea 244 | Solo una respuesta pendiente; espera 22 s; devuelve errores B0 |
| 9. Validar en Jetson | J2 `handle`, línea 73 | Firma, expiración, identificadores y antirreplay SQLite |
| 10. Crear worker | J1 `start`, línea 602 | Verifica rutas, abre log, crea grupo de procesos y archivos por sesión |
| 11. Capturar | J3 `capture_worker`, línea 2006 | Abre fuente; falla inicial detiene; fallos posteriores pueden repetir indefinidamente |
| 12. Preprocesar | J3 `preprocess`, línea 515 | Resize, BGR→RGB, float32, NHWC |
| 13. Inferir | J3 `infer`, línea 526 | Copias CUDA, ejecución TensorRT y sincronización |
| 14. Decodificar | J3 línea 595 | Busca cuatro salidas, filtra confianza y transforma coordenadas |
| 15. Seguir y contar | J3 líneas 1333 y 1835 | Asociación, confirmación, identidad y acumulador |
| 16. Obtener resultado | J3 línea 130; J1 línea 905 | JSON/log final; no siempre diferencia resultado completo de interrupción |
| 17. Responder | J2 línea 50; J1 línea 1267 | Firma R1; dos transmisiones; TxDone no confirma recepción |
| 18. Recibir en app | F1 línea 674 | Reensambla y correlaciona `request_id`; verificación criptográfica posterior |
| 19. Actualizar UI | F1 línea 785 | Solo tras backend; polling nominal de 4 s mientras figura activo |
| 20. Guardar | B2 línea 329 | Revalida prueba; transacción crea conteo y alerta usando ID de sesión |
| 21. Consultar historial | B2 línea 371 | Mezcla colecciones actuales/legacy; cursor defectuoso en empates |
| 22. Finalizar | J1 línea 686 | SIGTERM, espera 8 s, SIGKILL y espera adicional de 3 s |
| 23. Liberar | J3 línea 2425; J1 línea 1551; F1 línea 896 | Limpieza prevista, con huecos ante señales, hilos bloqueados y excepciones |


Condiciones transversales
- Éxito de transporte no equivale a éxito de conteo: STARTED confirma lanzamiento del proceso, no un primer frame inferido.
- Éxito criptográfico no equivale a resultado completo: la firma autentica lo que afirma el receptor.
- Timeout HTTP: 30 segundos por petición.
- Timeout BLE: 25 segundos.
- Polling: 4 segundos nominales; espera creciente tras errores.
- Reintentos: hay repetición de respuesta LoRa y consultas posteriores; no un protocolo completo de entrega confirmada.
- Recursos: cada propietario debe liberar lo que crea; el siguiente apartado detalla las excepciones.
6. Informe de seguridad
Controles favorables
La autorización no depende únicamente de las pantallas:
- verifyIdToken(idToken, true) comprueba revocación.
- Se exige perfil existente, activo y sin operación pendiente.
- Las rutas administrativas exigen administrador.
- Las rutas ganaderas exigen usuario o ganadero.
- Los recursos actuales se ubican bajo el UID autenticado.
- Las lecturas legacy individuales verifican propietario.
- Las reglas Firestore niegan enumeración y escrituras directas.
- El registro de conteos no acepta una cantidad arbitraria enviada por Flutter.
- El backend limita cuerpos a 16 KB y utiliza Helmet, CORS configurable y rate limiting.
- El cliente HTTP impide redirecciones y destinos de otro origen.
- SMTP exige TLS.
- El subprocess se ejecuta con argumentos, sin shell.
- El receptor descarta comandos no autenticados.
Riesgos principales
| Superficie | Evaluación |
|---|---|
| Autorización por sesión | Vulnerabilidad confirmada al aplicar respuestas `IDLE` antiguas a reservas nuevas |
| Repetición | Jetson protege solicitudes; backend no hace idempotentes todos los efectos de verificar respuestas |
| BLE | Sin autenticación de enlace configurada; susceptible a ocupación/suplantación del puente y denegación |
| LoRa | Autenticidad de extremos, pero no cifrado; observación e interferencia siguen siendo posibles |
| Respuestas falsas | No permiten guardar resultados sin firma; pueden consumir la respuesta pendiente antes de validarla |
| HTTP local | Aceptado para direcciones privadas; Android debug/profile permite texto claro |
| Sesiones móviles | La revocación backend no invalida automáticamente toda la UI local |
| Secretos | No se detectaron patrones examinados; rotaciones históricas no verificadas |
| Dependencias | Versiones inventariadas; vulnerabilidades actuales pendientes |
| Despliegue | Reglas, TLS, TTL, secretos y versión instalada no comprobados |


No se confirmó una vulnerabilidad crítica que permita ejecutar órdenes físicas arbitrarias sin firma en el código actual.
Correspondencias CWE orientativas:
- BOV-HIGH-001: CWE-863, autorización incorrecta.
- BOV-MED-003: CWE-362, condición de carrera lógica.
- BOV-MED-005: CWE-400, consumo no acotado.
- BOV-MED-006: CWE-306 en acceso al transporte, sin afirmar ausencia de autenticación de las órdenes finales.
No se asigna CVSS numérico.
7. Informe de concurrencia y recursos
Ciclo de vida
| Recurso | Creación/propietario | Liberación prevista | Observación |
|---|---|---|---|
| HTTP Flutter | F4 constructor; app | `ApiClient.close`, F5 `dispose` | Timeout abortable y límite de respuesta |
| Scan BLE | F1 `scanAndConnect` | `_release`, cancelación y `stopScan` | Limpieza explícita |
| Suscripciones BLE | F1 líneas 476, 484, 638 | `_release` y `dispose` | Existen defensas contra callbacks tardíos |
| Timer de polling | F1 línea 316 | Pausa, desconexión y dispose | Pausar no cancela una orden ya en vuelo |
| Cola de comandos | F2 línea 18 | Finalización de cada tarea | Sin límite, invalidación o identidad capturada al encolar |
| Controladores de formularios | Vistas Flutter | `dispose` | Se observaron cierres y eliminación de listeners |
| HTTP Node | B5 línea 73 | `server.close` y límite de 10 s | No se verificó despliegue |
| SMTP | `mailService.js`, línea 7 | `finally`, línea 27 | Timeouts definidos |
| SPI y lock | J1 líneas 250 y 278 | `close`, línea 552 | Lock cooperativo, no protege contra programas externos |
| SQLite | J2 línea 66 | `close`, línea 106 | Solicitudes persistentes; resultados no integrados |
| Worker | J1 línea 664 | SIGTERM/SIGKILL y `wait` | Grupo propio; dependencia del ciclo de vida del receptor |
| Log worker | J1 línea 645 | `close_log_file` | Append sin rotación en el código |
| Cámara | J3 línea 2025 | `finally`, línea 2170 | Apertura y algunas salidas están fuera de la protección completa |
| Stream/buffers CUDA | J3 líneas 429 y 500 | `close`, línea 569 | Construcción parcialmente fallida no dispone de rollback completo |
| Hilos | J3 líneas 2649 y 2671 | Event y `join` | `join` limitado no comprueba que hayan terminado |
| Colas de frames | J3 línea 2635 | Vida del worker | Tamaño 2 en vivo; ilimitada en modo exhaustivo |
| Exportador | J3 línea 758 | `close`, línea 848 | Error al cerrar puede impedir limpieza posterior en el mismo `finally` |

Diagnóstico
No hay evidencia de un deadlock demostrado ni de una fuga medida de memoria GPU.
Sí hay rutas concretas de riesgo:
- Hilo de captura muerto mientras el hilo principal sigue esperando.
- Lectura de cámara bloqueada o sin frames sin watchdog de progreso.
- Resultado emitido antes de confirmar terminación de todos los hilos.
- Terminación del receptor por SIGTERM sin manejador propio.
- Tareas pendientes ejecutadas después de una reconexión.
- JSON de estado escrito sin reemplazo atómico y desde distintos hilos.
- Cola exhaustiva y archivos operativos sin límites de crecimiento.
La recuperación automática es, por tanto, parcial.
8. Informe de hardware y comunicaciones
Coherencia verificable
| Parámetro | Jetson | ESP32 | Evaluación |
|---|---|---|---|
| Frecuencia | 433 MHz | 433 MHz | Coincide |
| SF | 7 | 7 | Coincide |
| Ancho de banda | 125 kHz | 125 kHz | Coincide |
| Coding rate | 4/5 | 4/5 | Coincide |
| Sync word | `0xF3` | `0xF3` | Coincide |
| CRC | Activado por defecto | Activado | Coincide |
| BLE UUID | App | Firmware | Coinciden |
| C1 máximo | 180 caracteres | 180 caracteres | Compatible |
| R1 máximo backend/app | 200 caracteres | 200 caracteres | Compatible |


Jetson:
- SPI0 CS0, velocidad configurada de 10 kHz.
- RST documentado a 3,3 V fijo.
- DIO0 declarado en pin físico 31, pero no utilizado por el receptor.
- Polling de IRQ por SPI.
- Verificación de registros y recuperación de RX tras TX.
ESP32:
- NSS 5, RST 14, DIO0 4.
- Inicialización LoRa diferida y reintentos si no inicia.
- CPU configurada a 80 MHz.
- Cola FreeRTOS limitada a cuatro comandos.
- Brownout desactivado explícitamente.
Limitaciones
- No se comprobó cableado, tensión, corriente, antena, distancia ni calidad RF.
- No se comprobó que el firmware instalado coincida con E1.
- No existe confirmación criptográfica de recepción de R1 por la app hacia la Jetson.
- La repetición doble de R1 no garantiza entrega: el puente deja de esperar después de la primera respuesta aceptada estructuralmente.
- No se observó recuperación completa ante un radio que falla después de haber sido marcado loraReady.
- No hay supervisión térmica/energética operativa en el protocolo.
- No se evaluó legalidad de frecuencia/potencia ni seguridad de vuelo.
Compatibilidad aparente no equivale a validación física.
9. Informe de inteligencia artificial
Inferencia
El código:
1. Deserializa un motor TensorRT externo.
2. Espera una entrada de cuatro dimensiones NHWC.
3. Sustituye dimensiones dinámicas espaciales por 640.
4. Redimensiona directamente el frame.
5. Convierte BGR a RGB.
6. Utiliza float32 con valores sin normalización explícita.
7. Busca salidas compatibles con num_detections, detection_boxes, detection_scores y detection_classes.
8. Filtra por confianza.
9. Escala cajas normalizadas a la resolución del frame.
No puede confirmarse:
- Arquitectura exacta y entrenamiento del motor.
- Correspondencia de normalización con entrenamiento.
- Label map y clase objetivo.
- NMS integrado dentro del motor.
- Compatibilidad de plugins, TensorRT, CUDA y JetPack.
- Integridad del artefacto mediante hash.
- Rendimiento o exactitud.
No se considera incorrecta la ausencia de normalización o NMS externo por sí misma: pueden estar incorporados en el modelo exportado.
Tracking
- BoT-SORT es la selección predeterminada.
- Si su inicialización falla, se utiliza el tracker interno.
- Existe compensación ORB de movimiento global.
- La reidentificación usa posición, tamaño, aspecto e histograma HSV.
- La memoria de reidentificación tiene ventana temporal.
- Los animales parecidos pueden fusionarse; los que reaparecen tarde pueden duplicarse.
- El movimiento de dron y ganado, oclusiones y cambios de perspectiva requieren evaluación específica.
Conteo
Se incrementa el acumulado al confirmar identidades de tracking.
Esto no demuestra identidad biológica persistente.
La comprobación aislada del tracker interno mostró:
Objeto visible → identidad eliminada tras ausencias → misma caja reaparece
Resultado: dos identidades y acumulado 2.
La asociación fue simplificada en el doble de prueba; el resultado demuestra el comportamiento del ciclo de eliminación/recreación, no una tasa de error de campo.
Métricas
Existen puntos de instrumentación para FPS, latencia y frames procesados/descartados. No se identificaron resultados experimentales reproducibles suficientes para acreditar:
- mAP.
- Precision y recall.
- Falsos positivos/negativos.
- Error de conteo por sesión.
- ID switches o fragmentación.
- Latencia E2E.
- Memoria y rendimiento sostenido.
No hay evidencia suficiente para afirmar conteo único confiable.
10. Informe de software
Flutter
Aspectos positivos:
- Separación razonable entre vistas, viewmodels, repositorios y servicios.
- Estado de sesión recreado por UID.
- Verificación backend antes de aceptar R1.
- Estados de error visibles.
- Controles de carga y prevención de varias acciones repetidas.
- Controladores y suscripciones con limpieza explícita.
- Historial y alertas con carga adicional.
Problemas:
- Desconectar borra el resultado mantenido en memoria.
- La cola no vincula una tarea a la generación/sesión en que fue solicitada.
- Una sesión revocada sigue representada por _currentUser hasta que se cierre explícitamente.
- La clasificación de algunos errores depende de texto que contiene sesion.
- El diagnóstico de audio Bluetooth usa una API incompatible.
- Las capacidades de escritorio/web no están acreditadas por la existencia de carpetas de plataforma.
Backend y Firestore
Colecciones relevantes:
- Usuarios.
- Subcolecciones ConfiguracionSistema, DispositivosConteo, Conteos, Alertas.
- IotCommands, IotSessions, IotDevices.
- CedulasUsuarios, OperacionesUsuarios.
- Colecciones legacy raíz.
Los conteos nuevos usan ID de sesión como ID de documento, lo cual evita duplicación por reintentar guardado.
La coexistencia legacy presenta discrepancias:
- Listados deduplican, agregaciones suman.
- Lectura de configuración admite legacy; inicio de conteo no.
- Borrado de usuario no recorre todas las colecciones legacy.
- Consultas legacy están limitadas sin paginación equivalente.
No se identificaron endpoints para editar arbitrariamente cantidades ya guardadas.
Datos simulados
No se encontró una generación aleatoria de conteos presentada como resultado real en el flujo vigente.
Sí hay valores de sustitución —por ejemplo, ceros o fechas actuales en algunos modelos— que pueden ocultar datos ausentes. Esto merece endurecimiento del contrato, pero no prueba simulación deliberada.
11. Informe de calidad
Pruebas observables
| Área | Cobertura presente | Vacíos relevantes |
|---|---|---|
| Backend unitario | Validación, credenciales aleatorias, HMAC, formatos | Máquina de estados y concurrencia de respuestas |
| Backend integración | Roles, aislamiento, conteo, paginación, reglas, usuarios | Replay antiguo sobre sesión nueva; empates grandes; fallos parciales |
| Flutter | Widgets, API, cola, mensajes BLE, formatos | BLE completo, reconexión con tareas pendientes, recuperación durable |
| Jetson protocolo | Firma, expiración, replay, comandos sin firma, SPI simulado | Reinicio con resultado real y ciclo completo worker |
| Tracking | Confirmación, filtros, selección y GMC sintético | Identidades reales, reapariciones prolongadas, oclusión y re-ID |
| Firmware | No se identificó suite automatizada | Compilación CI, buffers, concurrencia, RF |
| Hardware/E2E | Documentación histórica | Evidencia repetible de esta revisión |

La prueba de paginación existente usa fechas distintas; no cubre el defecto reproducido.
La prueba del dashboard legacy documenta y acepta el total duplicado actual. Un test verde puede estar fijando un comportamiento incorrecto.
Mantenibilidad
- run_bovino.py: 2.735 líneas.
- lora_jetson_rx.py: 1.561 líneas.
- Servicio BLE: 943 líneas.
- Pantalla de conteo: 902 líneas.
Concentran responsabilidades, pero no justifican reescribir el proyecto. Conviene separar posteriormente protocolo, ciclo de sesión, captura e identidad, preservando interfaces y tests.
La CI existe, pero no acredita despliegue ni hardware. Flutter estable, firebase-tools y dependencias Python de CI no están completamente fijados.
12. Matriz de hallazgos detallados
Para cada registro, las referencias remiten al catálogo del apartado 3. “Probabilidad” es cualitativa y condicionada al disparador; no representa frecuencia medida.
BOV-HIGH-001 — Replay de IDLE altera una sesión posterior
- Subsistema/severidad/tipo/evidencia: backend IoT; alta; vulnerabilidad de autorización y repetición; CONFIRMADO.
- Ruta/función/líneas: B1, verify, líneas 74, 76, 77, 100 y 101.
- Esperado: verificar de nuevo una respuesta antigua no modifica el estado actual.
- Observado: si data.response ya existe, se omite frescura; cualquier IDLE puede borrar la sesión actual del dispositivo sin comparar propietario o sesión.
- Reproducción segura realizada: ticket antiguo de usuario A, respuesta ya verificada, reserva nueva de B; verify(A, respuesta) produjo actualización de la reserva de B.
- Impacto/probabilidad: pérdida de control lógico, bloqueo de consultas/detención y ocupación incorrecta; alta bajo replay deliberado, posible por reintentos.
- Causa raíz: idempotencia del contenido sin idempotencia de efectos; falta de vinculación entre observación y versión actual del dispositivo.
- Solución/alternativa: devolver el resultado previamente verificado sin nuevos efectos; condicionar cambios a sesión/versión esperada. Alternativa: transición explícita de reconciliación.
- Regresión/aceptación: replay de A durante sesión B no cambia B; respuestas fuera de orden no retroceden estado.
- Dependencias/complejidad/prioridad: ninguna; media; P0.
BOV-HIGH-002 — ESTADO falla después de una sesión terminada
- Subsistema/severidad/tipo/evidencia: contrato Jetson/backend; alta; defecto funcional; CONFIRMADO.
- Ruta/función/líneas: J1 execute_secure_command, 1218; status, 775; J2 handle, 92; B1 verify, 80 y 86.
- Esperado: H informa disponibilidad independientemente del último conteo.
- Observado: H consulta un controlador que conserva STOPPED y cantidad. R1 usa sesión -; backend exige sesión para cualquier terminal con cantidad.
- Verificación: una respuesta H/STOPPED firmada produjo HTTP lógico 400, “Fecha de finalizacion invalida”.
- Disparador/impacto/probabilidad: terminar y consultar estado, especialmente al reconectar; impide comprobación y recuperación normal; alta en esa secuencia.
- Causa: contrato de disponibilidad mezclado con resultado de sesión.
- Solución/alternativa: definir respuesta de disponibilidad sin prueba terminal; reservar resultados para Q/R/T, o rediseñar explícitamente el contrato.
- Regresión/aceptación: H funciona antes, durante y después de conteos y tras reinicios; no filtra cantidades de otra sesión.
- Dependencias/complejidad/prioridad: H001 para transiciones seguras; media; P1.
BOV-HIGH-003 — Recuperación durable de resultados no implementada
- Subsistema/severidad/tipo/evidencia: Jetson y app; alta; funcionalidad incompleta; CONFIRMADO.
- Ruta/función/líneas: J2 save_result, 97, y result, 102; J1 finish_session, 905; F1 disconnect, 928.
- Esperado: recuperar un resultado tras reiniciar receptor o aplicación.
- Observado: los métodos SQLite de resultados no tienen llamadas operativas; controlador conserva sesión/resultado en memoria. Flutter borra snapshots al desconectar.
- Disparador: resultado no guardado, reinicio y consulta posterior.
- Impacto/probabilidad: pérdida de recuperabilidad automática; alta si el receptor reinicia antes de verificar/guardar.
- Matiz: un resultado ya verificado puede existir en IotSessions, pero falta un recorrido móvil completo para recuperarlo.
- Causa: persistencia implementada como API aislada, no como parte del ciclo de sesión.
- Solución/alternativa: persistir final y sesión antes de responder; recuperación por ID; listado de sesiones pendientes en backend. Alternativa: reconciliación desde artefactos durables.
- Regresión/aceptación: finalizar, perder respuesta, reiniciar y guardar exactamente una vez, con fecha original.
- Dependencias/complejidad/prioridad: H001, H002, H004; alta; P1.
BOV-HIGH-004 — Terminación forzada convertida en resultado válido
- Subsistema/severidad/tipo/evidencia: conteo; alta; integridad de datos; CONFIRMADO.
- Ruta/función/líneas: J1 stop, 734, 738, 750 y 751; secure_completed, 1180; B2 registrarConteoReal, 344 y 351.
- Esperado: una terminación forzada identifica resultado parcial/no validado.
- Observado: SIGKILL conduce a STOPPED con último acumulado; se firma y puede guardarse como finalizado. El motivo no viaja en R1.
- Reproducción realizada: proceso simulado que agota SIGTERM devolvió STOPPED, cantidad 7, motivo killed_after_timeout.
- Impacto/probabilidad: subconteos persistidos como finales y alertas engañosas; condicionada a bloqueos/interrupción.
- Causa: éxito de cierre y validez del resultado comparten estado.
- Solución/alternativa: distinguir completo, parcial, abortado y error; exigir evidencia final del worker. Alternativa: permitir guardar parciales con etiqueta explícita.
- Regresión/aceptación: SIGKILL, cámara congelada o cero frames no generan final válido silencioso.
- Dependencias/complejidad/prioridad: contrato backend/app; media-alta; P0 por integridad.
BOV-HIGH-005 — Captura puede quedar sin progreso y sin error terminal
- Subsistema/severidad/tipo/evidencia: cámara/hilos; alta; estabilidad; CONFIRMADO en la lógica.
- Ruta/función/líneas: J3 capture_worker, 2025, 2089, 2122 y 2170; infer_worker, 2267; main, 2722.
- Esperado: pérdida sostenida de frames o excepción del hilo produce estado de error y cierre.
- Observado: para fuentes vivas, lecturas fallidas solo esperan y repiten; excepciones de captura no siempre establecen stop_event.
- Disparadores: desconexión, fallo OpenCV, frame inválido o bloqueo de lectura.
- Impacto/probabilidad: UI RUNNING con conteo congelado, recursos ocupados; probable en fallos de cámara.
- Causa: supervisión de proceso sin supervisión de progreso/hilos.
- Solución/alternativa: watchdog de último frame, propagación central de excepciones y reconexión limitada; alternativamente terminar explícitamente la sesión.
- Regresión/aceptación: simular read=False, excepción y bloqueo; transición a error dentro de un plazo definido, sin final normal.
- Dependencias/complejidad/prioridad: H004; media-alta; P1.
BOV-HIGH-006 — Cierre del receptor y del worker no garantiza liberación completa
- Subsistema/severidad/tipo/evidencia: procesos; alta; riesgo de huérfanos/estado obsoleto; PROBABLE.
- Ruta/función/líneas: J1 start, 670; main, 1549 y 1551; J3 main, 2725 y 2730.
- Esperado: SIGTERM/reinicio deja procesos cerrados y final coherente.
- Observado: receptor no registra manejador SIGTERM; cleanup depende del finally. Worker hace joins limitados y emite final sin comprobar is_alive.
- Condiciones: SIGTERM al receptor, hilo nativo bloqueado y política systemd que no elimine todo el grupo.
- Impacto/probabilidad: worker sobreviviente, cámara ocupada o final emitido antes de terminar; probabilidad dependiente de despliegue.
- Causa: responsabilidad de cierre repartida entre Python y un servicio no versionado completo.
- Solución/alternativa: parada central idempotente, supervisión y política systemd explícita; aislamiento de captura si no es cancelable.
- Regresión/aceptación: SIGTERM, excepción y reinicio dejan cero hijos previos y permiten nueva captura.
- Dependencias/complejidad/prioridad: H004, H005; alta; P1.
BOV-HIGH-007 — Identidades de tracking no garantizan conteo único
- Subsistema/severidad/tipo/evidencia: IA/conteo; alta; limitación algorítmica; CONFIRMADO para recreación interna; validación de campo pendiente.
- Ruta/función/líneas: J3 PersistentBovineTracker.update, 1389 y 1401; _count_track, 1295; _cleanup_identity_memory, 1627.
- Esperado: un mismo animal no incrementa nuevamente el conteo dentro del dominio operativo definido.
- Observado: tracks eliminados pueden reaparecer con nuevo ID; re-ID externa tiene ventana temporal y heurísticas que también pueden fusionar animales distintos.
- Verificación: desaparición superior al buffer y reaparición sintética incrementaron el acumulado.
- Impacto/probabilidad: sobre/subconteo; aumenta con oclusiones, vueltas del dron y ganado agrupado.
- Causa: equivalencia implícita entre identidad temporal e individuo.
- Solución/alternativa: definir protocolo de recorrido/conteo, evaluar re-ID y límites; alternativa localizada: conteo por cruce/región con condiciones operativas controladas.
- Regresión/aceptación: vídeos etiquetados con reaparición, agrupamiento y cámara móvil; error medido contra umbral acordado.
- Dependencias/complejidad/prioridad: H008, M004; alta; P1.
BOV-HIGH-008 — Modelo y exactitud no auditables con los artefactos disponibles
- Subsistema/severidad/tipo/evidencia: ML; alta respecto al objetivo central; evidencia insuficiente; PENDIENTE DE VALIDACIÓN.
- Ruta/función/líneas: J1 configuración del engine, 50; J3 TRTDetector, 419, 460, 515; decode_detections, 595 y 652.
- Esperado: contrato reproducible entre entrenamiento, exportación e inferencia.
- Observado: motor externo; sin artefacto, label map, dataset de evaluación ni métricas reproducibles identificados.
- Riesgo adicional: el decoder conserva cualquier clase aceptada por confianza; no filtra explícitamente bovino.
- Impacto/probabilidad: semántica de entrada/salida y precisión desconocidas; no estimable sin motor.
- Causa: ausencia de paquete de validación, no prueba de que el modelo sea incorrecto.
- Solución/alternativa: registrar hash, versiones, shapes, normalización, clases, NMS y resultados; conservar modelo privado si se aporta manifiesto verificable.
- Prueba/aceptación: dataset independiente, comparación de exportación y TensorRT, métricas de detección y conteo separadas.
- Dependencias/complejidad/prioridad: ninguna; alta por evaluación; P1 y requisito de demostración.
BOV-MED-001 — Paginación omite registros con fechas iguales
- Subsistema/severidad/tipo/evidencia: historial/alertas; media; defecto; CONFIRMADO.
- Ruta/función/líneas: B2 listOwnedMerged, 175, 178, 189, 197 y 208.
- Esperado: recorrer todos los documentos sin pérdidas.
- Observado: solo se obtienen limit+1 actuales; ampliar empates en ese subconjunto no recupera los demás; cursor excluye toda la fecha.
- Verificación: 35 documentos de igual fecha, límite 30: primera página 31, segunda 0.
- Impacto/probabilidad: historial incompleto; condicionada a empates o importaciones.
- Causa: cursor solo temporal.
- Solución/alternativa: cursor compuesto fecha/ID y merge paginado estable; alternativa migración controlada a una colección canónica.
- Regresión/aceptación: grupos mayores que página, múltiples fechas y fuentes; ningún ID perdido/repetido.
- Dependencias/complejidad/prioridad: M002; media; P1.
BOV-MED-002 — Compatibilidad legacy inconsistente
- Subsistema/severidad/tipo/evidencia: datos; media; defectos de integración; CONFIRMADO.
- Ruta/función/líneas: B2 getConfigDoc, 127; consultas 141 y 183; dashboard 296; B1 issue, 42; B3 borrado, 43 y 44.
- Esperado: misma configuración, historial y política de eliminación en todos los recorridos.
- Observado: dashboard deduplica listados pero suma documentos; configuración legacy se muestra y no sirve para iniciar; históricos se limitan a 100/200; borrado no recorre todas las colecciones raíz.
- Impacto/probabilidad: totales contradictorios, inicio rechazado y datos residuales; condicionado a datos legacy.
- Causa: compatibilidad añadida por endpoint.
- Solución/alternativa: capa común o migración reversible con inventario y deduplicación.
- Prueba/aceptación: fixtures actuales/legacy/duplicados; totales coherentes, configuración utilizable y política de retención explícita.
- Dependencias/complejidad/prioridad: M001; media-alta; P2.
BOV-MED-003 — Comandos encolados pueden ejecutarse en otra conexión o sesión
- Subsistema/severidad/tipo/evidencia: Flutter; media; concurrencia; CONFIRMADO estructuralmente, reproducción móvil pendiente.
- Ruta/función/líneas: F2 add, 18; F1 sendCommand, 725; _sendCommand, 737; F3 issueCommand, 16.
- Esperado: una tarea conserva el contexto en el que fue solicitada.
- Observado: la generación se captura al ejecutar, no al encolar; no se envía session_id; no se vacía la cola al desconectar.
- Disparador: tarea pendiente, desconexión/reconexión y cambio de sesión activa.
- Impacto/probabilidad: consulta o detención aplicada a sesión diferente; probable en carreras específicas.
- Causa: cola de closures sin contexto ni cancelación.
- Solución/alternativa: capturar generación/sesión, invalidar pendientes y limitar cola; coalescer consultas.
- Regresión/aceptación: ninguna tarea de una conexión anterior actúa sobre una sesión nueva.
- Dependencias/complejidad/prioridad: H001, H003; media; P1.
BOV-MED-004 — Filtro previo impide aprovechar detecciones de baja confianza
- Subsistema/severidad/tipo/evidencia: tracking; media; integración; CONFIRMADO.
- Ruta/función/líneas: J3 infer_worker, 2298; defaults 2518 y 2582; _to_supervision, 1714.
- Esperado: umbral bajo permite asociar detecciones débiles a tracks existentes.
- Observado: decoder elimina por defecto todo valor inferior a 0,45 antes de llegar al umbral de tracking 0,15.
- Impacto/probabilidad: fragmentación y pérdida de asociación; alta cuando la confianza baja.
- Causa: mismo conjunto filtrado usado para visualización y tracking.
- Solución/alternativa: suministrar candidatos con umbral bajo y separar umbral de creación; no reducir indiscriminadamente la aceptación.
- Regresión/aceptación: secuencia 0,9→0,25→0,9 conserva identidad sin crear tracks por ruido aislado.
- Dependencias/complejidad/prioridad: H007, H008; baja-media; P1.
BOV-MED-005 — Crecimiento no acotado de memoria y archivos
- Subsistema/severidad/tipo/evidencia: recursos; media; riesgo de agotamiento; CONFIRMADO en estructuras, impacto no medido.
- Ruta/función/líneas: J3 constante 23, cola 2635, tracks 1390; J1 log 645 y archivos 625; B1 ticket 63.
- Esperado: consumo limitado o política de retención explícita.
- Observado: cola exhaustiva ilimitada; tracks internos eliminados permanecen almacenados; log append y JSON por sesión sin limpieza en código.
- Impacto/probabilidad: OOM en vídeo exhaustivo o almacenamiento lleno tras uso sostenido; condicionada al volumen.
- Causa: ausencia de backpressure/retención en rutas concretas.
- Solución/alternativa: cola finita bloqueante, compactación y rotación; política TTL verificada.
- Matiz: expires_at no acredita una política TTL activa; debe configurarse expresamente. Documentación Firestore.
- Prueba/aceptación: vídeo largo y sesiones repetidas con techo de memoria/disco definido.
- Dependencias/complejidad/prioridad: H003 antes de depurar resultados; media; P2.
BOV-MED-006 — Transporte BLE/LoRa vulnerable a denegación por mensajes no autenticados
- Subsistema/severidad/tipo/evidencia: comunicaciones; media; disponibilidad; CONFIRMADO en controles ausentes, ataque físico pendiente.
- Ruta/función/líneas: E1 setupBLE, 403 y 419; handleLoRaPayload, 267 y 283; F1 _receive, 685.
- Esperado: mensajes falsos no consumen definitivamente la espera legítima.
- Observado: BLE sin pairing autenticado configurado; primer R1 con ID coincidente cierra espera del puente antes de validar HMAC en backend.
- Condiciones: proximidad BLE/LoRa y conocimiento del request ID observable en radio.
- Impacto/probabilidad: bloqueo o pérdida de respuesta; no falsificación exitosa del conteo; probabilidad física no medida.
- Causa: correlación estructural tratada como recepción suficiente.
- Solución/alternativa: endurecer enlace BLE y conservar ventana de recepción/reintento tras respuesta inválida; mantener secreto fuera del puente.
- Prueba/aceptación: inyectar respuesta falsa en simulador y después legítima; no aceptar la falsa ni perder innecesariamente la legítima.
- Dependencias/complejidad/prioridad: contrato C1/R1; media; P2.
BOV-MED-007 — Brownout desactivado como configuración predeterminada
- Subsistema/severidad/tipo/evidencia: ESP32; media; riesgo eléctrico-operativo; CONFIRMADO en firmware; impacto pendiente.
- Ruta/función/líneas: E1 constante 56; stabilizePowerBeforeRadios, 505 y 506.
- Esperado: alimentación estable y respuesta definida ante subtensión.
- Observado: detector brownout desactivado explícitamente.
- Impacto/probabilidad: funcionamiento indeterminado durante caídas de tensión; depende de fuente/carga.
- Causa: mitigación software de síntomas de alimentación.
- Solución/alternativa: validar alimentación y protección; excepción diagnóstica documentada si realmente necesaria.
- Prueba/aceptación: ensayo eléctrico autorizado con medición bajo BLE+TX; reinicio o degradación controlados.
- Dependencias/complejidad/prioridad: hardware; media; P1 antes de campo.
BOV-MED-008 — Despliegue insuficientemente reproducible
- Subsistema/severidad/tipo/evidencia: DevOps; media; deuda técnica; CONFIRMADO.
- Ruta/función/líneas: C1 líneas 27 y 47; J1 rutas 47 y 50; .github/workflows/ci.yml, línea 1; jetson/systemd/unbuffered.conf, línea 1.
- Esperado: construir y desplegar la misma versión con configuración verificable.
- Observado: release Android firma debug; no se identificó manifiesto Python/firmware fijado ni unidad systemd completa; CI usa componentes variables.
- Impacto/probabilidad: divergencia entre equipos, fallback inesperado y publicación no preparada; alta al replicar entorno.
- Causa: instalación operacional externa al repositorio.
- Solución/alternativa: manifiesto de entorno, versión de placa/bibliotecas y unidad reproducible; firma release separada.
- Prueba/aceptación: instalación limpia controlada reproduce versiones y contrato; build release sin firma debug.
- Dependencias/complejidad/prioridad: H008; media; P2, obligatorio antes de distribuir.
BOV-MED-009 — Autoedición administrativa puede bloquear su propia recuperación
- Subsistema/severidad/tipo/evidencia: administración; media; recuperación; PROBABLE.
- Ruta/función/líneas: B3 execute, 33, 62, 63 y 104; B4 líneas 84 y 85; usuarioController.js, línea 84.
- Esperado: fallo parcial de autoedición tiene una vía segura de reanudación.
- Observado: autoedición está permitida mientras conserva rol/estado; se marca operación pendiente y revocan tokens. Un fallo posterior puede impedir al mismo administrador reintentar.
- Condiciones: único administrador, autoedición y fallo entre Auth y finalización Firestore.
- Impacto/probabilidad: recuperación requiere otro administrador o intervención operativa; baja-media condicionada.
- Causa: actor de recuperación y usuario bloqueado son la misma identidad.
- Solución/alternativa: política específica de autoedición y recuperación; alternativa impedir operaciones sensibles sobre sí mismo.
- Prueba/aceptación: inyectar fallo en cada frontera Auth/Firestore y demostrar recuperación autorizada.
- Dependencias/complejidad/prioridad: ninguna; media; P2.
BOV-MED-010 — UI autenticada no se reconcilia automáticamente con revocación
- Subsistema/severidad/tipo/evidencia: Flutter; media; sesión/UX; CONFIRMADO.
- Ruta/función/líneas: F6 isAuthenticated, 24; login 45; F4 respuesta de error, 155; F5 reanudación, 197.
- Esperado: una sesión invalidada deja de presentarse como autorizada.
- Observado: _currentUser determina la UI; un 401/403 no activa invalidación central ni recarga del perfil.
- Disparador: desactivación, cambio de rol o revocación durante una sesión.
- Impacto/probabilidad: pantalla obsoleta y errores repetidos; no bypass de autorización backend; probable durante administración.
- Causa: estado local desacoplado de errores de autenticación.
- Solución/alternativa: invalidación central por 401 y tratamiento específico de 403; no cerrar sesión por cualquier indisponibilidad.
- Regresión/aceptación: revocación cierra/restablece acceso; timeout de red conserva una recuperación razonable.
- Dependencias/complejidad/prioridad: M003 para cancelar tareas; media; P2.
BOV-LOW-001 — Diagnóstico de audio Bluetooth utiliza API incompatible
- Subsistema/severidad/tipo/evidencia: Android; baja; defecto de diagnóstico; CONFIRMADO por código y API.
- Ruta/función/líneas: A1 connectedAudioDeviceNames, 39, 43 y 51.
- Esperado: consultar dispositivos A2DP/HEADSET correctamente.
- Observado: se pasan esos perfiles a BluetoothManager.getConnectedDevices, limitado a GATT/GATT_SERVER; la excepción termina en lista vacía. Fuente Android AOSP.
- Impacto/probabilidad: diagnóstico incompleto; alta cuando se usa esa rama.
- Causa: confusión entre APIs de perfiles clásicos y GATT.
- Solución/alternativa: API de perfil apropiada o eliminar diagnóstico causal no demostrable.
- Prueba/aceptación: teléfonos con/sin audio conectado; no afirmar que unos audífonos causan el fallo BLE sin evidencia.
- Dependencias/complejidad/prioridad: ninguna; baja-media; P3.
BOV-LOW-002 — Documentación y módulos históricos inducen expectativas incorrectas
- Subsistema/severidad/tipo/evidencia: documentación; baja; mantenibilidad; CONFIRMADO.
- Ruta/función/líneas: README.md, línea 1; comunicacion-iot/shared/protocol.py, línea 1; backend/src/routes/usuarioRoute.js, línea 1; J2 métodos 97 y 102.
- Esperado: documentación distingue implementación, pruebas históricas y funciones pendientes.
- Observado: referencias a envío de credenciales frente a enlace de activación; protocolo JSON denominado seguro aunque solo usa checksum; rutas duplicadas; persistencia descrita con mayor alcance que el flujo real.
- Impacto/probabilidad: integración con interfaces obsoletas y confianza injustificada; media al incorporar desarrolladores.
- Causa: documentación acumulativa sin reconciliación final.
- Solución/alternativa: marcar módulos históricos y generar un contrato vigente; retirar duplicados solo tras confirmar ausencia de consumidores.
- Prueba/aceptación: documentación enlaza código y separa verificado/pending.
- Dependencias/complejidad/prioridad: posteriores a correcciones funcionales; baja; P3.
13. Mapa de dependencias entre correcciones
H001 Autorización e idempotencia
  ├── H002 Contrato de estado
  ├── H003 Recuperación durable
  └── M003 Cola ligada a sesión

H004 Resultado completo/parcial
  ├── H005 Supervisión de captura
  ├── H006 Cierre de procesos
  └── H003 Persistencia y recuperación

H008 Contrato y validación del modelo
  ├── M004 Umbrales del tracker
  └── H007 Evaluación de conteo único

M002 Modelo canónico/legacy
  └── M001 Paginación consistente

H003 Recuperación durable
  └── M005 Retención segura de archivos y estado

Correcciones funcionales
  ├── M008 Reproducibilidad
  └── L002 Documentación final
No conviene borrar artefactos operativos ni activar TTL agresivo antes de resolver recuperación e idempotencia.
14. Plan de remediación
| Etapa | Qué corregir y por qué | Dónde | Qué preservar | Comprobación y evidencia |
|---|---|---|---|---|
| **P0** | Replay que altera reservas; finales parciales tratados como completos | B1, J1, J2, B2, F1 | HMAC, autorización por UID, guardado idempotente | Tests de replay cruzado y SIGKILL; estados antes/después |
| **P1** | Contrato `H/Q/R`, recuperación, cámara, procesos y cola | J1/J2/J3, F1/F2/F3 | Firmware opaco y comandos autenticados | Secuencias iniciar/detener/reiniciar; cero procesos previos |
| **P1** | Validar modelo y conteo; corregir umbrales | J3 y manifiesto de modelo | Motor existente hasta comparar resultados | Dataset, configuración, métricas y errores por escenario |
| **P1** | Alimentación y brownout antes de campo | E1 y hardware | Pinout vigente sin cambios improvisados | Medición eléctrica autorizada y firmware identificado |
| **P2** | Paginación, legacy, sesiones UI, recursos y transporte | Backend/Flutter/ESP32 | Historial existente y recuperación | Fixtures, pruebas de fallos, límites de consumo |
| **P2** | Reproducibilidad y publicación | CI, dependencias, systemd, Android | Configuración privada fuera del repo | Instalación limpia y hashes/versiones |
| **P3** | Separación localizada y documentación | Módulos grandes y docs | Interfaces públicas y tests | Diff acotado, pruebas sin regresiones |
| **P4** | Optimización medida | Pipeline y radio | Exactitud y recuperación | Comparación reproducible de latencia/FPS/consumo |

P0 expresa urgencia; no implica que se haya asignado severidad crítica.
15. Backlog para el agente implementador
Las tareas siguientes son propuestas; no fueron ejecutadas.
| Tarea | Objetivo y archivos | Pasos sugeridos y restricciones | Aceptación y regresión |
|---|---|---|---|
| T01 — H001 | Hacer `verify` idempotente; B1/tests | Separar lectura de respuesta cacheada de transición; comprobar sesión/versión. No relajar firmas ni propiedad | Replay antiguo no altera dispositivo; dos usuarios y respuestas desordenadas |
| T02 — H002 | Definir disponibilidad; J1/J2/B1/F1 | Especificar `H` antes/durante/después; reservar pruebas finales a sesión identificada | `H` siempre interpretable; ninguna cantidad ajena |
| T03 — H004 | Distinguir parcial/completo; J1/J2/B2/F1/F7 | Añadir semántica terminal y causa; no convertir unknown en cero | SIGKILL/timeout/cero frames no aparecen como final normal |
| T04 — H005/H006 | Supervisar y cerrar workers; J1/J3 | Propagar excepciones, watchdog de progreso, cierre idempotente; no reiniciar servicios físicos automáticamente | Fallos simulados terminan dentro del plazo; recursos liberados |
| T05 — H003 | Recuperar sesiones; J1/J2/B1/F1/F3 | Persistir antes de responder, recuperar por ID, exponer pendientes propios; no borrar SQLite existente | Reinicio y pérdida de respuesta conservan resultado/fecha |
| T06 — M003 | Invalidar tareas antiguas; F1/F2/F3 | Contexto al encolar, sesión explícita, límite y cancelación | Tarea vieja nunca detiene sesión nueva |
| T07 — H008 | Producir contrato ML | Inventariar motor, hashes, versiones, clases y preprocesamiento; no asumir normalización | Inferencia comparada con referencia y artefactos identificados |
| T08 — M004/H007 | Evaluar tracking/conteo; J3/tests | Separar umbrales y medir re-ID; no cambiar múltiples parámetros sin comparación | Vídeos etiquetados; errores por oclusión, retorno y cámara móvil |
| T09 — M001/M002 | Unificar paginación y legacy; B2/B1/B3 | Cursor compuesto, merge estable y política de migración; no borrar datos sin respaldo/autorización | Todos los IDs recuperables, totales coherentes |
| T10 — M005 | Acotar consumo; J3/J1/B1 | Backpressure, rotación y retención posterior a T05 | Techo de memoria/disco; sin perder pruebas recuperables |
| T11 — M006/M007 | Endurecer puente | Simular colas/respuestas falsas; validar brownout en banco autorizado | Respuesta falsa no valida ni inutiliza recuperación; alimentación estable |
| T12 — M009/M010 | Recuperación de cuentas | Fallos Auth/Firestore, política de autoedición y manejo 401/403 | Administrador recuperable; sesión revocada no queda operativa en UI |
| T13 — M008 | Reproducir despliegue | Fijar versiones y unidad systemd; configurar firma release | Build/instalación reproducibles sin secretos incluidos |
| T14 — L001/L002 | Corregir diagnóstico y documentación | API Android correcta; etiquetar legacy; actualizar contratos tras T01–T13 | Documentación consistente y diagnóstico comprobado |


Cada entrega debería incluir: diff localizado, pruebas ejecutadas, resultados, escenarios no probados y evidencia de que no cambió el protocolo o comportamiento ajeno a la tarea.
16. Riesgos residuales y escenarios adversos
Matriz de fallos

| Escenario | Esperado | Deducible del código, recuperación y riesgo | Evidencia / prueba pendiente |
|---|---|---|---|
| BLE desconectado | Estado recuperable | Cancela recursos, borra snapshot; worker sigue | F1:928; reconectar con resultado sin guardar |
| LoRa fuera de alcance | Timeout y reconciliación | B0 a 22 s; no se sabe si orden ejecutó | E1:318; perder solo respuesta |
| Jetson reiniciada | Recuperar o marcar interrumpido | Sesión en memoria perdida; SQLite resultados no integrado | H003; reinicio controlado |
| ESP32 reiniciado | Restablecer enlace y consultar | Pierde espera; reinicializa BLE/LoRa | E1:533; reinicio durante S/T |
| Cámara desconectada | Error limitado en tiempo | Puede repetir lectura sin progreso | H005 |
| Modelo no encontrado | Rechazo claro | Validación de ruta o error de inferencia | J1:572; stub de archivo ausente |
| TensorRT falla | Error, recursos liberados | Excepción capturada; construcción parcial tiene huecos | J3:2215,2425; fallo de cada asignación |
| Backend inaccesible | Estado local seguro | No se emite nuevo ticket, incluido detener | F1:743; timeout local de sesión |
| Firebase indisponible | Fallo recuperable | Autorización/emisión/guardado pueden fallar | B4:37, B1; emulador con fallos |
| Usuario sin permisos | Denegar | Backend deniega; UI puede quedar obsoleta | B4, M010 |
| Comando duplicado, mismo ID | No ejecutar dos veces | SQLite cachea respuesta | J2:73; falta prueba física |
| Inicio repetido, nuevo ID | Mantener sesión | Backend convierte S en Q si reserva vigente | B1:37; concurrentes |
| Detención repetida | Mismo resultado | Reutiliza resultado en memoria; falla recuperación tras reinicio | J1:689; H003 |
| Comandos fuera de orden | No retroceder estado | Frescura temporal no garantiza orden causal | H001/M003 |
| Operaciones simultáneas | Exclusión por sesión | Transacciones y cola ayudan; respuestas antiguas rompen reserva | H001 |
| Conteo interrumpido | Parcial/abortado | Puede guardarse como final | H004 |
| Resultado recibido dos veces | Una persistencia | ID de sesión deduplica; verificación tiene efectos repetibles | B2:340; H001 |
| Respuesta perdida tras ejecutar | Consultar estado/resultado | Recuperación parcial; H terminal puede fallar | H002/H003 |
| Memoria insuficiente | Error controlado | CUDA puede fallar; cola exhaustiva aumenta presión | M005/H006 |
| Almacenamiento lleno | No afirmar persistencia | JSON solo registra error; SQLite puede impedir respuesta | J3:93, J2:94 |
| Error inesperado en worker | Detener y reportar | Inferencia propaga; captura/display no siempre | H005/H006 |
| Cierre forzado de app | Sesión recuperable | No garantiza comando de parada; estado local volátil | F5:208; H003 |
| Restauración de conectividad | Reconciliar antes de actuar | Reconexión manual y nuevas consultas; cola antigua pendiente | M003 |
| Ejecución prolongada | Recursos acotados | Timeout controlador; logs y artefactos acumulativos | M005 |
| Iniciar→iniciar | Sin proceso duplicado | `is_worker_alive` y reserva lo impiden en camino normal | J1:604, B1:37 |
| Detener→reiniciar conteo | Nueva sesión limpia | Habitualmente posible; finales/consulta y tareas viejas interfieren | H002/M003 |
| Interrumpir→recuperar | Conservar resultado y estado | No garantizado | H003/H004/H006 |



Aspectos que permanecen sin acreditar
- Versión efectiva en Jetson y ESP32.
- Cámara CSI y compatibilidad Argus/GStreamer.
- Motor TensorRT, plugins y CUDA.
- Térmica, potencia y batería.
- Comportamiento de LoRa.endPacket() con la biblioteca realmente instalada.
- Política systemd, permisos y usuario del servicio.
- Reglas Firebase activas, índices y TTL.
- Rotación de credenciales mencionadas en documentación histórica.
- Calidad RF en campo.
- Seguridad del prototipo aéreo.
- Precisión de conteo y estabilidad sostenida.
17. Conclusión técnica
Preparación para demostración académica
El proyecto tiene suficiente implementación para preparar una demostración técnica relevante, pero no se acredita todavía una demostración completa, repetible y recuperable del conteo real.
Antes de presentarla como funcional de extremo a extremo deben cerrarse:
- Replay de estado y coherencia de sesiones.
- Consulta después de finalizar.
- Clasificación de resultados parciales.
- Recuperación tras desconexión/reinicio.
- Validación de cámara, motor y al menos un conjunto de escenas con referencia manual.
- Registro de versiones efectivamente instaladas.
Una demostración parcial de autenticación, administración o transporte debe identificarse como parcial.
Preparación para operación real
No está acreditada. Persisten defectos de integridad, recuperación y trazabilidad, además de incertidumbre experimental sobre conteo único, hardware y estabilidad.
La recomendación es corregir los puntos localizados y fortalecer pruebas. No se justifica una reescritura general ni introducir infraestructura desproporcionada.
Tabla final de trazabilidad
ID	Severidad	Componente	Problema	Evidencia	Impacto	Prioridad	Dependencias	Criterio de aceptación

| ID | Severidad | Componente | Problema | Evidencia | Impacto | Prioridad | Dependencias | Criterio de aceptación |
|---|---|---|---|---|---|---|---|---|
| BOV-HIGH-001 | Alta | Backend IoT | Replay `IDLE` libera sesión nueva | B1:76,100; reproducido | Pérdida de control entre sesiones | P0 | — | Replay no modifica reserva actual |
| BOV-HIGH-002 | Alta | Contrato IoT | `H` terminal rechazado | J1:1218; J2:92; B1:86 | Bloqueo de consulta/reconexión | P1 | H001 | Estado válido en todo ciclo |
| BOV-HIGH-003 | Alta | Persistencia | Resultados SQLite no integrados | J2:97; J1:905; F1:928 | Resultado irrecuperable por flujo normal | P1 | H001,H002,H004 | Recuperación tras reinicio |
| BOV-HIGH-004 | Alta | Conteo | SIGKILL produce final válido | J1:750; B2:351; reproducido | Datos parciales tratados como completos | P0 | Contrato app/API | Parcial nunca es final silencioso |
| BOV-HIGH-005 | Alta | Captura | Falta supervisión de progreso | J3:2122,2722 | Sesión congelada | P1 | H004 | Error dentro de plazo definido |
| BOV-HIGH-006 | Alta | Procesos | Cierre incompleto posible | J1:670,1551; J3:2725 | Huérfanos/recursos retenidos | P1 | H004,H005 | Cero procesos previos tras cierre |
| BOV-HIGH-007 | Alta | Tracking | Unicidad no garantizada | J3:1389,1627; prueba sintética | Sobre/subconteo | P1 | H008,M004 | Error medido en escenas etiquetadas |
| BOV-HIGH-008 | Alta | ML | Modelo y métricas no acreditados | J1:50; J3:419,515,652 | Resultado científico no validado | P1 | — | Contrato, hash y evaluación |
| BOV-MED-001 | Media | Historial | Cursor pierde empates | B2:178,189; reproducido | Registros omitidos | P1 | M002 | Todos los IDs paginables |
| BOV-MED-002 | Media | Firestore | Legacy inconsistente | B2:127,183,296; B3:43 | Totales/configuración/retención incoherentes | P2 | M001 | Política canónica consistente |
| BOV-MED-003 | Media | Flutter | Cola sin contexto de sesión | F2:18; F1:725,737 | Acción sobre sesión posterior | P1 | H001,H003 | Invalidación de tareas antiguas |
| BOV-MED-004 | Media | Tracking | Umbral bajo inutilizado | J3:2298,2518,2582 | Fragmentación evitable | P1 | H007,H008 | Asociación con baja confianza |
| BOV-MED-005 | Media | Recursos | Crecimiento no acotado | J3:23,2635; J1:645 | Memoria/disco agotados | P2 | H003 | Límites medidos y retención |
| BOV-MED-006 | Media | BLE/LoRa | Respuesta falsa consume espera | E1:267,283; F1:685 | Denegación de comunicación | P2 | Contrato IoT | Falsa rechazada y recuperación |
| BOV-MED-007 | Media | ESP32 | Brownout desactivado | E1:56,506 | Inestabilidad por alimentación | P1 campo | Hardware | Ensayo eléctrico satisfactorio |
| BOV-MED-008 | Media | DevOps | Despliegue no reproducible | C1:47; J1:47; CI | Divergencia entre instalaciones | P2 | H008 | Build y entorno reproducibles |
| BOV-MED-009 | Media | Usuarios | Autoedición bloquea recuperación | B3:33,63,104; B4:84 | Administrador bloqueado | P2 | — | Recuperación ante fallo parcial |
| BOV-MED-010 | Media | Sesión móvil | Revocación no reconcilia UI | F6:24; F4:155 | Estado autorizado obsoleto | P2 | M003 | Invalidación central probada |
| BOV-LOW-001 | Baja | Android | API de audio incompatible | A1:39,43,51 | Diagnóstico incorrecto | P3 | — | Consulta correcta o diagnóstico retirado |
| BOV-LOW-002 | Baja | Documentación | Contratos históricos ambiguos | README; shared/protocol; ruta duplicada | Errores de mantenimiento | P3 | Correcciones previas | Documentación vigente trazable |