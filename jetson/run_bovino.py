import os
import cv2
import time
import queue
import ctypes
import signal
import argparse
import threading
import json
import numpy as np
import tensorrt as trt

try:
    from cuda.bindings import runtime as cudart
except Exception:
    from cuda import cudart


TRT_LOGGER = trt.Logger(trt.Logger.INFO)
FRAME_QUEUE_SIZE = 2
VIS_QUEUE_SIZE = 2
EXHAUSTIVE_FRAME_QUEUE_SIZE = 0
EOS_FRAME = object()
WORKER_SESSION_ID = os.getenv("BOVISENSE_SESSION_ID", "")
WORKER_STATUS_FILE = os.getenv("BOVISENSE_STATUS_FILE", "")
WORKER_RESULT_FILE = os.getenv("BOVISENSE_RESULT_FILE", "")
COUNT_STATS_LOCK = threading.Lock()
COUNT_STATS = {
    "last_visible_count": None,
    "max_visible_count": None,
    "total_unique_count": 0,
    "frames_processed": 0,
}
PERF_STATS_LOCK = threading.Lock()
PERF_STATS = {
    "frames_read": 0,
    "frames_dropped": 0,
    "source_fps": None,
    "source_frame_count": None,
    "started_at": time.time(),
    "ended_at": None,
}


def update_count_stats(visible_count, total_unique_count):
    visible_count = int(visible_count)
    total_unique_count = int(total_unique_count)
    with COUNT_STATS_LOCK:
        COUNT_STATS["last_visible_count"] = visible_count
        current_max = COUNT_STATS["max_visible_count"]
        if current_max is None or visible_count > current_max:
            COUNT_STATS["max_visible_count"] = visible_count
        COUNT_STATS["total_unique_count"] = total_unique_count
        COUNT_STATS["frames_processed"] += 1


def current_count_stats():
    with COUNT_STATS_LOCK:
        return dict(COUNT_STATS)


def update_perf_stats(frames_read=0, frames_dropped=0, source_fps=None, source_frame_count=None):
    with PERF_STATS_LOCK:
        PERF_STATS["frames_read"] += int(frames_read)
        PERF_STATS["frames_dropped"] += int(frames_dropped)
        if source_fps is not None and source_fps > 0:
            PERF_STATS["source_fps"] = float(source_fps)
        if source_frame_count is not None and source_frame_count > 0:
            PERF_STATS["source_frame_count"] = int(source_frame_count)


def current_perf_stats():
    with PERF_STATS_LOCK:
        return dict(PERF_STATS)


def reset_runtime_stats():
    with COUNT_STATS_LOCK:
        COUNT_STATS["last_visible_count"] = None
        COUNT_STATS["max_visible_count"] = None
        COUNT_STATS["total_unique_count"] = 0
        COUNT_STATS["frames_processed"] = 0
    with PERF_STATS_LOCK:
        PERF_STATS["frames_read"] = 0
        PERF_STATS["frames_dropped"] = 0
        PERF_STATS["source_fps"] = None
        PERF_STATS["source_frame_count"] = None
        PERF_STATS["started_at"] = time.time()
        PERF_STATS["ended_at"] = None


def write_worker_json(path, payload):
    if not path:
        return
    try:
        with open(path, "w", encoding="utf-8") as file:
            json.dump(payload, file, ensure_ascii=False)
    except Exception as exc:
        print(f"WORKER_STATUS|status=error|detail=status_file_error:{exc}", flush=True)


def emit_worker_status(status, detail="", visible_count=None):
    stats = current_count_stats()
    payload = {
        "session": WORKER_SESSION_ID,
        "status": status,
        "detail": detail,
        "updatedAt": time.time(),
        "count": stats["total_unique_count"],
        "last_visible_count": stats["last_visible_count"],
        "max_visible_count": stats["max_visible_count"],
        "frames_processed": stats["frames_processed"],
    }
    if visible_count is not None:
        payload["visible_count"] = int(visible_count)

    fields = [f"status={status}"]
    if detail:
        fields.append(f"detail={detail}")
    if visible_count is not None:
        fields.append(f"visible_count={int(visible_count)}")
    fields.append(f"count={int(stats['total_unique_count'])}")
    if stats["max_visible_count"] is not None:
        fields.append(f"max_visible_count={int(stats['max_visible_count'])}")
    print("WORKER_STATUS|" + "|".join(fields), flush=True)
    write_worker_json(WORKER_STATUS_FILE, payload)


def emit_worker_result(reason):
    stats = current_count_stats()
    perf = current_perf_stats()
    final_count = stats["total_unique_count"]
    count_text = "unknown" if final_count is None else str(int(final_count))
    result_status = "error" if reason in ("capture_open_failed", "inference_error") else "finished"
    ended_at = time.time()
    elapsed_s = ended_at - float(perf.get("started_at") or ended_at)
    processing_fps = stats["frames_processed"] / max(elapsed_s, 1e-6)
    payload = {
        "session": WORKER_SESSION_ID,
        "status": result_status,
        "reason": reason,
        "count": final_count,
        "last_visible_count": stats["last_visible_count"],
        "max_visible_count": stats["max_visible_count"],
        "frames_processed": stats["frames_processed"],
        "frames_read": perf["frames_read"],
        "frames_dropped": perf["frames_dropped"],
        "elapsed_s": elapsed_s,
        "processing_fps": processing_fps,
        "source_fps": perf["source_fps"],
        "updatedAt": time.time(),
    }
    print(
        f"COUNT_FINAL|count={count_text}|reason={reason}|"
        f"frames={stats['frames_processed']}",
        flush=True,
    )
    print(
        "PERF_FINAL|"
        f"frames_read={perf['frames_read']}|"
        f"frames_processed={stats['frames_processed']}|"
        f"frames_dropped={perf['frames_dropped']}|"
        f"elapsed_s={elapsed_s:.2f}|"
        f"processing_fps={processing_fps:.2f}|"
        f"source_fps={0.0 if perf['source_fps'] is None else perf['source_fps']:.3f}",
        flush=True,
    )
    write_worker_json(WORKER_RESULT_FILE, payload)


# ============================================================
# CUDA helpers
# ============================================================
def cuda_err_code(err):
    """
    Normaliza distintos formatos de retorno de cuda-python.
    Puede llegar como:
      - entero
      - enum/int-like
      - tupla, por ejemplo: (err,)
    """
    if isinstance(err, tuple):
        if len(err) == 0:
            return 0
        err = err[0]

    if hasattr(err, "value"):
        return int(err.value)

    return int(err)


def check_cuda(err, msg):
    code = cuda_err_code(err)
    if code != 0:
        raise RuntimeError(f"{msg} | CUDA error code: {code}")


def init_trt_plugins():
    plugin_candidates = [
        "libnvinfer_plugin.so",
        "libnvinfer_plugin.so.10",
        "/usr/lib/aarch64-linux-gnu/libnvinfer_plugin.so",
        "/usr/lib/aarch64-linux-gnu/libnvinfer_plugin.so.10",
    ]

    loaded = False
    for lib in plugin_candidates:
        try:
            ctypes.CDLL(lib, mode=ctypes.RTLD_GLOBAL)
            print(f"[TRT] Plugin library cargada: {lib}")
            loaded = True
            break
        except OSError:
            pass

    if not loaded:
        raise RuntimeError(
            "No se pudo cargar libnvinfer_plugin.so. "
            "Verifica la instalación de TensorRT."
        )

    ok = trt.init_libnvinfer_plugins(TRT_LOGGER, "")
    if not ok:
        raise RuntimeError("trt.init_libnvinfer_plugins(...) falló")

    print("[TRT] Plugins estándar registrados correctamente")


# ============================================================
# Video source
# ============================================================
def gst_pipeline_rtsp(rtsp_url: str, codec: str = "h264", latency: int = 120) -> str:
    codec = codec.lower().strip()
    if codec == "h265":
        depay = "rtph265depay"
        parse = "h265parse"
    else:
        depay = "rtph264depay"
        parse = "h264parse"

    pipeline = (
        f'rtspsrc location="{rtsp_url}" latency={latency} protocols=tcp ! '
        f'{depay} ! {parse} ! nvv4l2decoder ! '
        f'nvvidconv ! video/x-raw,format=BGRx ! '
        f'videoconvert ! video/x-raw,format=BGR ! '
        f'appsink drop=1 max-buffers=1 sync=false'
    )
    return pipeline


def gst_pipeline_file_hw(file_path: str, codec: str = "h264") -> str:
    codec = codec.lower().strip()
    if codec == "h265":
        parse = "h265parse"
    else:
        parse = "h264parse"

    return (
        f'filesrc location="{file_path}" ! '
        f'qtdemux ! {parse} ! nvv4l2decoder ! '
        f'nvvidconv ! video/x-raw,format=BGRx ! '
        f'videoconvert ! video/x-raw,format=BGR ! '
        f'appsink drop=1 max-buffers=1 sync=false'
    )


def gst_pipeline_csi(
    sensor_id: int = 0,
    capture_width: int = 1920,
    capture_height: int = 1080,
    display_width: int | None = None,
    display_height: int | None = None,
    framerate: int = 30,
    flip_method: int = 0,
) -> str:
    """
    Pipeline para cámara CSI/MIPI usando nvarguscamerasrc.

    Pensado para Arducam/Raspberry Pi Camera v2 IMX219 en Jetson Orin Nano.
    OpenCV recibe BGR para mantener compatible preprocess(frame_bgr).
    appsink drop=1/max-buffers=1 prioriza baja latencia.
    """
    display_width = capture_width if display_width is None else int(display_width)
    display_height = capture_height if display_height is None else int(display_height)

    return (
        f"nvarguscamerasrc sensor-id={int(sensor_id)} ! "
        f"video/x-raw(memory:NVMM), "
        f"width=(int){int(capture_width)}, height=(int){int(capture_height)}, "
        f"format=(string)NV12, framerate=(fraction){int(framerate)}/1 ! "
        f"nvvidconv flip-method={int(flip_method)} ! "
        f"video/x-raw, width=(int){display_width}, height=(int){display_height}, "
        f"format=(string)BGRx ! "
        f"videoconvert ! video/x-raw, format=(string)BGR ! "
        f"appsink drop=1 max-buffers=1 sync=false"
    )


def parse_csi_sensor_id(source: str, default_sensor_id: int = 0) -> int:
    source = source.strip().lower()
    if source in ("csi", "imx219", "arducam"):
        return int(default_sensor_id)
    if source.startswith("csi://"):
        raw = source.replace("csi://", "", 1).strip("/")
        return int(raw) if raw else int(default_sensor_id)
    return int(default_sensor_id)


