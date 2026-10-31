"""Regresiones de fallos de captura, cierre, TensorRT y persistencia, sin hardware."""
import json
import queue
import tempfile
import threading
import time
import types
import sys
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import Mock, patch

import numpy as np
import test_tracking_logic as tracking_tests
import test_secure_protocol as protocol_tests

WORKER = tracking_tests.MODULE
protocol_tests.ControllerTests.setUpClass()
RX = protocol_tests.ControllerTests.module
SESSION = "a" * 32
OTHER = "b" * 32


class WorkerReliabilityTests(unittest.TestCase):
    def setUp(self):
        stack = ExitStack()
        self.addCleanup(stack.close)
        self.enterContext = stack.enter_context  # unittest de Python 3.10 (Ubuntu 22.04).
        WORKER.reset_runtime_stats()
        self.output = StringIO()
        self.enterContext(redirect_stdout(self.output))
        self.enterContext(patch.object(WORKER, "WORKER_STATUS_FILE", ""))
        self.enterContext(patch.object(WORKER, "WORKER_RESULT_FILE", ""))

    def capture(self, cap):
        event, reason = threading.Event(), {"value": "finished"}
        with patch.object(WORKER, "open_video_source", return_value=(cap, "fake")):
            WORKER.capture_worker("csi://0", "h264", 120, queue.Queue(2), event,
                                  stop_reason=reason, capture_timeout=1)
        return event, reason

    def test_capture_exception_stops_session_and_releases_camera(self):
        cap = Mock()
        cap.get.return_value = 30
        cap.read.side_effect = RuntimeError("disconnected")
        event, reason = self.capture(cap)
        self.assertTrue(event.is_set())
        self.assertEqual(reason["value"], "capture_error")
        cap.release.assert_called_once()

    def test_capture_open_failure_releases_handle(self):
        cap = Mock()
        cap.isOpened.return_value = False
        event, reason = self.capture(cap)
        self.assertTrue(event.is_set())
        self.assertEqual(reason["value"], "capture_open_failed")
        cap.release.assert_called_once()

    def test_capture_metadata_exception_also_releases_handle(self):
        cap = Mock()
        cap.get.side_effect = RuntimeError("metadata")
        event, reason = self.capture(cap)
        self.assertTrue(event.is_set())
        cap.release.assert_called_once()

    def test_repeated_empty_camera_reads_timeout(self):
        cap = Mock()
        cap.get.return_value = 30
        cap.read.return_value = (False, None)
        with patch.object(WORKER.time, "monotonic", side_effect=[0, 2]):
            event, reason = self.capture(cap)
        self.assertTrue(event.is_set())
        self.assertEqual(reason["value"], "capture_timeout")
        cap.release.assert_called_once()

    def test_signal_cannot_overwrite_an_error(self):
        event, reason = threading.Event(), {"value": "finished"}
        WORKER.request_stop(event, reason, "inference_error")
        WORKER.request_stop(event, reason, "signal")
        self.assertEqual(reason["value"], "inference_error")

    def test_no_processed_frames_cannot_produce_zero_success(self):
        result = WORKER.emit_worker_result("signal")
        self.assertEqual(result["reason"], "no_frames_processed")
        self.assertEqual(result["status"], "error")
        self.assertIsNone(result["count"])

    def test_processed_empty_scene_is_valid_zero(self):
        WORKER.update_count_stats(0, 0)
        result = WORKER.emit_worker_result("signal")
        self.assertEqual(result["status"], "finished")
        self.assertEqual(result["count"], 0)

    def test_failed_session_only_exposes_partial_count_as_diagnostic(self):
        WORKER.update_count_stats(3, 5)
        result = WORKER.emit_worker_result("capture_timeout")
        self.assertIsNone(result["count"])
        self.assertEqual(result["partial_count"], 5)

    def test_write_failure_is_not_announced_as_success(self):
        WORKER.update_count_stats(2, 2)
        with patch.object(WORKER, "write_worker_json", return_value=False):
            result = WORKER.emit_worker_result("signal")
        self.assertEqual(result["reason"], "result_write_failed")
        self.assertIn("COUNT_FINAL|count=unknown", self.output.getvalue())

    def test_atomic_writes_from_concurrent_publishers(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "status.json"
            with ThreadPoolExecutor(max_workers=4) as pool:
                outcomes = list(pool.map(lambda n: WORKER.write_worker_json(str(path), {"value": n}), range(20)))
            self.assertTrue(all(outcomes))
            self.assertIn(json.loads(path.read_text())["value"], range(20))
            self.assertEqual(list(Path(directory).iterdir()), [path])
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_failed_replace_preserves_previous_json(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "status.json"
            path.write_text('{"count": 2}')
            with patch.object(WORKER.os, "replace", side_effect=OSError("full")):
                self.assertFalse(WORKER.write_worker_json(str(path), {"count": 3}))
            self.assertEqual(json.loads(path.read_text()), {"count": 2})
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_supervisor_flags_stuck_thread_before_final_result(self):
        event = threading.Event()
        event.set()
        reason = {"value": "signal"}
        threads = [Mock(name="capture"), Mock(name="inference")]
        for thread, name in zip(threads, ("capture", "inference")):
            thread.name = name
            thread.is_alive.return_value = True
        stuck = WORKER.supervise_workers(threads, event, reason, False, 1, 1, 10, 0.01)
        self.assertEqual(stuck, ["capture", "inference"])
        self.assertEqual(reason["value"], "shutdown_timeout")

    def test_supervisor_detects_unexpected_inference_exit(self):
        event, reason = threading.Event(), {"value": "finished"}
        threads = [Mock(), Mock()]
        for thread in threads:
            thread.is_alive.return_value = False
        stuck = WORKER.supervise_workers(threads, event, reason, False, 1, 1, 10, 0.01)
        self.assertEqual(stuck, [])
        self.assertEqual(reason["value"], "inference_worker_exited")

    def test_eof_during_supervisor_poll_is_not_misclassified_as_crash(self):
        event, reason = threading.Event(), {"value": "eof"}
        capture, inference = Mock(), Mock()
        capture.is_alive.return_value = False
        def exited():
            event.set()
            return False
        inference.is_alive.side_effect = exited
        self.assertEqual(WORKER.supervise_workers([capture, inference], event, reason, True, 1, 1, 10, 0.01), [])
        self.assertEqual(reason["value"], "eof")

    def test_supervisor_detects_no_progress_even_if_threads_are_alive(self):
        for local, expected in ((False, "capture_timeout"), (True, "inference_timeout")):
            with self.subTest(local=local):
                event, reason = threading.Event(), {"value": "finished"}
                threads = [Mock(name="capture"), Mock(name="inference")]
                for thread in threads:
                    thread.name = "fake"
                    thread.is_alive.return_value = True
                WORKER.supervise_workers(threads, event, reason, local, 0.01, 0.01, 10, 0.01)
                self.assertEqual(reason["value"], expected)

    def test_exhaustive_capture_applies_backpressure_and_can_stop(self):
        self.assertGreater(WORKER.EXHAUSTIVE_FRAME_QUEUE_SIZE, 0)
        cap = Mock()
        cap.get.return_value = 30
        cap.read.return_value = (True, np.zeros((4, 4, 3), dtype=np.uint8))
        event, reason = threading.Event(), {"value": "finished"}
        frames = queue.Queue(WORKER.EXHAUSTIVE_FRAME_QUEUE_SIZE)
        with patch.object(WORKER, "open_video_source", return_value=(cap, "file")), \
             patch.object(WORKER, "is_local_file_source", return_value=True), \
             patch.object(WORKER, "is_live_source", return_value=False):
            thread = threading.Thread(target=WORKER.capture_worker,
                args=("file", "h264", 120, frames, event),
                kwargs={"video_mode": "exhaustive", "stop_reason": reason})
            thread.start()
            try:
                deadline = time.monotonic() + 2
                while not frames.full() and time.monotonic() < deadline:
                    event.wait(0.01)
                self.assertTrue(frames.full())
                self.assertLessEqual(cap.read.call_count, frames.maxsize + 1)
            finally:
                event.set()
                thread.join(timeout=2)
            self.assertFalse(thread.is_alive())
        cap.release.assert_called_once()

    def test_worker_lock_excludes_second_instance_and_can_be_reacquired(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(WORKER.tempfile, "gettempdir", return_value=directory):
            fd = WORKER.acquire_worker_lock()
            try:
                with self.assertRaises(BlockingIOError):
                    WORKER.acquire_worker_lock()
            finally:
                WORKER.os.close(fd)
            fd = WORKER.acquire_worker_lock()
            WORKER.os.close(fd)

    def test_main_processes_video_and_resets_count_between_sessions(self):
        outputs = {"num_detections": [1], "detection_boxes": [[[0.1, 0.1, 0.8, 0.8]]],
                   "detection_scores": [[0.9]], "detection_classes": [[1]]}
        arguments = ["run_bovino.py", "--engine", "fake.engine", "--source", "fake.mp4",
                     "--tracker", "simple", "--gmc", "none", "--track-min-hits", "1", "--no-display"]
        with tempfile.TemporaryDirectory() as directory:
            for _ in range(2):
                cap = Mock()
                cap.get.return_value = 30
                cap.read.side_effect = [(True, np.zeros((32, 32, 3), dtype=np.uint8)) for _ in range(3)] + [(False, None)]
                detector = Mock(input_layout="nhwc")
                detector.infer.return_value = outputs
                path = Path(directory) / "result.json"
                with patch.object(WORKER, "open_video_source", return_value=(cap, "fake.mp4")), \
                     patch.object(WORKER, "is_local_file_source", return_value=True), \
                     patch.object(WORKER, "is_live_source", return_value=False), \
                     patch.object(WORKER, "TRTDetector", return_value=detector), \
                     patch.object(WORKER, "WORKER_RESULT_FILE", str(path)), \
                     patch.object(WORKER.tempfile, "gettempdir", return_value=directory), \
                     patch.object(WORKER.signal, "signal"), patch.object(sys, "argv", arguments):
                    self.assertEqual(WORKER.main(), 0)
                result = json.loads(path.read_text())
                self.assertEqual(result["count"], 1)
                self.assertEqual(result["frames_processed"], 3)
                self.assertEqual(result["tracker_effective"], "internal_persistent")
                cap.release.assert_called_once()
                detector.close.assert_called_once()


class ModelContractTests(unittest.TestCase):
    def test_layout_and_640_contract(self):
        for shape, layout in (((1, 640, 640, 3), "nhwc"), ((1, 3, 640, 640), "nchw")):
            detector = WORKER.TRTDetector.__new__(WORKER.TRTDetector)
            detector.input_layout = "auto"
            self.assertEqual(detector._resolve_input_shape(shape), shape)
            self.assertEqual(detector.input_layout, layout)
        for shape in ((2, 640, 640, 3), (1, 320, 320, 3), (-1, -1, -1, -1)):
            detector.input_layout = "auto"
            with self.assertRaises(RuntimeError):
                detector._resolve_input_shape(shape)

    def test_preprocessing_respects_layout_dtype_and_normalization(self):
        detector = WORKER.TRTDetector.__new__(WORKER.TRTDetector)
        detector.input_layout, detector.input_dtype = "nchw", np.float16
        detector.normalization = "zero_one"
        image = np.zeros((4, 4, 3), dtype=np.uint8)
        image[:, :, 2] = 255
        inp = detector.preprocess(image)
        self.assertEqual(inp.shape, (1, 3, 640, 640))
        self.assertEqual(inp.dtype, np.float16)
        self.assertTrue(np.all(inp[0, 0] == 1))  # RGB, no BGR.
        self.assertTrue(np.all(inp[0, 2] == 0))

    def test_cuda_resources_released_on_partial_constructor_failure(self):
        names = ["input", "num_detections", "detection_boxes", "detection_scores", "detection_classes"]
        engine = Mock(num_io_tensors=len(names))
        engine.get_tensor_name.side_effect = names
        engine.get_tensor_mode.side_effect = lambda name: "in" if name == "input" else "out"
        engine.get_tensor_dtype.return_value = np.float32
        engine.get_tensor_shape.return_value = (1, 640, 640, 3)
        context = engine.create_execution_context.return_value
        context.get_tensor_shape.return_value = (1, 640, 640, 3)
        context.set_tensor_address.return_value = False
        runtime = Mock()
        runtime.__enter__ = Mock(return_value=runtime)
        runtime.__exit__ = Mock(return_value=False)
        runtime.deserialize_cuda_engine.return_value = engine
        trt = types.SimpleNamespace(Runtime=Mock(return_value=runtime), nptype=lambda value: value,
                                    TensorIOMode=types.SimpleNamespace(INPUT="in"))
        cuda = Mock()
        cuda.cudaStreamCreate.return_value = (0, 17)
        cuda.cudaMalloc.return_value = (0, 23)
        cuda.cudaFree.return_value = (0,)
        cuda.cudaStreamDestroy.return_value = (0,)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fake.engine"
            path.write_bytes(b"fake")
            with patch.object(WORKER, "trt", trt), patch.object(WORKER, "cudart", cuda), \
                 patch.object(WORKER, "init_trt_plugins"), redirect_stdout(StringIO()):
                with self.assertRaisesRegex(RuntimeError, "buffer"):
                    WORKER.TRTDetector(str(path))
        cuda.cudaFree.assert_called_once_with(23)
        cuda.cudaStreamDestroy.assert_called_once_with(17)

    def test_cleanup_attempts_all_cuda_resources_even_if_one_fails(self):
        detector = WORKER.TRTDetector.__new__(WORKER.TRTDetector)
        detector.buffers = {"a": {"device": 1}, "b": {"device": 2}}
        detector.stream = 3
        cuda = Mock()
        cuda.cudaFree.side_effect = [RuntimeError("free failed"), (0,)]
        cuda.cudaStreamDestroy.return_value = (0,)
        with patch.object(WORKER, "cudart", cuda):
            with self.assertRaisesRegex(RuntimeError, "free failed"):
                detector.close()
            detector.close()  # Idempotencia, sin doble free.
        self.assertEqual(cuda.cudaFree.call_count, 2)
        cuda.cudaStreamDestroy.assert_called_once_with(3)

    def test_class_filter_and_weak_detections(self):
        outputs = {"num_detections": [3],
                   "detection_boxes": [[[0.1, 0.1, 0.4, 0.4]] * 3],
                   "detection_scores": [[0.2, 0.9, float("nan")]],
                   "detection_classes": [[1, 2, 1]]}
        detections = WORKER.decode_detections(outputs, (640, 640, 3), conf_th=0.15, class_ids=[1])
        self.assertEqual(len(detections), 1)
        self.assertAlmostEqual(detections[0][4], 0.2)
        self.assertEqual(WORKER.decode_detections(outputs, (640, 640, 3), conf_th=0.45, class_ids=[1]), [])

    def test_missing_tracker_is_error_unless_fallback_is_explicit(self):
        with patch.object(WORKER, "RoboflowBoTSORTBovineTracker", side_effect=ImportError("absent")):
            with self.assertRaisesRegex(RuntimeError, "no disponible"):
                WORKER.create_tracker("botsort", **tracking_tests.TrackerFactoryTests.common)

    def test_confirmation_requires_consecutive_frames(self):
        tracker = WORKER.PersistentBovineTracker(min_hits=3, max_missed=4)
        detection = tracking_tests.det((10, 10, 60, 60))
        with redirect_stdout(StringIO()):
            tracker.update([detection])
            tracker.update([detection])
            tracker.update([])
            self.assertEqual(tracker.update([detection])[1], 0)
            tracker.update([detection])
            self.assertEqual(tracker.update([detection])[1], 1)
            for _ in range(5):
                tracker.update([])
        self.assertEqual(tracker.tracks, {})
        self.assertEqual(tracker.total_count, 1)


class ReceiverReliabilityTests(unittest.TestCase):
    def setUp(self):
        stack = ExitStack()
        self.addCleanup(stack.close)
        self.enterContext = stack.enter_context
        self.enterContext(redirect_stdout(StringIO()))
        self.enterContext(patch.object(RX, "COUNT_LOG_PATH", "/nonexistent/bovisense-test.log"))
        self.protocol = Mock()
        self.protocol.result.return_value = None
        self.enterContext(patch.object(RX, "secure_protocol", self.protocol))
        self.controller = RX.CountSessionController()
        self.controller.session = {"id": SESSION, "status": "RUNNING", "start_time": time.time(), "count": 7}

    def publish(self, payload, final=True):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "result.json"
            path.write_text(json.dumps(payload))
            self.controller.read_worker_json(path, final=final)

    def valid_final(self, **changes):
        return dict(session=SESSION, status="finished", reason="signal", count=7, frames_processed=5, **changes)

    def test_final_result_waits_for_process_exit_and_persistence(self):
        self.controller.process = Mock()
        self.controller.process.poll.return_value = None
        self.publish(self.valid_final())
        self.controller.sync_worker_state()
        self.assertIsNone(self.controller.last_result)
        self.protocol.save_result.assert_not_called()
        self.controller.process.poll.return_value = 0
        self.controller.sync_worker_state()
        self.assertEqual(self.controller.result(SESSION)["status"], "RESULT")
        self.protocol.save_result.assert_called_once()

    def test_zero_frames_and_other_session_are_rejected(self):
        payload = self.valid_final()
        payload["session"] = OTHER
        self.publish(payload)
        self.assertNotIn("worker_result", self.controller.session)
        payload.update(session=SESSION, frames_processed=0)
        self.publish(payload)
        self.assertEqual(self.controller.session["worker_result"]["status"], "ERROR")

    def test_nonzero_exit_overrides_successful_hook(self):
        self.publish(self.valid_final())
        self.controller.process = Mock()
        self.controller.process.poll.return_value = 1
        self.controller.sync_worker_state()
        self.assertEqual(self.controller.last_result["status"], "ERROR")
        self.assertIsNone(self.controller.last_result["count"])

    def test_exit_zero_without_final_hook_is_error(self):
        self.controller.process = Mock()
        self.controller.process.poll.return_value = 0
        self.controller.sync_worker_state()
        self.assertEqual(self.controller.last_result["reason"], "missing_worker_result")

    def test_error_response_does_not_include_live_or_previous_count(self):
        self.assertEqual(self.controller.response_fields("ERROR")["count"], "unknown")
        self.assertEqual(self.controller.result_response()["status"], "ERROR")

    def test_stop_keeps_error_received_during_shutdown(self):
        self.controller.process = Mock(pid=123)
        self.controller.process.poll.return_value = None
        def complete(**kwargs):
            self.controller.session["worker_result"] = {"status": "ERROR", "reason": "inference_error", "count": None}
            self.controller.process.poll.return_value = 1
        self.controller.process.wait.side_effect = complete
        with patch.object(RX.os, "getpgid", return_value=123), patch.object(RX.os, "killpg"):
            result = self.controller.stop(requested_session=SESSION)
        self.assertEqual(result["status"], "ERROR")
        self.assertEqual(self.controller.last_result["reason"], "inference_error")

    def test_confirmed_graceful_stop_is_successful(self):
        self.controller.process = Mock(pid=123)
        self.controller.process.poll.return_value = None
        def complete(**kwargs):
            self.publish(self.valid_final())
            self.controller.process.poll.return_value = 0
        self.controller.process.wait.side_effect = complete
        with patch.object(RX.os, "getpgid", return_value=123), patch.object(RX.os, "killpg"):
            result = self.controller.stop(requested_session=SESSION)
        self.assertEqual(result["status"], "STOPPED")
        self.assertEqual(result["count"], "7")

    def test_disk_failure_blocks_success_and_new_session_until_retry(self):
        self.protocol.save_result.side_effect = OSError("disk full")
        self.controller.finish_session("signal")
        self.assertEqual(self.controller.result_response()["status"], "ERROR")
        self.assertEqual(self.controller.start(OTHER)["detail"], "result_persistence_failed")
        completed = self.controller.last_result["completed"]
        self.protocol.save_result.side_effect = None
        self.controller.sync_worker_state()
        self.assertEqual(self.controller.result_response()["status"], "RESULT")
        self.assertEqual(self.controller.last_result["completed"], completed)
        self.assertFalse(self.controller.pending_results)

    def test_recovery_of_multiple_sessions_in_arbitrary_order(self):
        self.controller.session = None
        stored = {SESSION: {"status": "STOPPED", "count": 4, "completed": 100},
                  OTHER: {"status": "STOPPED", "count": 8, "completed": 200}}
        self.protocol.result.side_effect = stored.get
        for session, count in ((SESSION, "4"), (OTHER, "8"), (SESSION, "4")):
            result = self.controller.result(session)
            self.assertEqual(result["status"], "RESULT")
            self.assertEqual(result["count"], count)

    def test_old_result_lookup_does_not_hide_current_finished_session(self):
        self.controller.finish_session("signal")
        first = dict(self.controller.last_result)
        self.protocol.result.side_effect = {SESSION: first, OTHER: {"status": "STOPPED", "count": 8, "completed": 200}}.get
        self.assertEqual(self.controller.result(OTHER)["count"], "8")
        self.assertEqual(self.controller.result(SESSION)["count"], "7")
        self.assertEqual(self.controller.result(SESSION)["completed"], str(first["completed"]))

    def test_same_session_start_does_not_restart_or_erase_result(self):
        self.controller.finish_session("signal")
        with patch.object(RX.subprocess, "Popen") as popen:
            result = self.controller.start(SESSION)
        popen.assert_not_called()
        self.assertEqual(result["status"], "RESULT")

    def test_finalization_is_idempotent_and_does_not_downgrade_error(self):
        self.controller.finish_session("inference_error", status="ERROR")
        original = dict(self.controller.last_result)
        self.controller.finish_session("signal", status="STOPPED")
        self.assertEqual(self.controller.last_result, original)
        self.protocol.save_result.assert_called_once()

    def test_database_read_failure_is_not_reported_as_idle(self):
        self.controller.session = None
        self.protocol.result.side_effect = OSError("unavailable")
        self.assertEqual(self.controller.result(SESSION)["status"], "ERROR")

    def test_launch_stop_and_recover_with_real_child_and_sqlite(self):
        # El hijo es un simulador sin camara/GPU/radio ni red. Valida env, argv,
        # SIGTERM, espera del proceso, hook final y recuperación SQLite juntos.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / "worker.py"
            script.write_text('''import json, os, signal, time
stop = False
def handle(sig, frame):
    global stop
    stop = True
signal.signal(signal.SIGTERM, handle)
session = os.environ["BOVISENSE_SESSION_ID"]
with open(os.environ["BOVISENSE_STATUS_FILE"], "w") as f:
    json.dump({"session": session, "status": "running", "count": 2}, f)
while not stop:
    time.sleep(0.01)
with open(os.environ["BOVISENSE_RESULT_FILE"], "w") as f:
    json.dump({"session": session, "status": "finished", "reason": "signal", "count": 2, "frames_processed": 5}, f)
''')
            engine = root / "fake.engine"
            engine.write_bytes(b"fake")
            protocol = protocol_tests.SecureProtocol(protocol_tests.KEY, root / "state.db")
            controller = RX.CountSessionController()
            try:
                with patch.multiple(RX, COUNT_PROJECT_DIR=directory, COUNT_VENV_PYTHON=sys.executable,
                                    COUNT_SCRIPT_PATH=str(script), COUNT_ENGINE_PATH=str(engine),
                                    COUNT_LOG_PATH=str(root / "worker.log"), secure_protocol=protocol), \
                     patch.object(RX.tempfile, "gettempdir", return_value=directory):
                    self.assertEqual(controller.start(SESSION)["status"], "STARTED")
                    deadline = time.monotonic() + 3
                    while not Path(controller.session["status_file"]).exists() and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(Path(controller.session["status_file"]).exists())
                    result = controller.stop(requested_session=SESSION)
                    self.assertEqual(result["status"], "STOPPED")
                    self.assertEqual(result["count"], "2")
                    self.assertFalse(controller.is_worker_alive())
                    self.assertIsNone(controller.log_file)
                    fresh = RX.CountSessionController()
                    self.assertEqual(fresh.result(SESSION)["completed"], result["completed"])
                    self.assertEqual(fresh.result(SESSION)["count"], "2")
            finally:
                if controller.is_worker_alive():
                    controller.process.kill()
                    controller.process.wait(timeout=3)
                controller.close_log_file()
                protocol.close()


if __name__ == "__main__":
    unittest.main()
