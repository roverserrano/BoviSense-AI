"""Pruebas de la logica de tracking y conteo de run_bovino.py sin hardware.

Cubre lo que hasta ahora solo se verificaba a mano:
  * filtro de detecciones demasiado pequenas;
  * filtrado de parametros segun la version instalada de la libreria de tracking;
  * conteo por identidad (un track cuenta una sola vez);
  * seleccion de motor y degradacion explicita;
  * compensacion de movimiento global (GMC) manteniendo el track con camara movil.

El detector TensorRT no se instancia: si `tensorrt`/`cuda` no estan disponibles
se sustituyen por dobles, de modo que la prueba corre tambien fuera de la Jetson.

Ejecutar:  python3 -m unittest test_tracking_logic.py
"""

import importlib.util
import pathlib
import sys
import types
import unittest

import cv2
import numpy as np


def _stub_tensorrt():
    module = types.ModuleType("tensorrt")

    class _Logger:
        INFO = 0

        def __init__(self, *args, **kwargs):
            pass

    module.Logger = _Logger
    module.Runtime = object
    module.DeserializationError = type("DeserializationError", (Exception,), {})
    return module


def _stub_cuda():
    cuda = types.ModuleType("cuda")
    bindings = types.ModuleType("cuda.bindings")
    runtime = types.ModuleType("cuda.bindings.runtime")
    runtime.cudaGetErrorString = lambda *args, **kwargs: (0, "stub")
    bindings.runtime = runtime
    cuda.bindings = bindings
    return cuda, bindings, runtime


