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
WORKER_SESSION_ID = os.getenv("BOVISENSE_SESSION_ID", "")
WORKER_STATUS_FILE = os.getenv("BOVISENSE_STATUS_FILE", "")
WORKER_RESULT_FILE = os.getenv("BOVISENSE_RESULT_FILE", "")
COUNT_STATS_LOCK = threading.Lock()
COUNT_STATS = {
    "last_visible_count": None,
    "max_visible_count": None,
    "frames_processed": 0,
}


def update_count_stats(visible_count):
    visible_count = int(visible_count)
    with COUNT_STATS_LOCK:
        COUNT_STATS["last_visible_count"] = visible_count
        current_max = COUNT_STATS["max_visible_count"]
        if current_max is None or visible_count > current_max:
            COUNT_STATS["max_visible_count"] = visible_count
        COUNT_STATS["frames_processed"] += 1


def current_count_stats():
    with COUNT_STATS_LOCK:
        return dict(COUNT_STATS)


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
        "count": stats["max_visible_count"],
        "last_visible_count": stats["last_visible_count"],
        "frames_processed": stats["frames_processed"],
    }
    if visible_count is not None:
        payload["visible_count"] = int(visible_count)

    fields = [f"status={status}"]
    if detail:
        fields.append(f"detail={detail}")
    if visible_count is not None:
        fields.append(f"visible_count={int(visible_count)}")
    if stats["max_visible_count"] is not None:
        fields.append(f"count={int(stats['max_visible_count'])}")
    print("WORKER_STATUS|" + "|".join(fields), flush=True)
    write_worker_json(WORKER_STATUS_FILE, payload)


def emit_worker_result(reason):
    stats = current_count_stats()
    final_count = stats["max_visible_count"]
    count_text = "unknown" if final_count is None else str(int(final_count))
    payload = {
        "session": WORKER_SESSION_ID,
        "status": "finished",
        "reason": reason,
        "count": final_count,
        "last_visible_count": stats["last_visible_count"],
        "frames_processed": stats["frames_processed"],
        "updatedAt": time.time(),
    }
    print(
        f"COUNT_FINAL|count={count_text}|reason={reason}|"
        f"frames={stats['frames_processed']}",
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


def open_video_source(source: str, codec: str = "h264", latency: int = 120):
    source = source.strip()

    if source.startswith("rtsp://"):
        pipeline = gst_pipeline_rtsp(source, codec=codec, latency=latency)
        cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
        used = pipeline
    else:
        # HTTP, archivo local, etc.
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


# ============================================================
# Hilos
# ============================================================
def capture_worker(source, codec, latency, frame_q, stop_event):
    cap, used = open_video_source(source, codec=codec, latency=latency)

    if not cap.isOpened():
        print(f"[CAPTURA] No se pudo abrir la fuente: {source}")
        emit_worker_status("error", "capture_open_failed")
        stop_event.set()
        return

    print("[CAPTURA] Fuente abierta correctamente")
    print(f"[CAPTURA] Usando: {used}")
    emit_worker_status("capture_ready", "source_opened")

    try:
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    except Exception:
        pass

    while not stop_event.is_set():
        ok, frame = cap.read()
        if not ok or frame is None:
            time.sleep(0.01)
            continue

        if frame_q.full():
            try:
                frame_q.get_nowait()
            except queue.Empty:
                pass

        try:
            frame_q.put_nowait(frame)
        except queue.Full:
            pass

    cap.release()
    print("[CAPTURA] Cerrado")


def infer_worker(engine_path, frame_q, vis_q, stop_event, conf_th, box_format):
    detector = None
    try:
        detector = TRTDetector(engine_path)
        emit_worker_status("running", "detector_ready")
        t0 = time.time()
        last_status_at = 0.0
        frames = 0
        fps = 0.0

        while not stop_event.is_set():
            try:
                frame = frame_q.get(timeout=0.2)
            except queue.Empty:
                continue

            inp = detector.preprocess(frame)
            outputs = detector.infer(inp)
            dets = decode_detections(outputs, frame.shape, conf_th=conf_th, box_format=box_format)

            count_visible = len(dets)
            update_count_stats(count_visible)
            now = time.time()
            if now - last_status_at >= 1.0:
                emit_worker_status(
                    "running",
                    "visible_count_available",
                    visible_count=count_visible,
                )
                last_status_at = now

            for (x1, y1, x2, y2, score, cls_id) in dets:
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                cv2.putText(
                    frame,
                    f"bovino {score:.2f}",
                    (x1, max(25, y1 - 8)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7,
                    (0, 255, 0),
                    2,
                    cv2.LINE_AA,
                )

            frames += 1
            if frames >= 10:
                t1 = time.time()
                fps = frames / max(t1 - t0, 1e-6)
                t0 = t1
                frames = 0

            cv2.putText(
                frame,
                f"Conteo visible: {count_visible} | FPS: {fps:.2f}",
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
        emit_worker_status("error", "inference_error")
        stop_event.set()
    finally:
        if detector is not None:
            detector.close()
        print("[INFERENCIA] Cerrado")


def display_worker(vis_q, stop_event, window_name="Bovinos - Jetson Orin Nano"):
    cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)

    while not stop_event.is_set():
        try:
            frame = vis_q.get(timeout=0.2)
        except queue.Empty:
            continue

        cv2.imshow(window_name, frame)
        key = cv2.waitKey(1) & 0xFF

        if key == ord("q") or key == 27:
            stop_event.set()
            break

    cv2.destroyAllWindows()
    print("[DISPLAY] Cerrado")


# ============================================================
# Main
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Detección bovina en tiempo real con TensorRT")
    parser.add_argument("--engine", required=True, help="Ruta al engine .engine")
    parser.add_argument("--source", required=True, help="Fuente: http://..., rtsp://..., archivo, etc.")
    parser.add_argument("--codec", default="h264", choices=["h264", "h265"], help="Codec RTSP")
    parser.add_argument("--latency", type=int, default=120, help="Latencia RTSP")
    parser.add_argument("--conf", type=float, default=0.45, help="Umbral de confianza")
    parser.add_argument("--box-format", default="yxyx", choices=["yxyx", "xyxy"], help="Formato de cajas")
    args = parser.parse_args()

    frame_q = queue.Queue(maxsize=FRAME_QUEUE_SIZE)
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
        args=(args.source, args.codec, args.latency, frame_q, stop_event),
        daemon=True,
    )
    th_inf = threading.Thread(
        target=infer_worker,
        args=(args.engine, frame_q, vis_q, stop_event, args.conf, args.box_format),
        daemon=True,
    )
    th_vis = threading.Thread(
        target=display_worker,
        args=(vis_q, stop_event),
        daemon=True,
    )

    th_cap.start()
    th_inf.start()
    th_vis.start()

    while not stop_event.is_set():
        time.sleep(0.2)

    th_cap.join(timeout=1.0)
    th_inf.join(timeout=1.0)
    th_vis.join(timeout=1.0)

    emit_worker_result(stop_reason["value"])
    print("[MAIN] Finalizado")


if __name__ == "__main__":
    main()