def is_csi_source(source: str) -> bool:
    source_l = source.strip().lower()
    return source_l in ("csi", "imx219", "arducam") or source_l.startswith("csi://")


def is_rtsp_source(source: str) -> bool:
    return source.strip().lower().startswith("rtsp://")


def is_v4l2_source(source: str) -> bool:
    source_l = source.strip().lower()
    return source_l.startswith("/dev/video") or source_l.isdigit()


def is_local_file_source(source: str) -> bool:
    source_l = source.strip().lower()
    if "://" in source_l:
        return False
    if is_csi_source(source) or is_v4l2_source(source):
        return False
    return os.path.isfile(source)


def is_live_source(source: str) -> bool:
    source_l = source.strip().lower()
    if is_csi_source(source) or is_rtsp_source(source) or is_v4l2_source(source):
        return True
    if source_l.startswith(("http://", "https://")):
        return True
    return False


def resize_for_processing(frame, processing_width=0, processing_height=0):
    target_w = int(processing_width or 0)
    target_h = int(processing_height or 0)
    if target_w <= 0 and target_h <= 0:
        return frame

    height, width = frame.shape[:2]
    if target_w <= 0:
        scale = target_h / float(height)
        target_w = max(1, int(round(width * scale)))
    elif target_h <= 0:
        scale = target_w / float(width)
        target_h = max(1, int(round(height * scale)))

    if width == target_w and height == target_h:
        return frame
    return cv2.resize(frame, (target_w, target_h), interpolation=cv2.INTER_AREA)


def open_video_source(
    source: str,
    codec: str = "h264",
    latency: int = 120,
    csi_sensor_id: int = 0,
    csi_width: int = 1920,
    csi_height: int = 1080,
    csi_fps: int = 30,
    csi_flip: int = 0,
    hw_decode: bool = False,
):
    source = source.strip()
    source_l = source.lower()

    if source_l.startswith("rtsp://"):
        pipeline = gst_pipeline_rtsp(source, codec=codec, latency=latency)
        cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
        used = pipeline
    elif source_l in ("csi", "imx219", "arducam") or source_l.startswith("csi://"):
        sensor_id = parse_csi_sensor_id(source, default_sensor_id=csi_sensor_id)
        pipeline = gst_pipeline_csi(
            sensor_id=sensor_id,
            capture_width=csi_width,
            capture_height=csi_height,
            framerate=csi_fps,
            flip_method=csi_flip,
        )
        cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
        used = pipeline
    elif hw_decode and is_local_file_source(source):
        pipeline = gst_pipeline_file_hw(source, codec=codec)
        cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
        used = pipeline
        if not cap.isOpened():
            print("[CAPTURA] HW decode no disponible para archivo; usando cv2.VideoCapture fallback")
            cap.release()
            cap = cv2.VideoCapture(source)
            used = source
    else:
        # HTTP, archivo local, /dev/videoX, etc.
        cap = cv2.VideoCapture(source)
        used = source

    return cap, used


# ============================================================
# TensorRT detector
# ============================================================
class TRTDetector:
    def __init__(self, engine_path: str):
        self.logger = TRT_LOGGER
        init_trt_plugins()

        if not os.path.exists(engine_path):
            raise FileNotFoundError(f"No existe el engine: {engine_path}")

        with open(engine_path, "rb") as f, trt.Runtime(self.logger) as runtime:
            self.engine = runtime.deserialize_cuda_engine(f.read())

        if self.engine is None:
            raise RuntimeError("No se pudo deserializar el engine")

        self.context = self.engine.create_execution_context()
        if self.context is None:
            raise RuntimeError("No se pudo crear el contexto de ejecución")

        err, stream = cudart.cudaStreamCreate()
        check_cuda(err, "No se pudo crear stream CUDA")
        self.stream = stream

        self.input_name = None
        self.output_names = []

        for i in range(self.engine.num_io_tensors):
            name = self.engine.get_tensor_name(i)
            mode = self.engine.get_tensor_mode(name)
            if mode == trt.TensorIOMode.INPUT:
                self.input_name = name
            else:
                self.output_names.append(name)

        if self.input_name is None:
            raise RuntimeError("No se encontró tensor de entrada")

        self.input_dtype = trt.nptype(self.engine.get_tensor_dtype(self.input_name))
        self.input_engine_shape = tuple(self.engine.get_tensor_shape(self.input_name))
        self.buffers = {}
        self.current_input_shape = None

        print(f"[TRT] Input tensor: {self.input_name}")
        print(f"[TRT] Input dtype : {self.input_dtype}")
        print(f"[TRT] Input shape : {self.input_engine_shape}")
        print(f"[TRT] Outputs     : {self.output_names}")

        resolved_input_shape = self._resolve_input_shape(self.input_engine_shape)
        self._allocate_for_shape(resolved_input_shape)

    def _resolve_input_shape(self, shape):
        if len(shape) != 4:
            raise RuntimeError(f"Shape de entrada no soportado: {shape}")

        n = 1 if shape[0] in (-1, 0) else int(shape[0])
        h = 640 if shape[1] in (-1, 0) else int(shape[1])
        w = 640 if shape[2] in (-1, 0) else int(shape[2])
        c = 3 if shape[3] in (-1, 0) else int(shape[3])

        if c != 3:
            raise RuntimeError(f"Se esperaba NHWC con 3 canales, pero llegó: {shape}")

        return (n, h, w, c)

    def _allocate_for_shape(self, input_shape):
        try:
            self.context.set_input_shape(self.input_name, input_shape)
        except Exception:
            pass

        self.current_input_shape = input_shape
        tensor_names = [self.input_name] + self.output_names

        for name, buf in self.buffers.items():
            try:
                cudart.cudaFree(buf["device"])
            except Exception:
                pass
        self.buffers = {}

        for name in tensor_names:
            shape = tuple(self.context.get_tensor_shape(name))
            dtype = trt.nptype(self.engine.get_tensor_dtype(name))

            if any(int(d) < 0 for d in shape):
                raise RuntimeError(
                    f"Shape no resuelto para tensor {name}: {shape}"
                )

            host = np.empty(shape, dtype=dtype)
            err, device_ptr = cudart.cudaMalloc(host.nbytes)
            check_cuda(err, f"cudaMalloc falló para {name}")

            self.context.set_tensor_address(name, int(device_ptr))

            self.buffers[name] = {
                "host": host,
                "device": device_ptr,
                "shape": shape,
                "dtype": dtype,
                "nbytes": host.nbytes,
            }

            print(f"[TRT] Tensor {name}: shape={shape}, dtype={dtype}")

    def preprocess(self, frame_bgr):
        n, h, w, c = self.current_input_shape
        resized = cv2.resize(frame_bgr, (w, h), interpolation=cv2.INTER_LINEAR)
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)

        # El engine espera float32 NHWC
        inp = rgb.astype(np.float32)
        inp = np.expand_dims(inp, axis=0)

        return np.ascontiguousarray(inp)

    def infer(self, inp):
        inp_buf = self.buffers[self.input_name]

        if inp.shape != tuple(inp_buf["shape"]):
            raise RuntimeError(
                f"Shape de input inesperado. Esperado {inp_buf['shape']}, recibido {inp.shape}"
            )

        np.copyto(inp_buf["host"], inp)

        err = cudart.cudaMemcpyAsync(
            inp_buf["device"],
            inp_buf["host"].ctypes.data,
            inp_buf["nbytes"],
            cudart.cudaMemcpyKind.cudaMemcpyHostToDevice,
            self.stream,
        )
        check_cuda(err, "H2D memcpy falló")

        ok = self.context.execute_async_v3(stream_handle=self.stream)
        if not ok:
            raise RuntimeError("TensorRT execute_async_v3 falló")

        outputs = {}
        for name in self.output_names:
            buf = self.buffers[name]
            err = cudart.cudaMemcpyAsync(
                buf["host"].ctypes.data,
                buf["device"],
                buf["nbytes"],
                cudart.cudaMemcpyKind.cudaMemcpyDeviceToHost,
                self.stream,
            )
            check_cuda(err, f"D2H memcpy falló para {name}")

        err = cudart.cudaStreamSynchronize(self.stream)
        check_cuda(err, "cudaStreamSynchronize falló")

        for name in self.output_names:
            outputs[name] = self.buffers[name]["host"].copy()

        return outputs

    def close(self):
        for _, buf in self.buffers.items():
            try:
                cudart.cudaFree(buf["device"])
            except Exception:
                pass

        try:
            cudart.cudaStreamDestroy(self.stream)
        except Exception:
            pass


# ============================================================
# Postproceso
# ============================================================
def get_output(outputs, name, contains=False):
    if name in outputs:
        return outputs[name]
    if contains:
        for k, v in outputs.items():
            if name.lower() in k.lower():
                return v
    return None


def decode_detections(outputs, frame_shape, conf_th=0.45, box_format="yxyx"):
    h, w = frame_shape[:2]

    num = get_output(outputs, "num_detections", contains=True)
    boxes = get_output(outputs, "detection_boxes", contains=True)
    scores = get_output(outputs, "detection_scores", contains=True)
    classes = get_output(outputs, "detection_classes", contains=True)

    if num is None or boxes is None or scores is None or classes is None:
        raise RuntimeError(
            "No se encontraron las salidas esperadas. "
            f"Outputs disponibles: {list(outputs.keys())}"
        )

    num = np.array(num).reshape(-1)
    boxes = np.array(boxes)
    scores = np.array(scores)
    classes = np.array(classes)

    if boxes.ndim == 3:
        boxes = boxes[0]
    if scores.ndim == 2:
        scores = scores[0]
    if classes.ndim == 2:
        classes = classes[0]

    n = int(num[0]) if len(num) else min(len(scores), len(boxes))
    n = min(n, len(scores), len(boxes), len(classes))

    dets = []
    for i in range(n):
        score = float(scores[i])
        if score < conf_th:
            continue

        box = boxes[i].astype(np.float32)

        if box_format == "xyxy":
            x1, y1, x2, y2 = box.tolist()
        else:
            y1, x1, y2, x2 = box.tolist()

        is_normalized = np.max(box) <= 1.5 and np.min(box) >= -0.5
        if is_normalized:
            x1 *= w
            x2 *= w
            y1 *= h
            y2 *= h

        x1 = int(np.clip(round(x1), 0, w - 1))
        y1 = int(np.clip(round(y1), 0, h - 1))
        x2 = int(np.clip(round(x2), 0, w - 1))
        y2 = int(np.clip(round(y2), 0, h - 1))

        if x2 <= x1 or y2 <= y1:
            continue

        cls = int(classes[i])
        dets.append((x1, y1, x2, y2, score, cls))

    return dets


