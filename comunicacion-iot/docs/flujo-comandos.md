# Flujo de Comandos (protocolo C1/R1)

Los nombres logicos que usa la app y el codigo que viaja por LoRa son:

| Nombre en la app | Codigo | Efecto en la Jetson |
| --- | --- | --- |
| `ESTADO` | `H` | Estado del receptor (no de la sesion de conteo). |
| `PREPARARCONTEO` | `P` | Valida entorno y deja el equipo listo. |
| `INICIARCONTEO` | `S` | Abre sesion y lanza el worker de deteccion. |
| `DETENERCONTEO` | `T` | Detiene la sesion y firma el resultado final. |
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
- `T` y `R` son los unicos que pueden cerrar una sesion con `count` y
  `completed_at`.
- La Jetson guarda solicitudes y resultados en SQLite, de modo que reenviar una
  trama ya vista devuelve la respuesta almacenada y no vuelve a ejecutar nada.
- El resultado solo se guarda como conteo (`POST /api/ganadero/conteos`) con la
  prueba final firmada de la sesion.