def _load_receiver_module():
    try:
        import tensorrt  # noqa: F401  (en la Jetson esta disponible de verdad)
    except Exception:
        sys.modules["tensorrt"] = _stub_tensorrt()
    try:
        import cuda  # noqa: F401
    except Exception:
        cuda, bindings, runtime = _stub_cuda()
        sys.modules["cuda"] = cuda
        sys.modules["cuda.bindings"] = bindings
        sys.modules["cuda.bindings.runtime"] = runtime

    path = pathlib.Path(__file__).with_name("run_bovino.py")
    spec = importlib.util.spec_from_file_location("bovino_test", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MODULE = _load_receiver_module()

# Deteccion plana tal como la produce decode_detections: [x1, y1, x2, y2, score, cls]
def det(box, score=0.9, cls=0):
    return [float(box[0]), float(box[1]), float(box[2]), float(box[3]), float(score), int(cls)]


def textured(shift_x=0):
    """Escena sintetica con textura suficiente para que ORB encuentre features."""
    rng = np.random.default_rng(7)
    noise = (rng.random((240, 320)) * 255).astype(np.uint8)
    image = cv2.cvtColor(cv2.GaussianBlur(noise, (9, 9), 0), cv2.COLOR_GRAY2BGR)
    return np.roll(image, shift_x, axis=1)


class HelperTests(unittest.TestCase):
    def test_small_boxes_are_filtered_only_when_enabled(self):
        detections = [det((10, 10, 40, 30)), det((100, 100, 104, 104))]
        self.assertEqual(MODULE.filter_small_detections(detections, 0.0), detections)
        self.assertEqual(MODULE.filter_small_detections(detections, 12), [detections[0]])
        self.assertEqual(MODULE.bbox_min_side(det((10, 10, 40, 30))), 20.0)

    def test_supported_kwargs_filters_by_signature(self):
        class Strict:
            def __init__(self, a=1):
                self.a = a

        class Loose:
            def __init__(self, **kwargs):
                self.kwargs = kwargs

        applied, dropped = MODULE.supported_kwargs(Strict, {"a": 5, "zzz": 1})
        self.assertEqual(applied, {"a": 5})
        self.assertEqual(dropped, ["zzz"])
        applied, dropped = MODULE.supported_kwargs(Loose, {"cualquiera": 1})
        self.assertEqual(applied, {"cualquiera": 1})
        self.assertEqual(dropped, [])


class CountingTests(unittest.TestCase):
    def test_legacy_tracker_counts_each_identity_once(self):
        tracker = MODULE.LegacyUniqueBovineTracker(max_missed=5, min_iou=0.1, max_distance=120)
        active, total = tracker.update([det((10, 10, 60, 60))])
        self.assertEqual(total, 1)
        self.assertEqual(len(active), 1)

        _, total = tracker.update([det((12, 12, 62, 62))])
        self.assertEqual(total, 1, "el mismo bovino no debe contarse dos veces")

        _, total = tracker.update([det((12, 12, 62, 62)), det((200, 200, 260, 260))])
        self.assertEqual(total, 2, "un bovino nuevo si debe contarse")
        self.assertEqual(tracker.summary_fields()["engine"], "legacy_internal")

    def test_legacy_tracker_respects_minimum_box(self):
        tracker = MODULE.LegacyUniqueBovineTracker(min_box_px=12)
        _, total = tracker.update([det((10, 10, 14, 14))])
        self.assertEqual(total, 0, "una caja diminuta no debe generar conteo")

    def test_persistent_tracker_confirms_before_counting(self):
        tracker = MODULE.PersistentBovineTracker(
            max_missed=5, min_hits=3, min_iou=0.05, max_distance=200
        )
        for _ in range(3):
            _, total = tracker.update([det((10, 10, 60, 60))])
        self.assertEqual(total, 1, "debe confirmar tras min_hits frames")

        _, total = tracker.update([det((11, 11, 61, 61))])
        self.assertEqual(total, 1, "no debe volver a contar el mismo track")

        for _ in range(3):
            _, total = tracker.update([det((11, 11, 61, 61)), det((300, 300, 360, 360))])
        self.assertEqual(total, 2, "el segundo bovino debe contarse una sola vez")
        self.assertEqual(tracker.summary_fields()["engine"], "internal_persistent")


class TrackerFactoryTests(unittest.TestCase):
    common = dict(
        track_buffer=120,
        frame_rate=30.0,
        track_min_iou=0.05,
        track_max_distance=120.0,
        track_min_hits=5,
        track_high_thresh=0.45,
        track_low_thresh=0.15,
        match_thresh=0.08,
        gmc_method="orb",
        reid_enabled=True,
        reid_max_seconds=10.0,
        reid_threshold=0.72,
        show_lost_tracks=True,
        lost_track_max_seconds=5.0,
        lost_track_prediction="hold",
        verbose_tracking=False,
    )

    def test_none_selects_legacy_tracker(self):
        tracker = MODULE.create_tracker("none", min_box_px=0.0, **self.common)
        self.assertIsInstance(tracker, MODULE.LegacyUniqueBovineTracker)

    def test_external_tracker_degrades_explicitly_without_library(self):
        tracker = MODULE.create_tracker("botsort", min_box_px=10.0, **self.common)
        self.assertIn(
            tracker.engine_name,
            ("roboflow_botsort", "internal_persistent"),
            "el motor efectivo debe estar identificado",
        )
        self.assertEqual(tracker.min_box_px, 10.0)


class GlobalMotionTests(unittest.TestCase):
    def test_gmc_estimates_translation(self):
        gmc = MODULE.ORBGlobalMotionCompensator()
        self.assertIsNone(gmc.estimate(textured(0)), "la primera llamada solo guarda el frame")
        matrix = gmc.estimate(textured(-100))
        self.assertIsNotNone(matrix, "ORB deberia estimar el desplazamiento global")
        self.assertAlmostEqual(float(matrix[0, 2]), -100.0, delta=2.0)

    def test_gmc_keeps_track_with_moving_camera(self):
        """Mismo bovino desplazado 100 px: con GMC no debe crear un track nuevo."""

        def count_with(use_gmc):
            tracker = MODULE.PersistentBovineTracker(
                max_missed=5,
                min_hits=1,
                min_iou=0.05,
                max_distance=50.0,
                gmc_method="orb" if use_gmc else "none",
            )
            tracker.update([det((200, 200, 240, 240))], frame=textured(0))
            return tracker.update([det((100, 200, 140, 240))], frame=textured(-100))[1]

        self.assertEqual(count_with(False), 2, "sin GMC el salto de 100 px crea un track nuevo")
        self.assertEqual(count_with(True), 1, "con GMC debe mantenerse el mismo bovino")


if __name__ == "__main__":
    unittest.main()