def decode_detections_for_export(outputs, frame_shape, conf_th=0.45, box_format="yxyx"):
    h, w = frame_shape[:2]

    num = get_output(outputs, "num_detections", contains=True)
    boxes = get_output(outputs, "detection_boxes", contains=True)
    scores = get_output(outputs, "detection_scores", contains=True)
    classes = get_output(outputs, "detection_classes", contains=True)

    if num is None or boxes is None or scores is None or classes is None:
        raise RuntimeError(
            "No se encontraron las salidas esperadas. "
            f"Outputs disponibles: {list(outputs.keys())}"
        )

    num = np.array(num).reshape(-1)
    boxes = np.array(boxes)
    scores = np.array(scores)
    classes = np.array(classes)

    if boxes.ndim == 3:
        boxes = boxes[0]
    if scores.ndim == 2:
        scores = scores[0]
    if classes.ndim == 2:
        classes = classes[0]

    n = int(num[0]) if len(num) else min(len(scores), len(boxes))
    n = min(n, len(scores), len(boxes), len(classes))

    detections = []
    for i in range(n):
        score = float(scores[i])
        if score < conf_th:
            continue

        box = boxes[i].astype(np.float32)
        if box_format == "xyxy":
            x1, y1, x2, y2 = [float(v) for v in box.tolist()]
        else:
            y1, x1, y2, x2 = [float(v) for v in box.tolist()]

        is_normalized = np.max(box) <= 1.5 and np.min(box) >= -0.5
        if is_normalized:
            x1 *= w
            x2 *= w
            y1 *= h
            y2 *= h

        x1 = float(np.clip(x1, 0.0, max(w - 1, 0)))
        y1 = float(np.clip(y1, 0.0, max(h - 1, 0)))
        x2 = float(np.clip(x2, 0.0, max(w - 1, 0)))
        y2 = float(np.clip(y2, 0.0, max(h - 1, 0)))
        if x2 <= x1 or y2 <= y1:
            continue

        detections.append(
            {
                "class_id": int(classes[i]),
                "class_name": "cow",
                "confidence": score,
                "x1": x1,
                "y1": y1,
                "x2": x2,
                "y2": y2,
            }
        )

    return detections


class DetectionExporter:
    def __init__(
        self,
        export_path=None,
        frames_dir=None,
        save_frame_every=1,
        engine_path="",
        source="",
        confidence_threshold=0.45,
        box_format="yxyx",
        processing_width=0,
        processing_height=0,
        video_mode="",
    ):
        self.export_path = export_path
        self.frames_dir = frames_dir
        self.save_frame_every = max(1, int(save_frame_every or 1))
        self.engine_path = engine_path
        self.source = source
        self.confidence_threshold = float(confidence_threshold)
        self.box_format = box_format
        self.processing_width = int(processing_width or 0)
        self.processing_height = int(processing_height or 0)
        self.video_mode = video_mode
        self.file = None
        self.meta_written = False
        self.frames_written = 0
        self.detections_written = 0
        self.images_written = 0

        if self.export_path:
            parent = os.path.dirname(os.path.abspath(self.export_path))
            os.makedirs(parent, exist_ok=True)
            self.file = open(self.export_path, "w", encoding="utf-8", buffering=1)
            print(f"DETECTION_EXPORT|path={self.export_path}", flush=True)

        if self.frames_dir:
            os.makedirs(self.frames_dir, exist_ok=True)
            print(f"DETECTION_FRAME_SAVE|directory={self.frames_dir}", flush=True)

    def _meta_path(self):
        if self.export_path:
            return os.path.join(os.path.dirname(os.path.abspath(self.export_path)), "detections_meta.json")
        if self.frames_dir:
            return os.path.join(os.path.abspath(self.frames_dir), "detections_meta.json")
        return ""

    def write_meta_once(self, frame_shape):
        if self.meta_written:
            return

        perf = current_perf_stats()
        height, width = frame_shape[:2]
        payload = {
            "engine": self.engine_path,
            "source": self.source,
            "confidence_threshold": self.confidence_threshold,
            "box_format": self.box_format,
            "processing_width": self.processing_width,
            "processing_height": self.processing_height,
            "evaluated_width": int(width),
            "evaluated_height": int(height),
            "source_fps": perf.get("source_fps"),
            "video_mode": self.video_mode,
            "iou_evaluation_recommended": 0.50,
        }
        meta_path = self._meta_path()
        if meta_path:
            with open(meta_path, "w", encoding="utf-8") as meta_file:
                json.dump(payload, meta_file, ensure_ascii=False, indent=2)
        self.meta_written = True

    def write_jsonl(self, frame_number, timestamp_ms, frame_shape, detections):
        if self.file is None:
            return
        height, width = frame_shape[:2]
        payload = {
            "frame": int(frame_number),
            "timestamp_ms": None if timestamp_ms is None else float(timestamp_ms),
            "width": int(width),
            "height": int(height),
            "detections": detections,
        }
        self.file.write(json.dumps(payload, ensure_ascii=False) + "\n")

    def save_frame(self, frame_number, frame, detections):
        if not self.frames_dir:
            return
        if self.frames_written % self.save_frame_every != 0:
            return

        annotated = frame.copy()
        for det in detections:
            x1 = int(round(det["x1"]))
            y1 = int(round(det["y1"]))
            x2 = int(round(det["x2"]))
            y2 = int(round(det["y2"]))
            cv2.rectangle(annotated, (x1, y1), (x2, y2), (0, 255, 255), 2)
            cv2.putText(
                annotated,
                f"{det['class_name']} {det['confidence']:.2f}",
                (x1, max(20, y1 - 6)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 255, 255),
                2,
                cv2.LINE_AA,
            )

        image_path = os.path.join(self.frames_dir, f"frame_{int(frame_number):06d}.jpg")
        if cv2.imwrite(image_path, annotated):
            self.images_written += 1

    def write(self, frame_number, timestamp_ms, frame, detections):
        self.write_meta_once(frame.shape)
        self.write_jsonl(frame_number, timestamp_ms, frame.shape, detections)
        self.save_frame(frame_number, frame, detections)
        self.frames_written += 1
        self.detections_written += len(detections)

    def close(self):
        if self.file is not None:
            self.file.flush()
            self.file.close()
            self.file = None
        if self.export_path or self.frames_dir:
            print(
                f"DETECTION_EXPORT_FINAL|frames={self.frames_written}|"
                f"detections={self.detections_written}|images={self.images_written}",
                flush=True,
            )


def bbox_iou(box_a, box_b):
    ax1, ay1, ax2, ay2 = box_a
    bx1, by1, bx2, by2 = box_b

    inter_x1 = max(ax1, bx1)
    inter_y1 = max(ay1, by1)
    inter_x2 = min(ax2, bx2)
    inter_y2 = min(ay2, by2)

    inter_w = max(0.0, inter_x2 - inter_x1)
    inter_h = max(0.0, inter_y2 - inter_y1)
    inter_area = inter_w * inter_h

    area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    denom = area_a + area_b - inter_area
    if denom <= 0.0:
        return 0.0

    return inter_area / denom


def bbox_center_distance(box_a, box_b):
    ax1, ay1, ax2, ay2 = box_a
    bx1, by1, bx2, by2 = box_b
    acx = (ax1 + ax2) / 2.0
    acy = (ay1 + ay2) / 2.0
    bcx = (bx1 + bx2) / 2.0
    bcy = (by1 + by2) / 2.0
    return float(np.hypot(acx - bcx, acy - bcy))


def transform_bbox(box, matrix, frame_shape):
    h, w = frame_shape[:2]
    x1, y1, x2, y2 = box
    points = np.array(
        [[[x1, y1]], [[x2, y1]], [[x2, y2]], [[x1, y2]]],
        dtype=np.float32,
    )
    transformed = cv2.transform(points, matrix).reshape(-1, 2)
    xs = transformed[:, 0]
    ys = transformed[:, 1]
    nx1 = int(np.clip(round(float(xs.min())), 0, w - 1))
    ny1 = int(np.clip(round(float(ys.min())), 0, h - 1))
    nx2 = int(np.clip(round(float(xs.max())), 0, w - 1))
    ny2 = int(np.clip(round(float(ys.max())), 0, h - 1))
    if nx2 <= nx1 or ny2 <= ny1:
        return box
    return (nx1, ny1, nx2, ny2)


class ORBGlobalMotionCompensator:
    def __init__(self, max_features=500, resize_width=640, min_matches=12):
        self.max_features = int(max_features)
        self.resize_width = int(resize_width)
        self.min_matches = int(min_matches)
        self.orb = cv2.ORB_create(nfeatures=self.max_features)
        self.matcher = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
        self.prev_gray = None
        self.prev_scale = 1.0

    def _prepare(self, frame):
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape[:2]
        if self.resize_width > 0 and w > self.resize_width:
            scale = self.resize_width / float(w)
            new_h = max(1, int(h * scale))
            gray = cv2.resize(gray, (self.resize_width, new_h), interpolation=cv2.INTER_AREA)
            return gray, scale
        return gray, 1.0

    def estimate(self, frame):
        gray, scale = self._prepare(frame)
        if self.prev_gray is None:
            self.prev_gray = gray
            self.prev_scale = scale
            return None

        kp_prev, des_prev = self.orb.detectAndCompute(self.prev_gray, None)
        kp_curr, des_curr = self.orb.detectAndCompute(gray, None)
        self.prev_gray = gray
        self.prev_scale = scale

        if des_prev is None or des_curr is None:
            return None

        matches = self.matcher.match(des_prev, des_curr)
        if len(matches) < self.min_matches:
            return None

        matches = sorted(matches, key=lambda m: m.distance)[:80]
        prev_pts = np.float32([kp_prev[m.queryIdx].pt for m in matches]).reshape(-1, 1, 2)
        curr_pts = np.float32([kp_curr[m.trainIdx].pt for m in matches]).reshape(-1, 1, 2)
        matrix, _ = cv2.estimateAffinePartial2D(
            prev_pts,
            curr_pts,
            method=cv2.RANSAC,
            ransacReprojThreshold=3.0,
        )
        if matrix is None:
            return None

        inv_scale = 1.0 / max(scale, 1e-6)
        matrix = matrix.astype(np.float32)
        matrix[0, 2] *= inv_scale
        matrix[1, 2] *= inv_scale
        return matrix


