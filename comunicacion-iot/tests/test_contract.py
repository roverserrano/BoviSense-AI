"""Contrato real Node -> C++ -> Python y Python -> C++ -> Node, sin equipos/red."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("protocol", ROOT / "jetson/secure_protocol.py")
PROTOCOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROTOCOL)
KEY = bytes.fromhex("11" * 32)  # Clave publica exclusiva de prueba.
NOW = 2000000000


class ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.directory.cleanup)
        cls.binary = str(Path(cls.directory.name) / "bridge-tests")
        subprocess.run(["g++", "-std=c++11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                        str(ROOT / "comunicacion-iot/tests/test_bridge_protocol.cpp"), "-o", cls.binary], check=True)

    def test_firmware_transport_logic(self):
        subprocess.run([self.binary], check=True, capture_output=True, text=True)

    def test_six_commands_and_all_receiver_states_across_three_languages(self):
        source = """
const p = require('./backend/src/services/iotProtocol');
const key = Buffer.alloc(32, 17);
console.log(JSON.stringify(Object.values(p.COMMANDS).map((command, i) => {
 const requestId = (i + 1).toString(16).repeat(32);
 const sessionId = ['H','P'].includes(command) ? '-' : 'a'.repeat(32);
 return p.commandFrame({requestId, sessionId, command, expires: 2000000060}, key);
})));
"""
        frames = json.loads(subprocess.run(["node", "-e", source], cwd=ROOT, check=True, capture_output=True, text=True).stdout)
        responses, vectors = [], []
        for frame in frames:
            request, _, command, session = PROTOCOL.parse_command(frame, KEY, NOW)
            statuses = ["READY", "IDLE", "RUNNING"] if command in {"H", "P"} else sorted(PROTOCOL.STATES)
            for status in statuses:
                count = 27 if session != "-" and status in {"RUNNING", "STOPPED", "RESULT"} else None
                completed = NOW if status in {"STOPPED", "RESULT"} else None
                reply = PROTOCOL.response_frame(request, session, status, count, completed, KEY, NOW)
                vectors.append(frame + "\t" + reply)
                responses.append(reply)
        subprocess.run([self.binary, "--frames"], input="\n".join(vectors), check=True, capture_output=True, text=True)
        node = """
const fs = require('node:fs');
const {responseFrame} = require('./backend/src/services/iotProtocol');
const frames = JSON.parse(fs.readFileSync(0, 'utf8'));
for (const frame of frames) responseFrame(frame, Buffer.alloc(32, 17));
console.log(frames.length);
"""
        result = subprocess.run(["node", "-e", node], cwd=ROOT, input=json.dumps(responses), check=True, capture_output=True, text=True)
        self.assertEqual(int(result.stdout), len(responses))

    def test_retried_command_never_executes_twice_on_jetson(self):
        with tempfile.TemporaryDirectory() as directory:
            protocol = PROTOCOL.SecureProtocol(KEY, Path(directory) / "state.db")
            self.addCleanup(protocol.close)
            for index, command in enumerate("HPSTQR", 1):
                request = format(index, "x") * 32
                session = "-" if command in "HP" else "a" * 32
                payload = f"C1|{request}|{NOW + 60}|{command}|{session}"
                frame = payload + "|" + PROTOCOL.sign(payload, KEY)
                executions = []
                def execute(code, session):
                    executions.append(code)
                    return {"status": "RUNNING"}
                replies = [protocol.handle(frame, execute, NOW + delay) for delay in (0, 6, 12)]
                self.assertEqual(executions, [command])
                self.assertEqual(len(set(replies)), 1)


if __name__ == "__main__":
    unittest.main()
