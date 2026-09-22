import importlib.util
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
from secure_protocol import SecureProtocol, parse_command, response_frame, sign

KEY = bytes.fromhex("11" * 32)
ID = "a" * 32
NOW = 2000000000


def command(code="S", session=ID):
    payload = f"C1|{ID}|{NOW + 60}|{code}|{session}"
    return payload + "|" + sign(payload, KEY)


def live_command(code="P", session="-"):
    now = int(__import__("time").time())
    request_id = "b" * 32
    payload = f"C1|{request_id}|{now + 60}|{code}|{session}"
    return payload + "|" + sign(payload, KEY), request_id


class FakeRadio:
    def __init__(self):
        self.sent = []

    def transmit_text(self, text):
        self.sent.append(text)
        return True


class ProtocolTests(unittest.TestCase):
    def test_authentication_expiry_and_bounds(self):
        self.assertEqual(parse_command(command(), KEY, NOW), (ID, NOW + 60, "S", ID))
        for frame in [command().replace("|S|", "|T|"), "BRIDGE|1|INICIARCONTEO", command() + "\n"]:
            with self.assertRaises(ValueError):
                parse_command(frame, KEY, NOW)
        with self.assertRaises(ValueError):
            parse_command(command(), KEY, NOW + 100)

    def test_replay_is_durable_and_never_reexecutes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "protocol.db"
            calls = []
            protocol = SecureProtocol(KEY, path)
            execute = lambda code, session: calls.append(code) or {"status": "RESULT", "count": 27, "completed": NOW}
            first = protocol.handle(command(), execute, NOW)
            self.assertEqual(first, protocol.handle(command(), execute, NOW))
            protocol.close()
            protocol = SecureProtocol(KEY, path)
            self.assertEqual(first, protocol.handle(command(), execute, NOW))
            self.assertEqual(calls, ["S"])
            protocol.close()

    def test_response_is_signed_and_bounded(self):
        frame = response_frame(ID, ID, "RESULT", 27, NOW - 1, KEY, NOW)
        self.assertEqual(len(frame.split("|")), 8)
        self.assertLessEqual(len(frame), 200)

    def test_execution_error_is_logged_and_cached(self):
        with tempfile.TemporaryDirectory() as directory:
            protocol = SecureProtocol(KEY, Path(directory) / "protocol.db")
            output = StringIO()
            errors = StringIO()
            calls = []

            def fail(code, session):
                calls.append(code)
                raise RuntimeError("worker state failed")

            with redirect_stdout(output), redirect_stderr(errors):
                first = protocol.handle(command(), fail, NOW)
                second = protocol.handle(command(), fail, NOW)
            self.assertEqual(first, second)
            self.assertEqual(calls, ["S"])
            self.assertIn("|ERROR|-|", first)
            self.assertIn("Fallo al ejecutar", output.getvalue())
            self.assertIn("antirreplay reutilizada", output.getvalue())
            self.assertIn("RuntimeError: worker state failed", errors.getvalue())
            protocol.close()


class ControllerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.modules.setdefault("spidev", types.SimpleNamespace())
        spec = importlib.util.spec_from_file_location("receiver_test", Path(__file__).with_name("lora_jetson_rx.py"))
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def test_active_session_never_returns_previous_result(self):
        controller = self.module.CountSessionController()
        controller.last_result = {"session": "old", "count": 99, "status": "STOPPED"}
        controller.session = {"id": ID, "status": "RUNNING", "start_time": 0, "count": 3}
        with patch.object(controller, "sync_worker_state"), patch.object(controller, "is_worker_alive", return_value=True):
            result = controller.result()
        self.assertEqual(result["status"], "RUNNING")
        self.assertEqual(result["session"], ID)

    def test_stop_does_not_reuse_result_from_another_session(self):
        controller = self.module.CountSessionController()
        controller.last_result = {
            "session": "b" * 32,
            "count": 99,
            "status": "STOPPED",
            "completed": NOW - 60,
        }
        controller.session = None
        with patch.object(controller, "sync_worker_state"), patch.object(controller, "is_worker_alive", return_value=False):
            result = controller.stop(requested_session=ID)
        # Sin sesion en el equipo no es un conflicto: es un equipo inactivo.
        self.assertEqual(result["status"], "IDLE")
        self.assertEqual(result["detail"], "no_active_session")
        self.assertEqual(result["count"], "unknown")

    def test_result_does_not_reuse_result_from_another_session(self):
        controller = self.module.CountSessionController()
        controller.last_result = {
            "session": "b" * 32,
            "count": 99,
            "status": "STOPPED",
            "completed": NOW - 60,
        }
        controller.session = None
        with patch.object(controller, "sync_worker_state"), patch.object(controller, "is_worker_alive", return_value=False):
            result = controller.result(requested_session=ID)
        self.assertEqual(result["status"], "IDLE")
        self.assertEqual(result["detail"], "no_active_session")
        self.assertEqual(result["count"], "unknown")

    def test_queries_without_session_are_idle_not_error(self):
        # Caso real: la Jetson se reinicio, el backend conservaba el session_id
        # anterior y respondia ERROR, que la app mostraba como falla de equipo.
        for method in ("status", "stop", "result"):
            controller = self.module.CountSessionController()
            controller.session = None
            controller.last_result = None
            with patch.object(controller, "sync_worker_state"), patch.object(controller, "is_worker_alive", return_value=False):
                result = getattr(controller, method)(requested_session=ID)
            self.assertEqual(result["status"], "IDLE", method)
            self.assertEqual(result["detail"], "no_active_session", method)
            self.assertEqual(result["count"], "unknown", method)

    def test_status_without_requested_session_does_not_leak_old_count(self):
        controller = self.module.CountSessionController()
        controller.session = None
        controller.last_result = {"session": ID, "count": 99, "status": "STOPPED"}
        with patch.object(controller, "sync_worker_state"), patch.object(controller, "is_worker_alive", return_value=False):
            result = controller.status()
        self.assertEqual(result["status"], "IDLE")
        self.assertEqual(result["count"], "unknown")

    def test_query_of_another_active_session_still_reports_mismatch(self):
        controller = self.module.CountSessionController()
        controller.session = {
            "id": "b" * 32,
            "status": "RUNNING",
            "start_time": 0,
            "count": 3,
        }
        controller.last_result = None
        with patch.object(controller, "sync_worker_state"), patch.object(controller, "is_worker_alive", return_value=True):
            result = controller.status(requested_session=ID)
        self.assertEqual(result["status"], "ERROR")
        self.assertEqual(result["detail"], "session_mismatch")
        self.assertEqual(result["count"], "unknown")

    def test_worker_launch_does_not_use_a_shell(self):
        self.assertIsInstance(self.module.CountSessionController().build_shell_command(), list)

    def test_secure_lora_command_sends_signed_r1_once(self):
        with tempfile.TemporaryDirectory() as directory:
            controller = self.module.CountSessionController()
            calls = []

            def prepare():
                calls.append("prepare")
                return {"status": "READY", "count": "unknown"}

            controller.prepare = prepare
            previous_controller = self.module.count_controller
            previous_protocol = self.module.secure_protocol
            try:
                self.module.count_controller = controller
                self.module.secure_protocol = SecureProtocol(KEY, Path(directory) / "protocol.db")
                frame, request_id = live_command("P", "-")
                radio = FakeRadio()

                self.module.maybe_reply_to_command(radio, frame)
                self.module.maybe_reply_to_command(radio, frame)

                self.assertEqual(calls, ["prepare"])
                self.assertEqual(len(radio.sent), self.module.STATUS_REPLY_REPEATS * 2)
                first = radio.sent[0]
                self.assertTrue(first.startswith(f"R1|{request_id}|-|READY|-|"))
                self.assertEqual(first, radio.sent[-1])
            finally:
                if self.module.secure_protocol is not None:
                    self.module.secure_protocol.close()
                self.module.count_controller = previous_controller
                self.module.secure_protocol = previous_protocol

    def test_secure_start_uses_backend_session_id(self):
        session = "c" * 32
        controller = self.module.CountSessionController()
        calls = []

        def start(session_id=None):
            calls.append(session_id)
            return {"status": "STARTED", "count": "unknown"}

        controller.start = start
        previous_controller = self.module.count_controller
        try:
            self.module.count_controller = controller
            result = self.module.execute_secure_command("S", session)
            self.assertEqual(calls, [session])
            self.assertEqual(result["status"], "STARTED")
        finally:
            self.module.count_controller = previous_controller


class RadioModeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = ControllerTests.module

    class FakeSpi:
        def __init__(self, block_standby=False, drop_payload=False, stale_tx_done=False):
            self.regs = {0x01: 0x8D, 0x42: 0x12}
            self.writes = []
            self.block_standby = block_standby
            self.drop_payload = drop_payload
            self.stale_tx_done = stale_tx_done

        def xfer2(self, values):
            address = values[0] & 0x7F
            if values[0] & 0x80:
                value = values[1]
                self.writes.append((address, value))
                current = self.regs.get(0x01, 0)
                if address == 0x01 and (current & 0x80) != (value & 0x80) and current & 0x07:
                    return [0] * len(values)
                if address == 0x01 and value == 0x89 and self.block_standby:
                    return [0] * len(values)
                if address == 0x12:
                    self.regs[address] = 0x08 if self.stale_tx_done else self.regs.get(address, 0) & ~value
                    if self.drop_payload and self.regs.get(0x22, 0):
                        self.regs[0x22] = 0
                else:
                    self.regs[address] = value
                if address == 0x01 and value == 0x8B:
                    self.regs[0x12] = 0x08
                return [0] * len(values)
            return [0, self.regs.get(address, 0)] + [0] * (len(values) - 2)

        def close(self):
            pass

    def radio(self, block_standby=False, drop_payload=False, stale_tx_done=False):
        spi = self.FakeSpi(block_standby, drop_payload, stale_tx_done)
        with patch.object(self.module.spidev, "SpiDev", return_value=spi, create=True):
            radio = self.module.SX1278Receiver()
        return radio

    def test_configuration_from_active_lora_keeps_lora_bit_during_sleep(self):
        radio = self.radio()
        self.assertTrue(radio.configure_lora_registers())
        mode_writes = [value for address, value in radio.spi.writes if address == 0x01]
        self.assertEqual(mode_writes, [0x88, 0x89])
        self.assertEqual(radio.current_mode(), self.module.MODE_STDBY)

    def test_configuration_from_fsk_enters_sleep_before_lora(self):
        radio = self.radio()
        radio.spi.regs[0x01] = 0x09
        self.assertTrue(radio.configure_lora_registers())
        mode_writes = [value for address, value in radio.spi.writes if address == 0x01]
        self.assertEqual(mode_writes, [0x08, 0x88, 0x89])

    def test_reply_switches_rx_to_tx_without_reinitializing_radio(self):
        radio = self.radio()
        self.assertTrue(radio.transmit_text("R1|test"))
        mode_writes = [value for address, value in radio.spi.writes if address == 0x01]
        self.assertEqual(mode_writes, [0x89, 0x8B, 0x89, 0x8D])
        self.assertFalse(any(address == 0x39 for address, _ in radio.spi.writes))

    def test_reply_does_not_transmit_zero_length_payload(self):
        radio = self.radio(drop_payload=True)
        self.assertFalse(radio.transmit_text("R1|test"))
        self.assertNotIn((0x01, 0x8B), radio.spi.writes)

    def test_reply_does_not_accept_previous_tx_done(self):
        radio = self.radio(stale_tx_done=True)
        self.assertFalse(radio.transmit_text("R1|test"))
        self.assertNotIn((0x01, 0x8B), radio.spi.writes)

    def test_reply_does_not_claim_transmission_if_standby_fails(self):
        radio = self.radio(block_standby=True)
        self.assertFalse(radio.transmit_text("R1|test"))
        self.assertNotIn((0x01, 0x8B), radio.spi.writes)

    def test_only_one_receiver_can_own_spi(self):
        with tempfile.TemporaryDirectory() as directory:
            first = self.radio()
            second = self.radio()
            with patch.object(self.module, "SPI_LOCK_DIRECTORY", directory):
                self.assertTrue(first.acquire_spi_lock())
                self.assertFalse(second.acquire_spi_lock())
                first.close()
                self.assertTrue(second.acquire_spi_lock())
                second.close()

    def test_receiver_never_controls_reset_by_gpio(self):
        # Cableado confirmado: RST del SX1278 puenteado a 3.3 V (pin 17) y DIO0
        # en el pin 31. El receptor no debe reclamar GPIO ni volver a usar el
        # pin 29 para reset.
        self.assertFalse(hasattr(self.module, "GPIO"))
        self.assertFalse(hasattr(self.module, "gpiod"))
        self.assertFalse(hasattr(self.module, "USE_GPIO_RST"))
        self.assertFalse(hasattr(self.module, "PIN_RST"))
        self.assertEqual(self.module.PIN_DIO0, 31)
        radio = self.radio()
        for legacy in ("setup_gpio", "setup_gpiod_gpio", "find_gpiod_line", "hold_reset_high"):
            self.assertFalse(hasattr(radio, legacy), legacy)


if __name__ == "__main__":
    unittest.main()
