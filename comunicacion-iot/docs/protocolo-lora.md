# Protocolo LoRa

## Encabezado fisico LoRa

Para compatibilidad con los codigos base:

```text
byte 0: recipient
byte 1: sender
bytes restantes: JSON UTF-8
```

Direcciones:

- ESP32: `0xBB`
- Jetson: `0xCC`
- Broadcast: `0xFF`

## JSON

Campos obligatorios:

- `message_id`
- `sequence`
- `source`
- `target`
- `command`
- `payload`
- `timestamp`
- `checksum`

## Checksum

SHA-256 sobre serializacion JSON canonica de:

```text
message_id, sequence, source, target, command, payload, timestamp
```

## Respuesta

El Jetson responde con `ACK` o `NACK` dentro de `payload.status`.

