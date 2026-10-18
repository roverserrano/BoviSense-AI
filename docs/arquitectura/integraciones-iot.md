# Integración IoT: app, ESP32, LoRa, Jetson y backend

Documenta únicamente lo que el repositorio evidencia. Los comportamientos que
requieren hardware real están marcados como `PENDIENTE DE VERIFICACIÓN`.

## 1. Camino completo de un comando

```text
[1] App  --HTTP-->  Backend        (pide ticket C1 firmado)
[2] App  --BLE-->   ESP32          (~C1...\n en fragmentos)
[3] ESP32 --LoRa--> Jetson         (trama C1 completa)
[4] Jetson          autentica, verifica replay y ejecuta
[5] Jetson --LoRa--> ESP32         (trama R1 firmada)
[6] ESP32 --BLE-->  App            (notificacion con R1)
[7] App  --HTTP-->  Backend        (verifica HMAC de la R1)
[8] Backend         guarda sesion, libera lease y responde a la app
```

Evidencia por tramo: `frontend/lib/data/services/esp32_ble_bridge_service.dart`
(`sendCommand`), `backend/src/services/iotProtocol.js:21-28`,
`comunicacion-iot/esp32/.../*.ino:245-260`,
`jetson/secure_protocol.py:26-48`, `backend/src/services/iotService.js:69-103`.

## 2. Tramo 1 y 7 — App ↔ Backend (HTTP)

| Aspecto | Contrato | Evidencia |
|---------|----------|-----------|
| Emisión | `POST /api/ganadero/iot/comandos {command, request_id}` → `{frame, request_id, session_id, command}` | `docs/arquitectura/api-http.md`; `backend/src/services/iotService.js:11-67` |
| Verificación | `POST /api/ganadero/iot/respuestas {frame}` → `{status, session, count, device_id, proof}` | `backend/src/services/iotService.js:69-103` |
| Firma | HMAC-SHA256 sobre el payload C1/R1, truncado a 16 bytes (32 hex) | `backend/src/services/iotProtocol.js:17-19` |
| Vigencia del ticket | 60 s (`expires = now + 60`) | `backend/src/services/iotService.js:61` |
| Reutilización | Un `request_id` repetido con el mismo comando y sesión devuelve el mismo ticket; con datos distintos responde `409` | `backend/src/services/iotService.js:20-28` |
| Contención del dispositivo | Lease de 900 s por usuario; otro usuario recibe `409` | `backend/src/services/iotService.js:37-51` |

## 3. Tramo 2 y 6 — App ↔ ESP32 (BLE)

| Aspecto | Contrato | Evidencia |
|---------|----------|-----------|
| Nombre anunciado | `BoviSense-Bridge` | `bridge_hotspot_lora_discovery.ino:31`; `esp32_ble_bridge_service.dart` (`deviceName`) |
| Servicio | `7d2f0001-1f3b-4a9b-8f2a-b05e00000001` | `.ino:32` |
| Characteristic RX (app → puente) | `7d2f0002-…` | `.ino:33` |
| Characteristic TX (notificaciones) | `7d2f0003-…` | `.ino:34` |
| Framing | `~<trama>\n`; la app escribe en fragmentos de 18 bytes y el puente rearma por el delimitador | `esp32_ble_bridge_service.dart` (`_receive`, escritura por `offset += 18`) |
| Filtrado de respuestas | La app solo acepta `R1` con el `request_id` vigente; otros `R1` se registran como ignorados | `esp32_ble_bridge_service.dart` (`_receive`) |
| Trama de error del puente | `B0\|<request_id>\|ERROR\|<reason>` | `.ino:161` |

Razones de error emitidas por el firmware y cómo las traduce la app
(`.ino:161,178,250,328`; `esp32_ble_bridge_service.dart`, `_bridgeErrorMessage`):

| `reason` | Significado operativo | Mensaje mostrado |
|----------|----------------------|------------------|
| `lora_not_ready` | El radio del puente aún no inicializó | "El puente BLE esta conectado, pero LoRa aun no esta listo." |
| `empty_lora_payload` | Comando vacío | "El puente recibio un comando vacio." |
| `lora_payload_too_long` | Supera el máximo permitido | "El comando supera el tamano permitido por LoRa." |
| `lora_send_failed` | Falló el envío por radio | "El puente no pudo enviar el comando por LoRa." |
| `bridge_busy_waiting_lora` | Hay una respuesta anterior pendiente | "El puente esta esperando una respuesta anterior de Jetson." |
| `jetson_response_timeout` | No llegó R1 en 22 s | "El puente envio el comando, pero Jetson no respondio por LoRa." |

## 4. Tramo 3 y 5 — ESP32 ↔ Jetson (LoRa)

### Formato de trama C1 (comando, backend → Jetson)

```text
C1|request_id|expires|command|session_id|mac
```

| Campo | Validación en la Jetson | Evidencia |
|-------|-------------------------|-----------|
| `C1` | Versión exacta | `jetson/secure_protocol.py:33` |
| `request_id` | 32 hex minúsculas | `jetson/secure_protocol.py:11,33` |
| `expires` | Entero; debe estar entre `now-5` y `now+65` segundos | `jetson/secure_protocol.py:40-44` |
| `command` | Uno de `H`, `P`, `S`, `T`, `Q`, `R` | `jetson/secure_protocol.py:35` |
| `session_id` | `-` para `H` y `P`; 32 hex para el resto | `jetson/secure_protocol.py:37` |
| `mac` | HMAC-SHA256 truncado, comparado en tiempo constante | `jetson/secure_protocol.py:45-48` |
| Longitud | Máximo 180 caracteres | `jetson/secure_protocol.py:28` |