def bbox_properties(box):
    x1, y1, x2, y2 = [float(v) for v in box]
    width = max(1.0, x2 - x1)
    height = max(1.0, y2 - y1)
    area = width * height
    return {
        "center": ((x1 + x2) * 0.5, (y1 + y2) * 0.5),
        "width": width,
        "height": height,
        "area": area,
        "aspect": width / max(height, 1.0),
    }


def clamp_bbox(box, frame_shape):
    h, w = frame_shape[:2]
    x1, y1, x2, y2 = [int(round(float(v))) for v in box]
    x1 = max(0, min(w - 1, x1))
    y1 = max(0, min(h - 1, y1))
    x2 = max(x1 + 1, min(w, x2))
    y2 = max(y1 + 1, min(h, y2))
    return (x1, y1, x2, y2)


def predict_bbox_from_info(
    info,
    current_frame_index,
    frame_shape,
    prediction_mode="hold",
    max_shift_per_frame=8.0,
    max_total_shift_ratio=0.35,
):
    bbox = info.get("bbox")
    if bbox is None:
        return None
    if prediction_mode == "hold":
        return clamp_bbox(bbox, frame_shape)

    velocity = info.get("velocity", (0.0, 0.0))
    lost_frame_index = int(info.get("lost_frame_index", info.get("frame_index", current_frame_index)))
    missed_frames = max(0, int(current_frame_index) - lost_frame_index)
    vx = max(-max_shift_per_frame, min(max_shift_per_frame, float(velocity[0])))
    vy = max(-max_shift_per_frame, min(max_shift_per_frame, float(velocity[1])))
    x1, y1, x2, y2 = [float(v) for v in bbox]
    props = bbox_properties(bbox)
    max_total_shift = max(8.0, np.sqrt(props["area"]) * max_total_shift_ratio)
    decay = max(0.0, 1.0 - missed_frames / 30.0)
    dx = max(-max_total_shift, min(max_total_shift, vx * missed_frames * decay))
    dy = max(-max_total_shift, min(max_total_shift, vy * missed_frames * decay))
    return clamp_bbox((x1 + dx, y1 + dy, x2 + dx, y2 + dy), frame_shape)


def hsv_crop_descriptor(frame, box, crop_size=64):
    if frame is None:
        return None
    h, w = frame.shape[:2]
    x1, y1, x2, y2 = [int(round(float(v))) for v in box]
    x1 = max(0, min(w - 1, x1))
    y1 = max(0, min(h - 1, y1))
    x2 = max(0, min(w, x2))
    y2 = max(0, min(h, y2))
    if x2 <= x1 or y2 <= y1:
        return None

    crop = frame[y1:y2, x1:x2]
    if crop.size == 0:
        return None
    if max(crop.shape[:2]) > crop_size:
        crop = cv2.resize(crop, (crop_size, crop_size), interpolation=cv2.INTER_AREA)
    hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
    hist = cv2.calcHist([hsv], [0, 1], None, [12, 8], [0, 180, 0, 256])
    cv2.normalize(hist, hist, alpha=0.0, beta=1.0, norm_type=cv2.NORM_MINMAX)
    return hist.astype(np.float32).flatten()


def descriptor_similarity(desc_a, desc_b):
    if desc_a is None or desc_b is None:
        return 0.5
    denom = float(np.linalg.norm(desc_a) * np.linalg.norm(desc_b))
    if denom <= 1e-9:
        return 0.5
    value = float(np.dot(desc_a, desc_b) / denom)
    return max(0.0, min(1.0, value))


class LegacyUniqueBovineTracker:
    def __init__(self, max_missed=20, min_iou=0.10, max_distance=120.0):
        self.max_missed = int(max_missed)
        self.min_iou = float(min_iou)
        self.max_distance = float(max_distance)
        self.next_track_id = 1
        self.total_count = 0
        self.tracks = {}
        self.stats = {
            "tracks_created": 0,
            "tracks_recovered": 0,
            "tracks_removed": 0,
            "reid_matches": 0,
            "reid_rejects": 0,
        }

    def _create_track(self, det):
        track_id = self.next_track_id
        self.next_track_id += 1
        self.stats["tracks_created"] += 1

        self.tracks[track_id] = {
            "id": track_id,
            "bbox": det[:4],
            "score": float(det[4]),
            "cls_id": int(det[5]),
            "missed": 0,
            "age": 1,
            "counted": True,
        }
        self.total_count += 1

    def _match_score(self, track_box, det_box):
        iou = bbox_iou(track_box, det_box)
        dist = bbox_center_distance(track_box, det_box)

        if iou < self.min_iou and dist > self.max_distance:
            return None

        # Priorizamos IoU, pero permitimos match por proximidad para tolerar
        # movimiento de dron y pequeños saltos entre frames.
        return iou - (dist / max(self.max_distance, 1.0)) * 0.05

    def update(self, detections, frame=None):
        track_ids = list(self.tracks.keys())
        unmatched_tracks = set(track_ids)
        unmatched_detections = set(range(len(detections)))
        candidates = []

        for track_id in track_ids:
            track = self.tracks[track_id]
            for det_idx, det in enumerate(detections):
                score = self._match_score(track["bbox"], det[:4])
                if score is None:
                    continue
                candidates.append((score, track_id, det_idx))

        candidates.sort(reverse=True, key=lambda item: item[0])

        for _, track_id, det_idx in candidates:
            if track_id not in unmatched_tracks or det_idx not in unmatched_detections:
                continue

            det = detections[det_idx]
            track = self.tracks[track_id]
            track["bbox"] = det[:4]
            track["score"] = float(det[4])
            track["cls_id"] = int(det[5])
            track["missed"] = 0
            track["age"] += 1

            unmatched_tracks.remove(track_id)
            unmatched_detections.remove(det_idx)

        for track_id in list(unmatched_tracks):
            track = self.tracks.get(track_id)
            if track is None:
                continue
            track["missed"] += 1
            track["age"] += 1
            if track["missed"] > self.max_missed:
                self.stats["tracks_removed"] += 1
                self.tracks.pop(track_id, None)

        for det_idx in sorted(unmatched_detections):
            self._create_track(detections[det_idx])

        active_tracks = [
            dict(track)
            for track in self.tracks.values()
            if track["missed"] == 0
        ]
        return active_tracks, self.total_count

    def summary_fields(self):
        fields = dict(self.stats)
        fields["unique_bovines"] = self.total_count
        return fields


class PersistentBovineTracker:
    def __init__(
        self,
        max_missed=20,
        min_iou=0.10,
        max_distance=120.0,
        min_hits=3,
        track_high_thresh=0.45,
        track_low_thresh=0.20,
        match_thresh=0.10,
        gmc_method="orb",
        verbose_tracking=False,
    ):
        self.max_missed = int(max_missed)
        self.min_iou = float(min_iou)
        self.max_distance = float(max_distance)
        self.min_hits = max(1, int(min_hits))
        self.track_high_thresh = float(track_high_thresh)
        self.track_low_thresh = float(track_low_thresh)
        self.match_thresh = float(match_thresh)
        self.next_track_id = 1
        self.total_count = 0
        self.tracks = {}
        self.counted_track_ids = set()
        self.gmc = ORBGlobalMotionCompensator() if gmc_method == "orb" else None
        self.gmc_method = gmc_method
        self.verbose_tracking = bool(verbose_tracking)
        self.stats = {
            "tracks_created": 0,
            "tracks_recovered": 0,
            "tracks_removed": 0,
            "reid_matches": 0,
            "reid_rejects": 0,
        }

    def _event(self, name, **fields):
        quiet_events = {"TRACK_CREATE", "TRACK_CONFIRM", "TRACK_LOST", "TRACK_RECOVER", "TRACK_REMOVED"}
        if not self.verbose_tracking and name in quiet_events:
            return
        values = "|".join(f"{key}={value}" for key, value in fields.items())
        print(f"{name}|{values}" if values else name, flush=True)

    def _create_track(self, det):
        track_id = self.next_track_id
        self.next_track_id += 1
        self.stats["tracks_created"] += 1
        self.tracks[track_id] = {
            "id": track_id,
            "bbox": det[:4],
            "score": float(det[4]),
            "cls_id": int(det[5]),
            "missed": 0,
            "age": 1,
            "hits": 1,
            "state": "tentative",
            "counted": False,
        }
        self._event("TRACK_CREATE", id=track_id, score=f"{float(det[4]):.3f}")
        self._confirm_if_ready(self.tracks[track_id])

    def _confirm_if_ready(self, track):
        if track["state"] == "confirmed":
            return
        if track["hits"] < self.min_hits:
            return

        track["state"] = "confirmed"
        self._event("TRACK_CONFIRM", id=track["id"], hits=track["hits"])
        self._count_track(track)

    def _count_track(self, track):
        track_id = track["id"]
        if track_id in self.counted_track_ids:
            self._event("COUNT_REJECTED_ALREADY_COUNTED", id=track_id)
            return

        self.counted_track_ids.add(track_id)
        track["counted"] = True
        self.total_count += 1
        self._event("COUNT_ACCEPTED", id=track_id, count=self.total_count)
        print(
            f"COUNT_UPDATE|count={self.total_count}|track_id={track_id}|"
            f"reason=track_confirmed",
            flush=True,
        )

    def _match_score(self, track_box, det_box):
        iou = bbox_iou(track_box, det_box)
        dist = bbox_center_distance(track_box, det_box)

        if iou < self.min_iou and dist > self.max_distance:
            return None
        if iou < self.match_thresh and dist > self.max_distance * 0.60:
            return None

        return iou - (dist / max(self.max_distance, 1.0)) * 0.05

    def _apply_gmc(self, frame):
        if self.gmc is None or frame is None:
            return
        matrix = self.gmc.estimate(frame)
        if matrix is None:
            return
        for track in self.tracks.values():
            if track["state"] == "removed":
                continue
            track["bbox"] = transform_bbox(track["bbox"], matrix, frame.shape)

    def update(self, detections, frame=None):
        self._apply_gmc(frame)
        usable_detections = [
            det for det in detections
            if float(det[4]) >= self.track_low_thresh
        ]

        track_ids = [
            track_id for track_id, track in self.tracks.items()
            if track["state"] != "removed"
        ]
        unmatched_tracks = set(track_ids)
        unmatched_detections = set(range(len(usable_detections)))
        candidates = []

        for track_id in track_ids:
            track = self.tracks[track_id]
            for det_idx, det in enumerate(usable_detections):
                score = self._match_score(track["bbox"], det[:4])
                if score is None:
                    continue
                candidates.append((score, track_id, det_idx))

        candidates.sort(reverse=True, key=lambda item: item[0])

        for _, track_id, det_idx in candidates:
            if track_id not in unmatched_tracks or det_idx not in unmatched_detections:
                continue

            det = usable_detections[det_idx]
            track = self.tracks[track_id]
            was_lost = track["state"] == "lost"
            track["bbox"] = det[:4]
            track["score"] = float(det[4])
            track["cls_id"] = int(det[5])
            track["missed"] = 0
            track["age"] += 1
            track["hits"] += 1
            if was_lost:
                track["state"] = "confirmed"
                self.stats["tracks_recovered"] += 1
                self._event("TRACK_RECOVER", id=track_id, hits=track["hits"])
            self._confirm_if_ready(track)

            unmatched_tracks.remove(track_id)
            unmatched_detections.remove(det_idx)

        for track_id in list(unmatched_tracks):
            track = self.tracks.get(track_id)
            if track is None or track["state"] == "removed":
                continue
            track["missed"] += 1
            track["age"] += 1
            if track["missed"] > self.max_missed:
                track["state"] = "removed"
                self.stats["tracks_removed"] += 1
                self._event("TRACK_REMOVED", id=track_id, missed=track["missed"])
            elif track["state"] == "confirmed":
                track["state"] = "lost"
                self._event("TRACK_LOST", id=track_id, missed=track["missed"])

        for det_idx in sorted(unmatched_detections):
            det = usable_detections[det_idx]
            if float(det[4]) < self.track_high_thresh:
                continue
            self._create_track(det)

        active_tracks = [
            dict(track)
            for track in self.tracks.values()
            if track["state"] != "removed" and track["missed"] == 0
        ]
        return active_tracks, self.total_count

    def summary_fields(self):
        fields = dict(self.stats)
        fields["unique_bovines"] = self.total_count
        return fields


