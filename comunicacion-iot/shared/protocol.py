"""Protocolo JSON seguro para Wi-Fi <-> ESP32 <-> LoRa <-> Jetson."""

from __future__ import annotations

import hashlib
import json
import time
import uuid
from dataclasses import dataclass
from typing import Any

try:
    from .constants import (
        ACK,
        ALLOWED_COMMANDS,
        ERROR_COMMAND_NOT_ALLOWED,
        ERROR_INVALID_CHECKSUM,
        ERROR_INVALID_JSON,
        ERROR_INVALID_SCHEMA,
        ERROR_SEQUENCE_INVALID,
        NACK,
    )
except ImportError:
    from constants import (  # type: ignore
        ACK,
        ALLOWED_COMMANDS,
        ERROR_COMMAND_NOT_ALLOWED,
        ERROR_INVALID_CHECKSUM,
        ERROR_INVALID_JSON,
        ERROR_INVALID_SCHEMA,
        ERROR_SEQUENCE_INVALID,
        NACK,
    )

Message = dict[str, Any]

CHECKSUM_FIELDS: tuple[str, ...] = (
    "message_id",
    "sequence",
    "source",
    "target",
    "command",
    "payload",
    "timestamp",
)


@dataclass(frozen=True)
class ProtocolError(Exception):
    """Error controlado del protocolo."""

    code: str
    message: str

    def __str__(self) -> str:
        return f"{self.code}: {self.message}"


def _canonical_payload(data: Any) -> str:
    """Convierte datos JSON a una representacion estable para checksum."""

    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def calculate_checksum(message: Message) -> str:
    """Calcula SHA-256 sobre los campos definidos del mensaje."""

    checksum_input = {field: message.get(field) for field in CHECKSUM_FIELDS}
    raw = _canonical_payload(checksum_input).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def build_message(
    *,
    source: str,
    target: str,
    command: str,
    sequence: int,
    payload: dict[str, Any] | None = None,
    message_id: str | None = None,
    timestamp: float | None = None,
) -> Message:
    """Construye un mensaje valido con checksum y lista blanca."""

    if command not in ALLOWED_COMMANDS:
        raise ProtocolError(ERROR_COMMAND_NOT_ALLOWED, f"Comando no permitido: {command}")
    if sequence < 0:
        raise ProtocolError(ERROR_SEQUENCE_INVALID, "La secuencia debe ser >= 0")

    message: Message = {
        "message_id": message_id or str(uuid.uuid4()),
        "sequence": sequence,
        "source": source,
        "target": target,
        "command": command,
        "payload": payload or {},
        "timestamp": timestamp if timestamp is not None else time.time(),
    }
    message["checksum"] = calculate_checksum(message)
    return message


def validate_message(message: Message) -> None:
    """Valida estructura, tipos, lista blanca y checksum."""

    required = set(CHECKSUM_FIELDS) | {"checksum"}
    missing = sorted(required - set(message))
    if missing:
        raise ProtocolError(ERROR_INVALID_SCHEMA, f"Campos faltantes: {', '.join(missing)}")
    if not isinstance(message["sequence"], int) or message["sequence"] < 0:
        raise ProtocolError(ERROR_SEQUENCE_INVALID, "Secuencia invalida")
    if message["command"] not in ALLOWED_COMMANDS:
        raise ProtocolError(ERROR_COMMAND_NOT_ALLOWED, f"Comando no permitido: {message['command']}")
    if not isinstance(message["payload"], dict):
        raise ProtocolError(ERROR_INVALID_SCHEMA, "payload debe ser un objeto JSON")

    expected = calculate_checksum(message)
    if message["checksum"] != expected:
        raise ProtocolError(ERROR_INVALID_CHECKSUM, "Checksum no coincide")


def serialize_message(message: Message) -> str:
    """Serializa un mensaje validado a JSON compacto."""

    validate_message(message)
    return _canonical_payload(message)


def deserialize_message(raw: str) -> Message:
    """Deserializa y valida un mensaje JSON."""

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ProtocolError(ERROR_INVALID_JSON, "JSON invalido") from exc
    if not isinstance(data, dict):
        raise ProtocolError(ERROR_INVALID_SCHEMA, "El mensaje debe ser un objeto JSON")
    validate_message(data)
    return data


def build_response(
    request: Message,
    *,
    status: str = ACK,
    payload: dict[str, Any] | None = None,
    error_code: str | None = None,
    error_message: str | None = None,
) -> Message:
    """Construye respuesta estandar ACK/NACK para una solicitud."""

    if status not in (ACK, NACK):
        raise ProtocolError(ERROR_INVALID_SCHEMA, "status debe ser ACK o NACK")
    response_payload: dict[str, Any] = {
        "status": status,
        "request_message_id": request.get("message_id"),
        "data": payload or {},
    }
    if error_code:
        response_payload["error"] = {"code": error_code, "message": error_message or error_code}

    response: Message = {
        "message_id": str(uuid.uuid4()),
        "sequence": int(request.get("sequence", 0)) + 1,
        "source": request.get("target", "unknown_target"),
        "target": request.get("source", "unknown_source"),
        "command": request.get("command", "PING"),
        "payload": response_payload,
        "timestamp": time.time(),
    }
    response["checksum"] = calculate_checksum(response)
    return response


def build_error_response(
    request: Message | None,
    *,
    error_code: str,
    error_message: str,
    source: str = "jetson_orin_nano",
    target: str = "esp32_bridge",
) -> Message:
    """Construye NACK aunque la solicitud original no sea confiable."""

    fallback = request or {
        "message_id": None,
        "sequence": 0,
        "source": target,
        "target": source,
        "command": "PING",
    }
    return build_response(
        fallback,
        status=NACK,
        payload={},
        error_code=error_code,
        error_message=error_message,
    )