### Formato de trama R1 (respuesta, Jetson → backend)

```text
R1|request_id|session_id|status|count|timestamp|completed_at|mac
```

- `count`: `-` cuando no hay conteo confiable
  (`jetson/secure_protocol.py:53`).
- `completed_at`: solo en `RESULT` o `STOPPED`
  (`jetson/secure_protocol.py:54`).
- `status`: `READY`, `STARTED`, `RUNNING`, `STOPPED`, `RESULT`, `ERROR`, `BUSY`,
  `IDLE` (`backend/src/services/iotProtocol.js:5`,
  `jetson/secure_protocol.py:12`).
- El backend revalida el mismo contrato y rechaza tramas de más de 200
  caracteres o con caracteres no imprimibles
  (`backend/src/services/iotProtocol.js:30-42`).

### Parámetros de radio acordados

| Parámetro | Valor | Evidencia |
|-----------|-------|-----------|
| Frecuencia | 433 MHz | `.ino:39`; constante de radio del receptor |
| SyncWord | `0xF3` | `.ino:40` |
| SF / BW / CR / CRC | SF7 / 125 kHz / 4-5 / activado | `AGENTS.md` sección 4 (verificado en log del receptor) |
| Potencia TX | 17 dBm en la Jetson | `AGENTS.md` sección 4 |
| Pines del puente | SS 5, RST 14, DIO0 4 | `.ino:36-38` |
| Longitud máxima de payload | 220 bytes en el puente | `.ino:46` |
| Espera de respuesta | 22 s en el puente, 25 s en la app | `.ino:47`; `esp32_ble_bridge_service.dart` |

## 5. Tramo 4 — Jetson: ejecución y sesión

| Comando | Etiqueta | Efecto verificado en el código | Evidencia |
|---------|----------|-------------------------------|-----------|
| `H` | ESTADO | Devuelve estado del receptor sin sesión; `IDLE` si no hay sesión | `jetson/lora_jetson_rx.py:754-780` |
| `P` | PREPARARCONTEO | Valida entorno del worker y responde `READY` | `jetson/lora_jetson_rx.py:584-601` |
| `S` | INICIARCONTEO | Abre sesión con el `session_id` del backend y lanza el worker | `jetson/lora_jetson_rx.py:602-685` |
| `T` | DETENERCONTEO | Detiene el worker, firma el resultado; `IDLE` si no hay sesión | `jetson/lora_jetson_rx.py:686-753` |
| `Q` | ESTADOCONTEO | Estado de la sesión; `IDLE` si el equipo no la conoce | `jetson/lora_jetson_rx.py:754-780` |
| `R` | RESULTADOCONTEO | Resultado firmado si existe; `IDLE` si no hay sesión ni resultado | `jetson/lora_jetson_rx.py:781-810` |

Antirreplay (`jetson/secure_protocol.py:60-96`): cada `request_id` se inserta en
SQLite antes de ejecutar; si vuelve a llegar la misma trama, se devuelve la
respuesta almacenada y no se reejecuta. Las solicitudes expiradas se purgan a los
120 s (`jetson/secure_protocol.py:77`).

Integración con el worker:

```text
run_bovino.py  --stdout-->  COUNT_UPDATE / COUNT_FINAL / WORKER_STATUS
               --archivos-->  BOVISENSE_STATUS_FILE, BOVISENSE_RESULT_FILE
lora_jetson_rx.py lee el log y los JSON para construir status/count/completed
```

Evidencia: `jetson/run_bovino.py:26-28,103-174`;
`jetson/lora_jetson_rx.py:871-903,937-961`.

## 6. Tabla de tiempos y límites (resumen)

| Límite | Valor | Dónde |
|--------|-------|-------|
| Vigencia del ticket C1 | 60 s | `backend/src/services/iotService.js:61` |
| Tolerancia de reloj de la Jetson | `-5 s` / `+65 s` | `jetson/secure_protocol.py:41-44` |
| Lease del dispositivo | 900 s | `backend/src/services/iotService.js:51` |
| Espera LoRa del puente | 22 s | `.ino:47` |
| Espera de R1 en la app | 25 s | `esp32_ble_bridge_service.dart` |
| Sondeo de conteo en la app | 4 s (con retroceso hasta 12 s) | `esp32_ble_bridge_service.dart` |
| Duración máxima de sesión | 600 s | `jetson/lora_jetson_rx.py:61` |
| Espera al detener el worker | 8 s antes de SIGKILL | `jetson/lora_jetson_rx.py:62` |
| Purga de solicitudes en SQLite | 120 s | `jetson/secure_protocol.py:77` |

## 7. PENDIENTE DE VERIFICACIÓN en esta integración

- Que el firmware grabado en el prototipo sea exactamente el sketch del
  repositorio (comparar versión por puerto serie).
- Latencias reales por tramo y tasa de éxito bajo repetición, interferencia y
  distancia (`AGENTS.md` sección 6.4).
- Que la R1 llegue al teléfono en el 100 % de los casos y que el reintento del
  sondeo no genere duplicados en campo.
- Comportamiento con el dron en movimiento real (el GMC está implementado, pero
  validado solo con datos sintéticos en esta revisión).

## 8. Evidencia

- `frontend/lib/data/services/esp32_ble_bridge_service.dart`
- `backend/src/services/iotProtocol.js`, `backend/src/services/iotService.js`
- `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/bridge_hotspot_lora_discovery.ino`
- `jetson/secure_protocol.py`, `jetson/lora_jetson_rx.py`, `jetson/run_bovino.py`
- `comunicacion-iot/docs/{flujo-comandos,protocolo-lora,arquitectura-comunicacion}.md`