class RoboflowBoTSORTBovineTracker:
    def __init__(
        self,
        track_buffer=120,
        frame_rate=30.0,
        track_min_iou=0.05,
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
    ):
        import supervision as sv
        from trackers import BoTSORTTracker

        self.sv = sv
        self.track_low_thresh = float(track_low_thresh)
        self.identity_counted_ids = set()
        self.visible_track_ids = set()
        self.lost_track_ids = set()
        self.lost_missed = {}
        self.track_to_identity = {}
        self.active_track_info = {}
        self.identity_memory = {}
        self.known_identity_ids = set()
        self.total_count = 0
        self.track_buffer = int(track_buffer)
        self.enable_cmc = gmc_method != "none"
        self.reid_enabled = bool(reid_enabled)
        self.reid_max_seconds = float(reid_max_seconds)
        self.reid_threshold = float(reid_threshold)
        self.show_lost_tracks = bool(show_lost_tracks)
        self.lost_track_max_seconds = float(lost_track_max_seconds)
        self.lost_track_prediction = str(lost_track_prediction).lower().strip()
        self.verbose_tracking = bool(verbose_tracking)
        self.next_identity_id = 1
        self.frame_index = 0
        self.stats = {
            "tracks_created": 0,
            "tracks_recovered": 0,
            "tracks_removed": 0,
            "reid_matches": 0,
            "reid_rejects": 0,
            "lost_display_frames": 0,
        }

        self.tracker = BoTSORTTracker(
            lost_track_buffer=int(track_buffer),
            frame_rate=float(frame_rate),
            track_activation_threshold=float(track_high_thresh),
            minimum_consecutive_frames=max(1, int(track_min_hits)),
            minimum_iou_threshold_first_assoc=float(match_thresh),
            minimum_iou_threshold_second_assoc=float(max(track_min_iou, match_thresh)),
            minimum_iou_threshold_unconfirmed_assoc=float(max(track_min_iou, match_thresh)),
            high_conf_det_threshold=float(track_high_thresh),
            enable_cmc=self.enable_cmc,
            cmc_method="orb" if gmc_method == "orb" else "sparseOptFlow",
            cmc_downscale=2,
            instant_first_frame_activation=False,
        )
        print(
            f"[TRACKER] BoT-SORT activo: cmc={self.enable_cmc} "
            f"method={gmc_method} buffer={track_buffer} min_hits={track_min_hits} "
            f"reid={self.reid_enabled} lost_display={self.show_lost_tracks} "
            f"lost_prediction={self.lost_track_prediction}",
            flush=True,
        )

    def _event(self, name, **fields):
        quiet_events = {
            "TRACK_CREATE",
            "TRACK_CONFIRM",
            "TRACK_LOST",
            "TRACK_RECOVER",
            "TRACK_REMOVED",
            "REID_REJECT",
        }
        if not self.verbose_tracking and name in quiet_events:
            return
        values = "|".join(f"{key}={value}" for key, value in fields.items())
        print(f"{name}|{values}" if values else name, flush=True)

    def _new_identity_id(self, preferred_id):
        preferred_id = int(preferred_id)
        if preferred_id not in self.known_identity_ids:
            identity_id = preferred_id
        else:
            while self.next_identity_id in self.known_identity_ids:
                self.next_identity_id += 1
            identity_id = self.next_identity_id
        self.known_identity_ids.add(identity_id)
        self.next_identity_id = max(self.next_identity_id, identity_id + 1)
        return identity_id

    def _build_track_info(self, track_id, bbox, score, cls_id, frame):
        props = bbox_properties(bbox)
        prev_info = self.active_track_info.get(int(track_id)) or self.identity_memory.get(
            self.track_to_identity.get(int(track_id))
        )
        velocity = (0.0, 0.0)
        if prev_info is not None:
            prev_center = prev_info.get("center")
            prev_frame_index = int(prev_info.get("frame_index", self.frame_index))
            frame_delta = max(1, self.frame_index - prev_frame_index)
            if prev_center is not None:
                velocity = (
                    (props["center"][0] - float(prev_center[0])) / frame_delta,
                    (props["center"][1] - float(prev_center[1])) / frame_delta,
                )
        return {
            "track_id": int(track_id),
            "bbox": tuple(int(round(float(v))) for v in bbox),
            "center": props["center"],
            "width": props["width"],
            "height": props["height"],
            "area": props["area"],
            "aspect": props["aspect"],
            "score": float(score),
            "cls_id": int(cls_id),
            "frame_index": self.frame_index,
            "timestamp": time.time(),
            "velocity": velocity,
            "descriptor": hsv_crop_descriptor(frame, bbox),
        }

    def _save_identity_memory(self, track_id):
        identity_id = self.track_to_identity.get(track_id)
        info = self.active_track_info.get(track_id)
        if identity_id is None or info is None:
            return
        stored = dict(info)
        stored["identity_id"] = identity_id
        stored["lost_timestamp"] = time.time()
        stored["lost_frame_index"] = self.frame_index
        self.identity_memory[identity_id] = stored

    def _cleanup_identity_memory(self):
        now = time.time()
        active_identities = set(self.track_to_identity.get(tid) for tid in self.visible_track_ids)
        active_identities.discard(None)
        for identity_id, info in list(self.identity_memory.items()):
            if identity_id in active_identities:
                self.identity_memory.pop(identity_id, None)
                continue
            age_s = now - float(info.get("lost_timestamp", info.get("timestamp", now)))
            if age_s > self.reid_max_seconds:
                self.identity_memory.pop(identity_id, None)

    def _reid_score(self, new_info, old_info):
        now = time.time()
        dt = now - float(old_info.get("lost_timestamp", old_info.get("timestamp", now)))
        if dt < 0.0 or dt > self.reid_max_seconds:
            return None
        if int(new_info["cls_id"]) != int(old_info.get("cls_id", new_info["cls_id"])):
            return None

        nx, ny = new_info["center"]
        ox, oy = old_info["center"]
        distance = float(np.hypot(nx - ox, ny - oy))
        dynamic_distance = max(
            80.0,
            np.sqrt(max(old_info.get("area", 1.0), new_info["area"])) * 1.8 + 35.0 * dt,
        )
        spatial_score = max(0.0, 1.0 - distance / dynamic_distance)

        area_ratio = min(new_info["area"], old_info.get("area", new_info["area"])) / max(
            new_info["area"], old_info.get("area", new_info["area"]), 1.0
        )
        aspect_old = max(float(old_info.get("aspect", new_info["aspect"])), 1e-6)
        aspect_new = max(float(new_info["aspect"]), 1e-6)
        aspect_score = max(0.0, 1.0 - min(abs(np.log(aspect_new / aspect_old)), 1.0))
        visual_score = descriptor_similarity(new_info.get("descriptor"), old_info.get("descriptor"))

        if area_ratio < 0.30 or aspect_score < 0.35:
            return None

        score = (
            0.35 * spatial_score
            + 0.25 * area_ratio
            + 0.15 * aspect_score
            + 0.25 * visual_score
        )
        return {
            "score": score,
            "distance": distance,
            "dt": dt,
            "spatial": spatial_score,
            "size": area_ratio,
            "aspect": aspect_score,
            "visual": visual_score,
        }

    def _match_recent_identity(self, new_info):
        if not self.reid_enabled:
            return None, None
        self._cleanup_identity_memory()
        candidates = []
        active_identities = set(self.track_to_identity.get(tid) for tid in self.visible_track_ids)
        for identity_id, old_info in self.identity_memory.items():
            if identity_id in active_identities:
                continue
            score_info = self._reid_score(new_info, old_info)
            if score_info is None:
                continue
            candidates.append((score_info["score"], identity_id, score_info))

        if not candidates:
            return None, None
        candidates.sort(reverse=True, key=lambda item: item[0])
        best_score, best_identity, best_info = candidates[0]
        second_score = candidates[1][0] if len(candidates) > 1 else -1.0
        if best_score >= self.reid_threshold and (best_score - second_score) >= 0.06:
            return best_identity, best_info
        self.stats["reid_rejects"] += 1
        self._event(
            "REID_REJECT",
            new_id=new_info["track_id"],
            best_id=best_identity,
            score=f"{best_score:.3f}",
            threshold=f"{self.reid_threshold:.3f}",
        )
        return None, best_info

    def _to_supervision(self, detections):
        usable = [
            det for det in detections
            if float(det[4]) >= self.track_low_thresh
        ]
        if not usable:
            try:
                return self.sv.Detections.empty()
            except AttributeError:
                return self.sv.Detections(
                    xyxy=np.empty((0, 4), dtype=np.float32),
                    confidence=np.array([], dtype=np.float32),
                    class_id=np.array([], dtype=int),
                )

        xyxy = np.array([det[:4] for det in usable], dtype=np.float32)
        confidence = np.array([float(det[4]) for det in usable], dtype=np.float32)
        class_id = np.array([int(det[5]) for det in usable], dtype=int)
        return self.sv.Detections(
            xyxy=xyxy,
            confidence=confidence,
            class_id=class_id,
        )

    def _count_confirmed_track(self, track_id):
        identity_id = self.track_to_identity.get(track_id, track_id)
        if identity_id in self.identity_counted_ids:
            self._event("COUNT_REJECTED_ALREADY_COUNTED", track_id=track_id, identity_id=identity_id)
            return
        self.identity_counted_ids.add(identity_id)
        self.total_count += 1
        print(
            f"COUNT_ACCEPTED|track_id={track_id}|identity_id={identity_id}|"
            f"count={self.total_count}",
            flush=True,
        )
        print(
            f"COUNT_UPDATE|count={self.total_count}|track_id={track_id}|"
            f"identity_id={identity_id}|"
            f"reason=botsort_confirmed",
            flush=True,
        )

    def _update_lifecycle_events(self, current_track_ids):
        recovered = current_track_ids & self.lost_track_ids
        for track_id in sorted(recovered):
            self.stats["tracks_recovered"] += 1
            self._event("TRACK_RECOVER", id=track_id)
            self.lost_track_ids.discard(track_id)
            self.lost_missed.pop(track_id, None)

        new_lost = self.visible_track_ids - current_track_ids
        for track_id in sorted(new_lost):
            self._event("TRACK_LOST", id=track_id, missed=1)
            self._save_identity_memory(track_id)
            self.lost_track_ids.add(track_id)
            self.lost_missed[track_id] = 1
            self.active_track_info.pop(track_id, None)

        for track_id in list(self.lost_track_ids):
            if track_id in current_track_ids:
                continue
            missed = self.lost_missed.get(track_id, 0) + 1
            self.lost_missed[track_id] = missed
            if missed > self.track_buffer:
                self.stats["tracks_removed"] += 1
                self._event("TRACK_REMOVED", id=track_id, missed=missed)
                self.lost_track_ids.discard(track_id)
                self.lost_missed.pop(track_id, None)

        self.visible_track_ids = set(current_track_ids)

    def _lost_display_tracks(self, frame):
        if not self.show_lost_tracks or frame is None:
            return []

        self._cleanup_identity_memory()
        now = time.time()
        active_identities = set(self.track_to_identity.get(tid) for tid in self.visible_track_ids)
        active_identities.discard(None)
        tracks = []

        for identity_id, info in sorted(self.identity_memory.items()):
            if identity_id in active_identities:
                continue
            age_s = now - float(info.get("lost_timestamp", info.get("timestamp", now)))
            if age_s < 0.0 or age_s > self.lost_track_max_seconds:
                continue
            bbox = predict_bbox_from_info(
                info,
                self.frame_index,
                frame.shape,
                prediction_mode=self.lost_track_prediction,
            )
            if bbox is None:
                continue
            missed_frames = max(1, self.frame_index - int(info.get("lost_frame_index", self.frame_index)))
            tracks.append(
                {
                    "id": identity_id,
                    "track_id": int(info.get("track_id", identity_id)),
                    "identity_id": identity_id,
                    "bbox": bbox,
                    "score": float(info.get("score", 0.0)),
                    "cls_id": int(info.get("cls_id", 0)),
                    "missed": missed_frames,
                    "age": missed_frames,
                    "hits": 0,
                    "state": "occluded",
                    "counted": identity_id in self.identity_counted_ids,
                    "visible": False,
                    "lost_age_s": age_s,
                }
            )

        self.stats["lost_display_frames"] += len(tracks)
        return tracks

    def update(self, detections, frame=None):
        self.frame_index += 1
        sv_detections = self._to_supervision(detections)
        tracked = self.tracker.update(
            sv_detections,
            frame=frame if self.enable_cmc else None,
        )

        tracker_ids = tracked.tracker_id
        if tracker_ids is None:
            self._update_lifecycle_events(set())
            return self._lost_display_tracks(frame), self.total_count

        active_tracks = []
        current_track_ids = set()
        confidences = tracked.confidence
        class_ids = tracked.class_id

        for idx, raw_track_id in enumerate(tracker_ids):
            track_id = int(raw_track_id)
            if track_id < 0:
                continue

            current_track_ids.add(track_id)
            score = 0.0 if confidences is None else float(confidences[idx])
            cls_id = 0 if class_ids is None else int(class_ids[idx])
            bbox = tuple(int(round(float(value))) for value in tracked.xyxy[idx])
            info = self._build_track_info(track_id, bbox, score, cls_id, frame)

            if track_id not in self.track_to_identity:
                self.stats["tracks_created"] += 1
                matched_identity, match_info = self._match_recent_identity(info)
                if matched_identity is not None:
                    self.track_to_identity[track_id] = matched_identity
                    self.stats["reid_matches"] += 1
                    print(
                        f"REID_MATCH|new_id={track_id}|old_id={matched_identity}|"
                        f"score={match_info['score']:.3f}|dt={match_info['dt']:.2f}|"
                        f"distance={match_info['distance']:.1f}",
                        flush=True,
                    )
                else:
                    identity_id = self._new_identity_id(track_id)
                    self.track_to_identity[track_id] = identity_id
                    print(
                        f"NEW_IDENTITY|track_id={track_id}|identity_id={identity_id}",
                        flush=True,
                    )

                self._event("TRACK_CONFIRM", id=track_id, identity_id=self.track_to_identity[track_id])
                self._count_confirmed_track(track_id)

            identity_id = self.track_to_identity.get(track_id, track_id)
            info["identity_id"] = identity_id
            self.active_track_info[track_id] = info
            active_tracks.append(
                {
                    "id": identity_id,
                    "track_id": track_id,
                    "identity_id": identity_id,
                    "bbox": bbox,
                    "score": score,
                    "cls_id": cls_id,
                    "missed": 0,
                    "age": 0,
                    "hits": 0,
                    "state": "confirmed",
                    "counted": identity_id in self.identity_counted_ids,
                    "visible": True,
                }
            )

        self._update_lifecycle_events(current_track_ids)
        active_tracks.extend(self._lost_display_tracks(frame))
        return active_tracks, self.total_count

    def summary_fields(self):
        return {
            "tracks_created": self.stats["tracks_created"],
            "tracks_recovered": self.stats["tracks_recovered"],
            "tracks_removed": self.stats["tracks_removed"],
            "reid_matches": self.stats["reid_matches"],
            "reid_rejects": self.stats["reid_rejects"],
            "lost_display_frames": self.stats["lost_display_frames"],
            "unique_bovines": self.total_count,
        }


