# Flujo de Comandos (protocolo C1/R1)

Los nombres logicos que usa la app y el codigo que viaja por LoRa son:

| Nombre en la app | Codigo | Efecto en la Jetson |
| --- | --- | --- |
| `ESTADO` | `H` | Estado del receptor (no de la sesion de conteo). |
| `PREPARARCONTEO` | `P` | Valida entorno y deja el equipo listo. |
| `INICIARCONTEO` | `S` | Abre sesion y lanza el worker de deteccion. |
| `DETENERCONTEO` | `T` | Solicita detener; solo entrega final valido si el worker confirma exito y el resultado se guarda. |
| `ESTADOCONTEO` | `Q` | Consulta el avance; no cierra la sesion. |
| `RESULTADOCONTEO` | `R` | Recupera el ultimo resultado firmado de la sesion. |

## Trama de comando `C1`

```text
C1|request_id|expires|command|session_id|mac
```

- `request_id`: 32 hexadecimales generados por la app.
- `expires`: epoch en segundos; la ventana nominal es de 60 s.
- `command`: uno de `H`, `P`, `S`, `T`, `Q`, `R`.
- `session_id`: `-` para `H` y `P`; 32 hexadecimales para el resto.
- `mac`: HMAC-SHA256 truncado a 16 bytes (32 hexadecimales).

## Trama de respuesta `R1`

```text
R1|request_id|session_id|status|count|timestamp|completed_at|mac
```

- `count`: `-` mientras no exista un conteo confiable.
- `completed_at`: `-` salvo en `RESULT` y `STOPPED`.
- Estados: `READY`, `STARTED`, `RUNNING`, `STOPPED`, `RESULT`, `ERROR`,
  `BUSY`, `IDLE`.

## Reglas de sesion

- `S` crea la sesion en `IotSessions` y reserva el dispositivo en `IotDevices`
  (`lease_until`). Si el mismo usuario vuelve a iniciar, el backend convierte la
  peticion en `Q` en lugar de abrir otra sesion.
- Si otra cuenta intenta usar el equipo, recibe `409`; si intenta operar una
  sesion ajena, `403`.
- `Q` tambien puede descubrir un final (`STOPPED`) si el worker ya termino.
  `T`/`R`/`Q` pueden entregar prueba final. `H`/`P` no llevan sesion ni conteo.
- `STARTED` confirma el lanzamiento del proceso, no una primera inferencia.
  Cero frames, error de camara/inferencia, agotamiento del tiempo de sesion,
  salida forzada o persistencia fallida producen `ERROR` sin conteo guardable.
- La Jetson guarda solicitudes y resultados en SQLite, de modo que reenviar una
  trama ya vista devuelve la respuesta almacenada y no vuelve a ejecutar nada.
- El resultado solo se guarda como conteo (`POST /api/ganadero/conteos`) con la
  prueba final firmada de la sesion.
- Las consultas generales guardan la reserva existente al emitir el ticket.
  Una respuesta `H/IDLE` anterior a otra sesion no libera la reserva nueva.
  Las respuestas de sesion verificadas registran el tiempo de emision del
  ticket; una respuesta anterior no reemplaza un estado mas reciente. Un
  H/IDLE antiguo tampoco libera esa misma reserva si ya se verifico una
  confirmacion posterior de la sesion.

## Perdida de mensajes y reconexion

1. El ESP32 transmite el C1 original y puede repetirlo a los 6 y 12 segundos,
   con un maximo de tres intentos y un plazo total de 22 segundos.
2. Jetson devuelve su respuesta cacheada al recibir el mismo C1: no vuelve a
   iniciar/detener el worker. Los reintentos no cambian expiracion, firma ni ID.
3. El puente reenvia tambien la segunda R1 de Jetson si pertenece al mismo
   request-id y sesion. La app puede reconstruir una primera copia incompleta.
4. Tras agotar el plazo se informa `B0|id|ERROR|jetson_response_timeout`.
   Esto no demuestra que la orden no se ejecuto. Consultar `Q`/`R` con un
   ticket nuevo antes de repetir una accion.
5. Al desconectar se abandonan la transaccion y los fragmentos BLE del puente,
   pero no se inventa un `T`. La Jetson conserva su limite independiente de
   600 s. Al reconectar, `Q` sin session_id explicito usa la sesion propia
   que conserva el backend; si no existe se permite iniciar una nueva.
