"""Authenticated LoRa envelopes with durable replay protection."""
import hashlib
import hmac
import os
import re
import sqlite3
import time
import traceback
from pathlib import Path

HEX_ID = re.compile(r"^[a-f0-9]{32}$")
STATES = {"READY", "STARTED", "RUNNING", "STOPPED", "RESULT", "ERROR", "BUSY", "IDLE"}


def load_key():
    value = os.environ.get("IOT_SHARED_SECRET", "")
    if not re.fullmatch(r"[a-fA-F0-9]{64}", value):
        raise ValueError("IOT_SHARED_SECRET must contain 64 hexadecimal characters")
    return bytes.fromhex(value)


def sign(payload, key):
    return hmac.new(key, payload.encode("ascii"), hashlib.sha256).hexdigest()[:32]


def parse_command(frame, key, now=None):
    if not isinstance(frame, str) or len(frame) > 180:
        raise ValueError("invalid envelope")
    parts = frame.split("|")
    if len(parts) != 6:
        raise ValueError("invalid envelope")
    version, request_id, expires, command, session, signature = parts
    if version != "C1" or not HEX_ID.fullmatch(request_id) or not HEX_ID.fullmatch(signature):
        raise ValueError("invalid identifier")
    if command not in {"H", "P", "S", "T", "Q", "R"}:
        raise ValueError("invalid command")
    if (command in {"H", "P"} and session != "-") or (command not in {"H", "P"} and not HEX_ID.fullmatch(session)):
        raise ValueError("invalid session")
    if not expires.isascii() or not expires.isdigit() or len(expires) > 11:
        raise ValueError("invalid expiry")
    now = int(time.time()) if now is None else now
    if not now - 5 <= int(expires) <= now + 65:
        raise ValueError("expired command or unsynchronized clock")
    expected = sign("|".join(parts[:-1]), key)
    if not hmac.compare_digest(expected, signature):
        raise ValueError("invalid signature")
    return request_id, int(expires), command, session


def response_frame(request_id, session, status, count, completed_at, key, now=None):
    if status not in STATES:
        status = "ERROR"
    count_text = str(count) if type(count) is int and 0 <= count <= 1000000 else "-"
    completed = str(int(completed_at)) if completed_at and status in {"RESULT", "STOPPED"} else "-"
    timestamp = int(time.time()) if now is None else now
    payload = f"R1|{request_id}|{session}|{status}|{count_text}|{timestamp}|{completed}"
    return payload + "|" + sign(payload, key)


class SecureProtocol:
    def __init__(self, key=None, path=None):
        self.key = load_key() if key is None else key
        state_dir = Path(os.environ.get("BOVISENSE_STATE_DIR", "~/.local/state/bovisense")).expanduser()
        path = Path(path or state_dir / "protocol.sqlite3")
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.db = sqlite3.connect(str(path))
        os.chmod(path, 0o600)
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("CREATE TABLE IF NOT EXISTS requests (id TEXT PRIMARY KEY, frame TEXT NOT NULL, expires INTEGER NOT NULL, response TEXT)")
        self.db.execute("CREATE TABLE IF NOT EXISTS results (session TEXT PRIMARY KEY, status TEXT, count INTEGER, completed INTEGER)")
        self.db.commit()

    def handle(self, frame, execute, now=None):
        request_id, expires, command, session = parse_command(frame, self.key, now)
        current = int(time.time()) if now is None else now
        with self.db:
            self.db.execute("DELETE FROM requests WHERE expires < ?", (current - 120,))
            previous = self.db.execute("SELECT frame, response FROM requests WHERE id=?", (request_id,)).fetchone()
            if previous:
                if previous[0] != frame:
                    raise ValueError("identifier reused")
                cached_status = previous[1].split("|")[3] if previous[1] else "ERROR"
                print(f"[Seguro] Respuesta antirreplay reutilizada id={request_id[:8]} status={cached_status}")
                return previous[1] or response_frame(request_id, session, "ERROR", None, None, self.key, current)
            self.db.execute("INSERT INTO requests VALUES (?, ?, ?, NULL)", (request_id, frame, expires))
        try:
            fields = execute(command, session)
        except Exception as exc:
            print(f"[Seguro] Fallo al ejecutar cmd={command} id={request_id[:8]}: {type(exc).__name__}: {exc}")
            traceback.print_exc()
            fields = {"status": "ERROR"}
        response = response_frame(request_id, session, fields.get("status", "ERROR"), fields.get("count"), fields.get("completed"), self.key, now)
        with self.db:
            self.db.execute("UPDATE requests SET response=? WHERE id=?", (response, request_id))
        return response

    def save_result(self, result):
        with self.db:
            self.db.execute("INSERT OR REPLACE INTO results VALUES (?, ?, ?, ?)",
                            (result["session"], result["status"], result.get("count"), result["completed"]))

    def result(self, session):
        row = self.db.execute("SELECT status, count, completed FROM results WHERE session=?", (session,)).fetchone()
        return dict(zip(("status", "count", "completed"), row)) if row else None

    def close(self):
        self.db.close()