def create_tracker(
    tracker_name,
    track_buffer,
    frame_rate,
    track_min_iou,
    track_max_distance,
    track_min_hits,
    track_high_thresh,
    track_low_thresh,
    match_thresh,
    gmc_method,
    reid_enabled,
    reid_max_seconds,
    reid_threshold,
    show_lost_tracks,
    lost_track_max_seconds,
    lost_track_prediction,
    verbose_tracking,
):
    if tracker_name == "none":
        print("[TRACKER] Modo legacy activado: conteo inmediato por track nuevo")
        return LegacyUniqueBovineTracker(
            max_missed=track_buffer,
            min_iou=track_min_iou,
            max_distance=track_max_distance,
        )

    if tracker_name == "botsort":
        try:
            return RoboflowBoTSORTBovineTracker(
                track_buffer=track_buffer,
                frame_rate=frame_rate,
                track_min_iou=track_min_iou,
                track_min_hits=track_min_hits,
                track_high_thresh=track_high_thresh,
                track_low_thresh=track_low_thresh,
                match_thresh=match_thresh,
                gmc_method=gmc_method,
                reid_enabled=reid_enabled,
                reid_max_seconds=reid_max_seconds,
                reid_threshold=reid_threshold,
                show_lost_tracks=show_lost_tracks,
                lost_track_max_seconds=lost_track_max_seconds,
                lost_track_prediction=lost_track_prediction,
                verbose_tracking=verbose_tracking,
            )
        except Exception as exc:
            print(
                "[TRACKER] No se pudo activar BoT-SORT real "
                f"({type(exc).__name__}: {exc}); usando tracker simple interno",
                flush=True,
            )
    else:
        print("[TRACKER] Usando tracker persistente interno")

    return PersistentBovineTracker(
        max_missed=track_buffer,
        min_iou=track_min_iou,
        max_distance=track_max_distance,
        min_hits=track_min_hits,
        track_high_thresh=track_high_thresh,
        track_low_thresh=track_low_thresh,
        match_thresh=match_thresh,
        gmc_method=gmc_method,
        verbose_tracking=verbose_tracking,
    )


# ============================================================
# Hilos
# ============================================================
def capture_worker(
    source,
    codec,
    latency,
    frame_q,
    stop_event,
    csi_sensor_id=0,
    csi_width=1920,
    csi_height=1080,
    csi_fps=30,
    csi_flip=0,
    stop_reason=None,
    processing_width=0,
    processing_height=0,
    realtime_video=False,
    playback_speed=1.0,
    video_mode="realtime",
    hw_decode=False,
):
    cap, used = open_video_source(
        source,
        codec=codec,
        latency=latency,
        csi_sensor_id=csi_sensor_id,
        csi_width=csi_width,
        csi_height=csi_height,
        csi_fps=csi_fps,
        csi_flip=csi_flip,
        hw_decode=hw_decode,
    )

    if not cap.isOpened():
        print(f"[CAPTURA] No se pudo abrir la fuente: {source}")
        if stop_reason is not None:
            stop_reason["value"] = "capture_open_failed"
        emit_worker_status("error", "capture_open_failed")
        stop_event.set()
        return

    local_file = is_local_file_source(source)
    pending_frame = None
    if local_file and hw_decode and used != source:
        ok, pending_frame = cap.read()
        if not ok or pending_frame is None:
            print("[CAPTURA] HW decode no entregó frames; usando cv2.VideoCapture fallback")
            cap.release()
            cap = cv2.VideoCapture(source)
            used = source
            if not cap.isOpened():
                print(f"[CAPTURA] No se pudo abrir la fuente: {source}")
                if stop_reason is not None:
                    stop_reason["value"] = "capture_open_failed"
                emit_worker_status("error", "capture_open_failed")
                stop_event.set()
                return
            pending_frame = None

    print("[CAPTURA] Fuente abierta correctamente")
    print(f"[CAPTURA] Usando: {used}")
    emit_worker_status("capture_ready", "source_opened")
    source_fps = float(cap.get(cv2.CAP_PROP_FPS) or 0.0)
    source_frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    update_perf_stats(source_fps=source_fps, source_frame_count=source_frame_count)

    try:
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    except Exception:
        pass

    low_latency = is_live_source(source) or (local_file and video_mode == "realtime")
    sync_to_video_time = local_file and (realtime_video or video_mode == "realtime")
    speed = max(float(playback_speed), 1e-6)
    first_video_msec = None
    first_wall_time = None
    frame_index = 0
    last_pos_msec = None

    try:
        while not stop_event.is_set():
            if pending_frame is not None:
                ok, frame = True, pending_frame
                pending_frame = None
            else:
                ok, frame = cap.read()
            if not ok or frame is None:
                if local_file and hw_decode and used != source and frame_index <= 2:
                    print("[CAPTURA] HW decode se detuvo al inicio; usando cv2.VideoCapture fallback")
                    cap.release()
                    cap = cv2.VideoCapture(source)
                    used = source
                    if not cap.isOpened():
                        if stop_reason is not None:
                            stop_reason["value"] = "capture_open_failed"
                        emit_worker_status("error", "capture_open_failed")
                        stop_event.set()
                        break
                    source_fps = float(cap.get(cv2.CAP_PROP_FPS) or source_fps)
                    source_frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or source_frame_count)
                    update_perf_stats(source_fps=source_fps, source_frame_count=source_frame_count)
                    frame_index = 0
                    continue
                if local_file:
                    if stop_reason is not None and stop_reason.get("value") == "finished":
                        stop_reason["value"] = "eof"
                    while not stop_event.is_set():
                        try:
                            frame_q.put(EOS_FRAME, timeout=0.2)
                            break
                        except queue.Full:
                            if low_latency:
                                try:
                                    frame_q.get_nowait()
                                    update_perf_stats(frames_dropped=1)
                                except queue.Empty:
                                    pass
                    break
                time.sleep(0.01)
                continue

            update_perf_stats(frames_read=1)
            frame_index += 1
            pos_msec = float(cap.get(cv2.CAP_PROP_POS_MSEC) or 0.0)
            if source_fps > 0.0:
                fallback_msec = (frame_index / source_fps) * 1000.0
                if pos_msec <= 0.0 or (last_pos_msec is not None and pos_msec <= last_pos_msec):
                    pos_msec = fallback_msec
            last_pos_msec = pos_msec

            if sync_to_video_time:
                if first_video_msec is None:
                    first_video_msec = pos_msec
                    first_wall_time = time.perf_counter()
                target_time = first_wall_time + ((pos_msec - first_video_msec) / 1000.0) / speed
                sleep_s = target_time - time.perf_counter()
                if sleep_s > 0.0:
                    time.sleep(min(sleep_s, 0.25))

            frame = resize_for_processing(frame, processing_width, processing_height)
            frame_packet = {
                "frame": frame,
                "frame_index": frame_index,
                "timestamp_ms": pos_msec,
            }

            if low_latency and frame_q.full():
                try:
                    frame_q.get_nowait()
                    update_perf_stats(frames_dropped=1)
                except queue.Empty:
                    pass

            while not stop_event.is_set():
                try:
                    frame_q.put(frame_packet, timeout=0.2)
                    break
                except queue.Full:
                    if low_latency:
                        try:
                            frame_q.get_nowait()
                            update_perf_stats(frames_dropped=1)
                        except queue.Empty:
                            pass
                    else:
                        continue
    finally:
        cap.release()
        print("[CAPTURA] Cerrado")


def infer_worker(
    engine_path,
    frame_q,
    vis_q,
    stop_event,
    conf_th,
    box_format,
    tracker_name,
    track_max_missed,
    track_min_iou,
    track_max_distance,
    track_min_hits,
    track_high_thresh,
    track_low_thresh,
    track_buffer,
    match_thresh,
    gmc_method,
    tracker_frame_rate,
    reid_enabled,
    reid_max_seconds,
    reid_threshold,
    show_lost_tracks,
    lost_track_max_seconds,
    lost_track_prediction,
    verbose_tracking,
    display_enabled,
    export_detections_path=None,
    save_detection_frames_dir=None,
    save_frame_every=1,
    source="",
    video_mode="",
    processing_width=0,
    processing_height=0,
    stop_reason=None,
):
    detector = None
    tracker = None
    detection_exporter = None
    try:
        detector = TRTDetector(engine_path)
        resolved_track_buffer = (
            track_max_missed if track_buffer is None else track_buffer
        )
        tracker = create_tracker(
            tracker_name=tracker_name,
            track_buffer=resolved_track_buffer,
            frame_rate=tracker_frame_rate,
            track_min_iou=track_min_iou,
            track_max_distance=track_max_distance,
            track_min_hits=track_min_hits,
            track_high_thresh=track_high_thresh,
            track_low_thresh=track_low_thresh,
            match_thresh=match_thresh,
            gmc_method=gmc_method,
            reid_enabled=reid_enabled,
            reid_max_seconds=reid_max_seconds,
            reid_threshold=reid_threshold,
            show_lost_tracks=show_lost_tracks,
            lost_track_max_seconds=lost_track_max_seconds,
            lost_track_prediction=lost_track_prediction,
            verbose_tracking=verbose_tracking,
        )
        if export_detections_path or save_detection_frames_dir:
            detection_exporter = DetectionExporter(
                export_path=export_detections_path,
                frames_dir=save_detection_frames_dir,
                save_frame_every=save_frame_every,
                engine_path=engine_path,
                source=source,
                confidence_threshold=conf_th,
                box_format=box_format,
                processing_width=processing_width,
                processing_height=processing_height,
                video_mode=video_mode,
            )
        emit_worker_status("running", "detector_ready")
        t0 = time.time()
        last_status_at = 0.0
        last_metric_at = 0.0
        frames = 0
        fps = 0.0
        metric_samples = 0
        inference_ms_sum = 0.0
        tracking_ms_sum = 0.0
        total_ms_sum = 0.0
        processed_frames = 0

        while not stop_event.is_set():
            try:
                item = frame_q.get(timeout=0.2)
            except queue.Empty:
                continue
            if item is EOS_FRAME:
                if stop_reason is not None and stop_reason.get("value") == "finished":
                    stop_reason["value"] = "eof"
                stop_event.set()
                break
            if isinstance(item, dict) and "frame" in item:
                frame = item["frame"]
                frame_number = int(item.get("frame_index", processed_frames + 1))
                timestamp_ms = item.get("timestamp_ms")
            else:
                frame = item
                frame_number = processed_frames + 1
                timestamp_ms = None

            frame_t0 = time.perf_counter()
            inp = detector.preprocess(frame)
            inference_t0 = time.perf_counter()
            outputs = detector.infer(inp)
            inference_ms = (time.perf_counter() - inference_t0) * 1000.0
            export_dets = None
            if detection_exporter is not None:
                export_dets = decode_detections_for_export(
                    outputs,
                    frame.shape,
                    conf_th=conf_th,
                    box_format=box_format,
                )
                detection_exporter.write(frame_number, timestamp_ms, frame, export_dets)
            dets = decode_detections(outputs, frame.shape, conf_th=conf_th, box_format=box_format)

            count_visible = len(dets)
            tracking_t0 = time.perf_counter()
            active_tracks, total_count = tracker.update(dets, frame=frame)
            tracking_ms = (time.perf_counter() - tracking_t0) * 1000.0
            visible_tracks = sum(1 for track in active_tracks if track.get("visible", True))
            occluded_tracks = sum(1 for track in active_tracks if not track.get("visible", True))
            update_count_stats(count_visible, total_count)
            total_ms = (time.perf_counter() - frame_t0) * 1000.0
            metric_samples += 1
            inference_ms_sum += inference_ms
            tracking_ms_sum += tracking_ms
            total_ms_sum += total_ms
            now = time.time()
            if now - last_status_at >= 1.0:
                emit_worker_status(
                    "running",
                    "cumulative_count_available",
                    visible_count=count_visible,
                )
                last_status_at = now
            if now - last_metric_at >= 5.0:
                sample_count = max(metric_samples, 1)
                print(
                    f"TRACK_METRIC|tracker={tracker_name}|active={visible_tracks}|"
                    f"occluded={occluded_tracks}|"
                    f"count={total_count}|tracking_ms={tracking_ms_sum / sample_count:.2f}",
                    flush=True,
                )
                print(
                    f"INFERENCE_METRIC|inference_ms={inference_ms_sum / sample_count:.2f}",
                    flush=True,
                )
                print(
                    f"PIPELINE_METRIC|fps={fps:.2f}|"
                    f"inference_ms={inference_ms_sum / sample_count:.2f}|"
                    f"tracking_ms={tracking_ms_sum / sample_count:.2f}|"
                    f"total_frame_ms={total_ms_sum / sample_count:.2f}",
                    flush=True,
                )
                last_metric_at = now
                metric_samples = 0
                inference_ms_sum = 0.0
                tracking_ms_sum = 0.0
                total_ms_sum = 0.0

            if display_enabled:
                for track in active_tracks:
                    x1, y1, x2, y2 = track["bbox"]
                    score = track["score"]
                    track_id = track.get("track_id", track["id"])
                    identity_id = track.get("identity_id", track["id"])
                    state = track.get("state", "confirmed")
                    color = (0, 255, 0) if state == "confirmed" else (0, 200, 255)
                    cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                    if state == "occluded":
                        label = f"id {identity_id} occ {track.get('missed', 0)}f"
                    else:
                        label = f"id {identity_id} trk {track_id} {score:.2f}"
                    cv2.putText(
                        frame,
                        label,
                        (x1, max(25, y1 - 8)),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.7,
                        color,
                        2,
                        cv2.LINE_AA,
                    )

            frames += 1
            processed_frames += 1
            if frames >= 10:
                t1 = time.time()
                fps = frames / max(t1 - t0, 1e-6)
                t0 = t1
                frames = 0

            if display_enabled:
                cv2.putText(
                    frame,
                    f"Visible: {count_visible} | Acumulado: {total_count} | FPS: {fps:.2f}",
                    (20, 35),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.9,
                    (0, 0, 255),
                    2,
                    cv2.LINE_AA,
                )

                if vis_q.full():
                    try:
                        vis_q.get_nowait()
                    except queue.Empty:
                        pass

                try:
                    vis_q.put_nowait(frame)
                except queue.Full:
                    pass

    except Exception as e:
        print(f"[INFERENCIA] Error: {e}")
        if stop_reason is not None:
            stop_reason["value"] = "inference_error"
        emit_worker_status("error", "inference_error")
        stop_event.set()
    finally:
        if detection_exporter is not None:
            detection_exporter.close()
        if tracker is not None and hasattr(tracker, "summary_fields"):
            fields = tracker.summary_fields()
            print(
                "TRACK_FINAL|" + "|".join(f"{key}={value}" for key, value in fields.items()),
                flush=True,
            )
        if detector is not None:
            detector.close()
        print("[INFERENCIA] Cerrado")


def resize_frame_to_fit(frame, max_width, max_height):
    if max_width <= 0 or max_height <= 0:
        return frame

    height, width = frame.shape[:2]
    scale = min(max_width / width, max_height / height, 1.0)
    if scale >= 1.0:
        return frame

    new_width = max(1, int(width * scale))
    new_height = max(1, int(height * scale))
    return cv2.resize(frame, (new_width, new_height), interpolation=cv2.INTER_AREA)


def display_worker(
    vis_q,
    stop_event,
    window_name="Bovinos - Jetson Orin Nano",
    max_width=960,
    max_height=540,
):
    window_created = False
    try:
        while not stop_event.is_set():
            try:
                frame = vis_q.get(timeout=0.2)
            except queue.Empty:
                continue

            if not window_created:
                cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
                if max_width > 0 and max_height > 0:
                    cv2.resizeWindow(window_name, int(max_width), int(max_height))
                window_created = True

            frame = resize_frame_to_fit(frame, int(max_width), int(max_height))
            cv2.imshow(window_name, frame)
            key = cv2.waitKey(1) & 0xFF

            if key == ord("q") or key == 27:
                stop_event.set()
                break
    finally:
        if window_created:
            cv2.destroyAllWindows()
    print("[DISPLAY] Cerrado")


# ============================================================
# Main
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Detección bovina en tiempo real con TensorRT")
    parser.add_argument("--engine", required=True, help="Ruta al engine .engine")
    parser.add_argument("--source", required=True, help="Fuente: csi://0, rtsp://..., http://..., archivo, /dev/videoX, etc.")
    parser.add_argument("--codec", default="h264", choices=["h264", "h265"], help="Codec RTSP")
    parser.add_argument("--latency", type=int, default=120, help="Latencia RTSP")
    parser.add_argument("--csi-sensor-id", type=int, default=0, help="Sensor CSI para nvarguscamerasrc. CAM0 suele mapear a sensor-id=0.")
    parser.add_argument("--csi-width", type=int, default=1920, help="Ancho de captura CSI/IMX219 antes del resize del modelo")
    parser.add_argument("--csi-height", type=int, default=1080, help="Alto de captura CSI/IMX219 antes del resize del modelo")
    parser.add_argument("--csi-fps", type=int, default=30, help="FPS de captura CSI/IMX219")
    parser.add_argument("--csi-flip", type=int, default=0, help="flip-method de nvvidconv: 0 sin giro, 2 rota 180, etc.")
    parser.add_argument("--no-display", action="store_true", help="No abrir ventana OpenCV. Recomendado cuando se ejecuta por LoRa/servicio.")
    parser.add_argument("--display-width", type=int, default=960, help="Ancho máximo de la ventana OpenCV. Usa 0 para no limitar.")
    parser.add_argument("--display-height", type=int, default=540, help="Alto máximo de la ventana OpenCV. Usa 0 para no limitar.")
    parser.add_argument("--processing-width", type=int, default=0, help="Ancho de procesamiento antes de TensorRT/tracking. 0 conserva ancho capturado.")
    parser.add_argument("--processing-height", type=int, default=0, help="Alto de procesamiento antes de TensorRT/tracking. 0 conserva alto capturado.")
    parser.add_argument("--export-detections", default="", help="Ruta JSONL para exportar detecciones crudas TensorRT antes del tracker.")
    parser.add_argument("--save-detection-frames", default="", help="Directorio para guardar frames con cajas crudas del detector.")
    parser.add_argument("--save-frame-every", type=int, default=1, help="Guardar una imagen de detección cada N frames procesados.")
    parser.add_argument("--realtime-video", action="store_true", help="Para archivos locales, sincroniza lectura/procesamiento al tiempo del video.")
    parser.add_argument("--playback-speed", type=float, default=1.0, help="Velocidad temporal para --realtime-video: 1.0 original, 0.5 mitad, 2.0 doble.")
    parser.add_argument(
        "--video-mode",
        default="exhaustive",
        choices=["realtime", "exhaustive"],
        help="Solo archivos locales: realtime prioriza tiempo real; exhaustive procesa todos los frames sin descartar.",
    )
    parser.add_argument("--hw-decode", action="store_true", help="Intenta decodificar archivos H264/H265 con GStreamer/NVDEC y usa fallback automático.")
    parser.add_argument("--conf", type=float, default=0.45, help="Umbral de confianza")
    parser.add_argument("--box-format", default="yxyx", choices=["yxyx", "xyxy"], help="Formato de cajas")
    parser.add_argument(
        "--tracker",
        default="botsort",
        choices=["simple", "botsort", "none"],
        help="Tracker: botsort usa Roboflow Trackers si esta instalado; simple usa persistencia interna; none usa comportamiento legacy.",
    )
    parser.add_argument(
        "--track-max-missed",
        type=int,
        default=20,
        help="Frames que un bovino puede desaparecer antes de considerarlo nuevo",
    )
    parser.add_argument(
        "--track-min-iou",
        type=float,
        default=0.05,
        help="IoU mínima para asociar detecciones al mismo bovino",
    )
    parser.add_argument(
        "--track-max-distance",
        type=float,
        default=120.0,
        help="Distancia máxima en píxeles entre centros para mantener el mismo bovino",
    )
    parser.add_argument(
        "--track-min-hits",
        type=int,
        default=5,
        help="Detecciones consecutivas requeridas antes de confirmar y contar un track",
    )
    parser.add_argument(
        "--track-high-thresh",
        type=float,
        default=0.45,
        help="Confianza mínima para crear un track nuevo",
    )
    parser.add_argument(
        "--track-low-thresh",
        type=float,
        default=0.15,
        help="Confianza mínima para asociar detecciones a tracks existentes",
    )
    parser.add_argument(
        "--track-buffer",
        type=int,
        default=120,
        help="Frames que un track puede permanecer perdido antes de eliminarse",
    )
    parser.add_argument(
        "--match-thresh",
        type=float,
        default=0.08,
        help="IoU mínima preferida para asociación del tracker",
    )
    parser.add_argument(
        "--gmc",
        default="orb",
        choices=["orb", "none"],
        help="Compensación de movimiento global para cámara móvil",
    )
    parser.add_argument(
        "--reid",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Habilita/deshabilita memoria ligera de identidad para evitar doble conteo con BoT-SORT.",
    )
    parser.add_argument("--reid-max-seconds", type=float, default=10.0, help="Ventana temporal de reidentificación ligera.")
    parser.add_argument("--reid-threshold", type=float, default=0.72, help="Umbral mínimo para fusionar un track nuevo con una identidad perdida.")
    parser.add_argument(
        "--show-lost-tracks",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Dibuja cajas predictivas para identidades confirmadas temporalmente ocluidas.",
    )
    parser.add_argument(
        "--lost-track-max-seconds",
        type=float,
        default=5.0,
        help="Tiempo máximo para mostrar una caja predictiva de track perdido.",
    )
    parser.add_argument(
        "--lost-track-prediction",
        default="hold",
        choices=["hold", "linear"],
        help="Modo de caja para tracks perdidos: hold mantiene la última caja; linear extrapola de forma limitada.",
    )
    parser.add_argument("--verbose-tracking", action="store_true", help="Imprime eventos TRACK_* y REID_REJECT detallados.")
    args = parser.parse_args()

    reset_runtime_stats()
    effective_video_mode = "realtime" if args.realtime_video else args.video_mode
    local_file = is_local_file_source(args.source)
    frame_queue_size = EXHAUSTIVE_FRAME_QUEUE_SIZE if local_file and effective_video_mode == "exhaustive" else FRAME_QUEUE_SIZE
    frame_q = queue.Queue(maxsize=frame_queue_size)
    vis_q = queue.Queue(maxsize=VIS_QUEUE_SIZE)
    stop_event = threading.Event()
    stop_reason = {"value": "finished"}

    def handle_sigint(sig, frame):
        stop_reason["value"] = "signal"
        stop_event.set()

    signal.signal(signal.SIGINT, handle_sigint)
    signal.signal(signal.SIGTERM, handle_sigint)
    emit_worker_status("starting", "threads_starting")

    th_cap = threading.Thread(
        target=capture_worker,
        args=(
            args.source,
            args.codec,
            args.latency,
            frame_q,
            stop_event,
            args.csi_sensor_id,
            args.csi_width,
            args.csi_height,
            args.csi_fps,
            args.csi_flip,
            stop_reason,
            args.processing_width,
            args.processing_height,
            args.realtime_video,
            args.playback_speed,
            effective_video_mode,
            args.hw_decode,
        ),
    )
    th_inf = threading.Thread(
        target=infer_worker,
        args=(
            args.engine,
            frame_q,
            vis_q,
            stop_event,
            args.conf,
            args.box_format,
            args.tracker,
            args.track_max_missed,
            args.track_min_iou,
            args.track_max_distance,
            args.track_min_hits,
            args.track_high_thresh,
            args.track_low_thresh,
            args.track_buffer,
            args.match_thresh,
            args.gmc,
            args.csi_fps,
            args.reid,
            args.reid_max_seconds,
            args.reid_threshold,
            args.show_lost_tracks,
            args.lost_track_max_seconds,
            args.lost_track_prediction,
            args.verbose_tracking,
            not args.no_display,
            args.export_detections,
            args.save_detection_frames,
            args.save_frame_every,
            args.source,
            effective_video_mode,
            args.processing_width,
            args.processing_height,
            stop_reason,
        ),
    )
    th_vis = None
    if not args.no_display:
        th_vis = threading.Thread(
            target=display_worker,
            args=(vis_q, stop_event, "Bovinos - Jetson Orin Nano", args.display_width, args.display_height),
        )

    th_cap.start()
    th_inf.start()
    if th_vis is not None:
        th_vis.start()

    while not stop_event.is_set():
        time.sleep(0.2)

    th_cap.join(timeout=5.0)
    th_inf.join(timeout=5.0)
    if th_vis is not None:
        th_vis.join(timeout=5.0)

    emit_worker_result(stop_reason["value"])
    print("[MAIN] Finalizado")


if __name__ == "__main__":
    main()
