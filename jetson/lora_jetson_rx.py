#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import time
import socket
import subprocess
import argparse
import json
import os
import signal
from pathlib import Path
import spidev

try:
    import Jetson.GPIO as GPIO
    GPIO_IMPORT_ERROR = None
except Exception as exc:
    GPIO = None
    GPIO_IMPORT_ERROR = exc

# =========================================================
# CONFIGURACIÓN
# =========================================================
SPI_BUS = 0
SPI_DEV = 0
SPI_SPEED_HZ = 500000

PIN_RST = 29
USE_RST_PULSE = False  # False = solo mantener HIGH, no hacer pulso de reset
USE_GPIO_RST = False   # False evita depender de Jetson.GPIO para iniciar.

FREQUENCY_HZ = 433_000_000
SYNC_WORD = 0xF3
SPREADING_FACTOR = 7
SIGNAL_BANDWIDTH_HZ = 125_000
CODING_RATE_DENOMINATOR = 5
CRC_ENABLED = True
TX_POWER_DBM = 2
DEBUG_INTERVAL_S = 5.0
STATUS_REPLY_REPEATS = 2
STATUS_REPLY_REPEAT_DELAY_S = 0.35
REGISTER_VERIFY_RETRIES = 4
COUNT_PROJECT_DIR = "/home/cow/Documents/proyecto"
COUNT_VENV_PYTHON = "/home/cow/Documents/proyecto/env_detection/bin/python3"
COUNT_SCRIPT_PATH = "/home/cow/Documents/proyecto/run_bovino.py"
COUNT_ENGINE_PATH = "/home/cow/Documents/proyecto/modelos/model_fp32.engine"
COUNT_SOURCE_URL = "http://192.168.1.4:8080/video"
COUNT_LOG_PATH = "/home/cow/Documents/proyecto/run_bovino_lora.log"
COUNT_MAX_DURATION_SEC = 600
COUNT_STOP_TIMEOUT_SEC = 8

# =========================================================
# REGISTROS SX127x
# =========================================================
REG_FIFO = 0x00
REG_OP_MODE = 0x01
REG_PA_CONFIG = 0x09
REG_FRF_MSB = 0x06
REG_FRF_MID = 0x07
REG_FRF_LSB = 0x08
REG_LNA = 0x0C
REG_FIFO_ADDR_PTR = 0x0D
REG_FIFO_TX_BASE_ADDR = 0x0E
REG_FIFO_RX_BASE_ADDR = 0x0F
REG_FIFO_RX_CURRENT_ADDR = 0x10
REG_IRQ_FLAGS_MASK = 0x11
REG_IRQ_FLAGS = 0x12
REG_RX_NB_BYTES = 0x13
REG_PKT_SNR_VALUE = 0x19
REG_PKT_RSSI_VALUE = 0x1A
REG_RSSI_VALUE = 0x1B
REG_MODEM_CONFIG_1 = 0x1D
REG_MODEM_CONFIG_2 = 0x1E
REG_SYMB_TIMEOUT_LSB = 0x1F
REG_PREAMBLE_MSB = 0x20
REG_PREAMBLE_LSB = 0x21
REG_PAYLOAD_LENGTH = 0x22
REG_MODEM_CONFIG_3 = 0x26
REG_DETECTION_OPTIMIZE = 0x31
REG_DETECTION_THRESHOLD = 0x37
REG_SYNC_WORD = 0x39
REG_VERSION = 0x42

MODE_LONG_RANGE_MODE = 0x80
MODE_LOW_FREQUENCY_MODE = 0x08
MODE_SLEEP = 0x00
MODE_STDBY = 0x01
MODE_TX = 0x03
MODE_RX_CONTINUOUS = 0x05

IRQ_RX_DONE_MASK = 0x40
IRQ_PAYLOAD_CRC_ERROR_MASK = 0x20
IRQ_VALID_HEADER_MASK = 0x10
IRQ_TX_DONE_MASK = 0x08
IRQ_CAD_DONE_MASK = 0x04
IRQ_FHSS_CHANGE_CHANNEL_MASK = 0x02
IRQ_CAD_DETECTED_MASK = 0x01
IRQ_ALL_CLEAR = 0xFF

EXPECTED_VERSION = 0x12
MAX_LORA_PAYLOAD_LENGTH = 220
FIFO_RX_BASE_ADDR = 0x00
FIFO_TX_BASE_ADDR = 0x80


def format_hex(value):
    return f"0x{value:02X}"


class SX1278Receiver:
    def __init__(self, crc_enabled=CRC_ENABLED, debug_interval_s=DEBUG_INTERVAL_S):
        self.spi = spidev.SpiDev()
        self.gpio_ready = False
        self.crc_enabled = crc_enabled
        self.debug_interval_s = debug_interval_s
        self.last_debug_at = 0.0

    def setup_gpio(self):
        if GPIO is None:
            print(f"[GPIO] Jetson.GPIO no disponible: {GPIO_IMPORT_ERROR}")
            print("[GPIO] Continuando sin controlar RST. Asegura RST del SX1278 en HIGH.")
            return False

        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BOARD)
        GPIO.setup(PIN_RST, GPIO.OUT, initial=GPIO.HIGH)
        GPIO.output(PIN_RST, GPIO.HIGH)  # mantener fuera de reset
        self.gpio_ready = True
        return True

    def pulse_reset(self):
        if GPIO is None or not self.gpio_ready:
            print("[GPIO] Pulso RST omitido porque GPIO no esta disponible.")
            return

        GPIO.output(PIN_RST, GPIO.LOW)
        time.sleep(0.01)
        GPIO.output(PIN_RST, GPIO.HIGH)
        time.sleep(0.05)

    def read_reg(self, reg):
        return self.spi.xfer2([reg & 0x7F, 0x00])[1]

    def write_reg(self, reg, value):
        self.spi.xfer2([reg | 0x80, value & 0xFF])

    def write_reg_checked(
        self,
        reg,
        value,
        label=None,
        retries=REGISTER_VERIFY_RETRIES,
    ):
        expected = value & 0xFF
        name = label or format_hex(reg)

        for attempt in range(1, retries + 1):
            self.write_reg(reg, expected)
            time.sleep(0.003)
            actual = self.read_reg(reg)
            if actual == expected:
                return True
            print(
                f"[SPI] Escritura no verificada en {name} "
                f"intento {attempt}/{retries}: "
                f"esperado={format_hex(expected)} leido={format_hex(actual)}"
            )

        return False

    def burst_read(self, reg, length):
        data = self.spi.xfer2([reg & 0x7F] + [0x00] * length)
        return data[1:]

    def burst_write(self, reg, data):
        self.spi.xfer2([reg | 0x80] + [value & 0xFF for value in data])

    def fifo_write_bytes(self, data):
        for value in data:
            self.write_reg(REG_FIFO, value)

    def set_frequency(self, frequency_hz):
        frf = int((frequency_hz << 19) / 32_000_000)
        self.write_reg(REG_FRF_MSB, (frf >> 16) & 0xFF)
        self.write_reg(REG_FRF_MID, (frf >> 8) & 0xFF)
        self.write_reg(REG_FRF_LSB, frf & 0xFF)

    def set_sleep(self):
        return self.write_reg_checked(
            REG_OP_MODE,
            MODE_LONG_RANGE_MODE | MODE_LOW_FREQUENCY_MODE | MODE_SLEEP,
            "OP_MODE sleep LoRa",
        )

    def set_standby(self):
        return self.write_reg_checked(
            REG_OP_MODE,
            MODE_LONG_RANGE_MODE | MODE_LOW_FREQUENCY_MODE | MODE_STDBY,
            "OP_MODE standby LoRa",
        )

    def set_rx_continuous(self):
        self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)
        self.write_reg(REG_FIFO_ADDR_PTR, FIFO_RX_BASE_ADDR)
        return self.write_reg_checked(
            REG_OP_MODE,
            MODE_LONG_RANGE_MODE | MODE_LOW_FREQUENCY_MODE | MODE_RX_CONTINUOUS,
            "OP_MODE RX continuo",
        )

    def current_mode(self):
        return self.read_reg(REG_OP_MODE) & 0x07

    def modem_config_1(self):
        # BW 125 kHz = 0x70, CR 4/5 = 0x02, explicit header = 0x00
        return 0x70 | ((CODING_RATE_DENOMINATOR - 4) << 1)

    def modem_config_2(self):
        # SF7 = 0x70, CRC bit = 0x04 when enabled, timeout MSB = 0
        crc_bit = 0x04 if self.crc_enabled else 0x00
        return (SPREADING_FACTOR << 4) | crc_bit

    def modem_config_3(self):
        # LowDataRateOptimize off for SF7/BW125, AGC auto on.
        return 0x04

    def packet_rssi(self):
        return self.read_reg(REG_PKT_RSSI_VALUE) - 164

    def packet_snr(self):
        raw = self.read_reg(REG_PKT_SNR_VALUE)
        if raw > 127:
            raw -= 256
        return raw / 4.0

    def current_rssi(self):
        return self.read_reg(REG_RSSI_VALUE) - 164

    def read_version_stable(self, tries=5, delay=0.05):
        values = []
        for _ in range(tries):
            values.append(self.read_reg(REG_VERSION))
            time.sleep(delay)
        return values

    def begin(self):
        self.spi.open(SPI_BUS, SPI_DEV)
        self.spi.max_speed_hz = SPI_SPEED_HZ
        self.spi.mode = 0
        self.spi.bits_per_word = 8
        self.spi.lsbfirst = False
        self.spi.no_cs = False
        self.spi.cshigh = False

        print(
            f"[SPI] Usando /dev/spidev{SPI_BUS}.{SPI_DEV} "
            f"a {SPI_SPEED_HZ} Hz, mode=0, CS activo en LOW"
        )

        # Si RST está cableado a PIN_RST, se puede habilitar con --use-gpio-rst.
        if USE_GPIO_RST or USE_RST_PULSE:
            self.setup_gpio()
        else:
            print("[GPIO] Control RST desactivado. RST del SX1278 debe estar en HIGH.")
            print("[GPIO] Si RST esta desconectado/flotando, el SX1278 puede recibir pero fallar al transmitir.")

        # Solo si quieres forzar reset, se hace el pulso
        if USE_RST_PULSE:
            self.pulse_reset()

        versions = self.read_version_stable()
        print("Lecturas REG_VERSION:", [f"0x{v:02X}" for v in versions])

        if not all(v == EXPECTED_VERSION for v in versions):
            return False

        if not self.configure_lora_registers():
            return False

        self.set_rx_continuous()

        self.print_radio_config()

        return True

    def configure_lora_registers(self):
        # SX127x only allows changing LongRangeMode reliably while sleeping.
        self.write_reg(REG_OP_MODE, MODE_SLEEP)
        time.sleep(0.01)
        if not self.set_sleep():
            print("[LoRa] No se pudo entrar en modo LoRa sleep.")
            return False
        time.sleep(0.01)

        self.set_frequency(FREQUENCY_HZ)

        self.write_reg(REG_FIFO_RX_BASE_ADDR, FIFO_RX_BASE_ADDR)
        self.write_reg(REG_FIFO_TX_BASE_ADDR, FIFO_TX_BASE_ADDR)
        self.write_reg(REG_FIFO_ADDR_PTR, FIFO_RX_BASE_ADDR)

        self.write_reg(REG_LNA, self.read_reg(REG_LNA) | 0x03)
        self.write_reg(REG_PA_CONFIG, 0x80 | min(max(TX_POWER_DBM - 2, 0), 15))
        self.write_reg(REG_IRQ_FLAGS_MASK, 0x00)

        self.write_reg(REG_MODEM_CONFIG_1, self.modem_config_1())
        self.write_reg(REG_MODEM_CONFIG_2, self.modem_config_2())
        self.write_reg(REG_MODEM_CONFIG_3, self.modem_config_3())
        self.write_reg(REG_DETECTION_OPTIMIZE, 0xC3)
        self.write_reg(REG_DETECTION_THRESHOLD, 0x0A)

        self.write_reg(REG_SYMB_TIMEOUT_LSB, 0x64)
        self.write_reg(REG_PREAMBLE_MSB, 0x00)
        self.write_reg(REG_PREAMBLE_LSB, 0x08)
        self.write_reg(REG_PAYLOAD_LENGTH, 0x00)
        self.write_reg(REG_SYNC_WORD, SYNC_WORD)
        self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)

        if not self.set_standby():
            print("[LoRa] No se pudo entrar en standby LoRa.")
            return False
        time.sleep(0.01)
        return True

    def ensure_lora_mode(self):
        op_mode = self.read_reg(REG_OP_MODE)
        if op_mode & MODE_LONG_RANGE_MODE:
            return

        print(f"[WARN] LongRangeMode apagado (OP_MODE={format_hex(op_mode)}); reconfigurando LoRa.")
        self.configure_lora_registers()

    def print_radio_config(self):
        regs = {
            "OP_MODE": self.read_reg(REG_OP_MODE),
            "FRF_MSB": self.read_reg(REG_FRF_MSB),
            "FRF_MID": self.read_reg(REG_FRF_MID),
            "FRF_LSB": self.read_reg(REG_FRF_LSB),
            "MODEM_CONFIG_1": self.read_reg(REG_MODEM_CONFIG_1),
            "MODEM_CONFIG_2": self.read_reg(REG_MODEM_CONFIG_2),
            "MODEM_CONFIG_3": self.read_reg(REG_MODEM_CONFIG_3),
            "SYNC_WORD": self.read_reg(REG_SYNC_WORD),
            "IRQ_MASK": self.read_reg(REG_IRQ_FLAGS_MASK),
            "IRQ_FLAGS": self.read_reg(REG_IRQ_FLAGS),
        }
        print("Configuracion LoRa aplicada:")
        print(f"  Frecuencia: {FREQUENCY_HZ / 1_000_000:.3f} MHz")
        print(
            "  Radio: "
            f"SF={SPREADING_FACTOR} BW={SIGNAL_BANDWIDTH_HZ // 1000}kHz "
            f"CR=4/{CODING_RATE_DENOMINATOR} CRC={'ON' if self.crc_enabled else 'OFF'} "
            f"SyncWord={format_hex(SYNC_WORD)}"
        )
        print("  Registros:", " ".join(f"{k}={format_hex(v)}" for k, v in regs.items()))

    def print_debug_status(self, force=False):
        now = time.monotonic()
        if not force and now - self.last_debug_at < self.debug_interval_s:
            return
        self.last_debug_at = now

        op_mode = self.read_reg(REG_OP_MODE)
        irq_flags = self.read_reg(REG_IRQ_FLAGS)
        fifo_addr = self.read_reg(REG_FIFO_ADDR_PTR)
        rx_current = self.read_reg(REG_FIFO_RX_CURRENT_ADDR)
        rx_bytes = self.read_reg(REG_RX_NB_BYTES)
        print(
            "[DBG] "
            f"op={format_hex(op_mode)} mode={op_mode & 0x07} "
            f"irq={format_hex(irq_flags)} fifo={format_hex(fifo_addr)} "
            f"rx_current={format_hex(rx_current)} rx_bytes={rx_bytes} "
            f"rssi={self.current_rssi()} dBm"
        )

        if self.current_mode() != MODE_RX_CONTINUOUS:
            print("[DBG] Radio no estaba en RX continuo; reactivando RX.")
            self.set_rx_continuous()

    def transmit_text(self, text, timeout=3.0):
        payload = text.encode("utf-8")
        if not payload:
            print("TX omitido: payload vacio")
            return False
        if len(payload) > MAX_LORA_PAYLOAD_LENGTH:
            print(f"TX omitido: payload demasiado largo ({len(payload)} bytes)")
            return False

        if not self.configure_lora_registers():
            print("TX omitido: el SX1278 no acepto la configuracion LoRa.")
            self.set_rx_continuous()
            return False

        time.sleep(0.01)
        if not self.write_reg_checked(REG_FIFO_ADDR_PTR, FIFO_TX_BASE_ADDR, "FIFO_ADDR_PTR TX"):
            print("TX omitido: no se pudo posicionar FIFO TX.")
            print("DIAGNOSTICO: el SX1278 no acepta escrituras SPI criticas para transmitir.")
            print("ACCION: conecta RST del SX1278 a 3.3V estable o a un GPIO controlado; no lo dejes flotando.")
            self.set_rx_continuous()
            return False

        self.write_reg(REG_PAYLOAD_LENGTH, 0x00)
        self.fifo_write_bytes(payload)
        if not self.write_reg_checked(REG_PAYLOAD_LENGTH, len(payload), "PAYLOAD_LENGTH TX"):
            print("TX omitido: el SX1278 no acepto PAYLOAD_LENGTH.")
            print("DIAGNOSTICO: el FIFO TX no quedo configurado; revisa RST, NSS/CS, MOSI y alimentacion 3.3V.")
            self.set_rx_continuous()
            return False

        self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)
        print(
            "TX preparando: "
            f"len={len(payload)} base={format_hex(FIFO_TX_BASE_ADDR)} "
            f"payload_len={self.read_reg(REG_PAYLOAD_LENGTH)} "
            f"op={format_hex(self.read_reg(REG_OP_MODE))}"
        )
        if not self.write_reg_checked(
            REG_OP_MODE,
            MODE_LONG_RANGE_MODE | MODE_LOW_FREQUENCY_MODE | MODE_TX,
            "OP_MODE TX",
        ):
            print("TX omitido: no se pudo entrar en modo TX LoRa.")
            self.set_rx_continuous()
            return False

        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            irq_flags = self.read_reg(REG_IRQ_FLAGS)
            if irq_flags & IRQ_TX_DONE_MASK:
                self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)
                self.set_rx_continuous()
                return True
            time.sleep(0.01)

        self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)
        self.set_rx_continuous()
        print("TX timeout: no se confirmo TxDone")
        return False

    def check_packet(self):
        self.ensure_lora_mode()
        if self.current_mode() != MODE_RX_CONTINUOUS:
            self.set_rx_continuous()

        irq_flags = self.read_reg(REG_IRQ_FLAGS)

        if not (irq_flags & IRQ_RX_DONE_MASK):
            interesting_flags = (
                IRQ_PAYLOAD_CRC_ERROR_MASK |
                IRQ_VALID_HEADER_MASK |
                IRQ_TX_DONE_MASK |
                IRQ_CAD_DONE_MASK |
                IRQ_FHSS_CHANGE_CHANNEL_MASK |
                IRQ_CAD_DETECTED_MASK
            )
            if irq_flags & interesting_flags:
                print(f"[IRQ] Sin RxDone, flags={format_hex(irq_flags)}; limpiando y siguiendo en RX.")
                self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)
                self.set_rx_continuous()
            return None

        if irq_flags & IRQ_PAYLOAD_CRC_ERROR_MASK:
            rssi = self.packet_rssi()
            snr = self.packet_snr()
            self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)
            self.set_rx_continuous()
            return {
                "ok": False,
                "error": "CRC",
                "irq": irq_flags,
                "rssi": rssi,
                "snr": snr,
            }

        current_addr = self.read_reg(REG_FIFO_RX_CURRENT_ADDR)
        packet_len = self.read_reg(REG_RX_NB_BYTES)
        self.write_reg(REG_FIFO_ADDR_PTR, current_addr)

        raw = self.burst_read(REG_FIFO, packet_len)

        try:
            text = bytes(raw).decode("utf-8", errors="replace")
        except Exception:
            text = str(raw)

        rssi = self.packet_rssi()
        snr = self.packet_snr()
        self.write_reg(REG_IRQ_FLAGS, IRQ_ALL_CLEAR)
        self.set_rx_continuous()

        return {
            "ok": True,
            "payload_text": text,
            "payload_raw": raw,
            "length": packet_len,
            "rssi": rssi,
            "snr": snr,
            "irq": irq_flags,
        }

    def close(self):
        try:
            self.spi.close()
        except Exception:
            pass
        try:
            if self.gpio_ready:
                GPIO.cleanup()
        except Exception:
            pass


def clean_field(value, fallback="No disponible", max_length=32):
    text = str(value).strip()
    if not text:
        text = fallback
    text = text.replace("|", "/").replace("\n", " ").replace("\r", " ")
    return text[:max_length]


def read_power_mode():
    try:
        result = subprocess.run(
            ["nvpmodel", "-q"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
        output = result.stdout + result.stderr
        for line in output.splitlines():
            if "NV Power Mode" in line or "Power Mode" in line:
                return clean_field(line.split(":", 1)[-1], max_length=12)
    except Exception as exc:
        return clean_field(f"error {exc}", max_length=28)

    return "No disponible"


def read_uptime():
    try:
        with open("/proc/uptime", "r", encoding="utf-8") as file:
            seconds = int(float(file.read().split()[0]))
        days, rem = divmod(seconds, 86400)
        hours, rem = divmod(rem, 3600)
        minutes, _ = divmod(rem, 60)
        if days:
            return f"{days}d{hours}h"
        return f"{hours}h{minutes}m"
    except Exception:
        return "No disponible"


def read_cpu_temp():
    try:
        thermal_root = "/sys/class/thermal"
        candidates = []
        for index in range(20):
            base = f"{thermal_root}/thermal_zone{index}"
            try:
                with open(f"{base}/type", "r", encoding="utf-8") as file:
                    zone_type = file.read().strip().lower()
                with open(f"{base}/temp", "r", encoding="utf-8") as file:
                    temp_c = int(file.read().strip()) / 1000.0
                candidates.append((zone_type, temp_c))
            except Exception:
                continue

        for zone_type, temp_c in candidates:
            if "cpu" in zone_type or "thermal" in zone_type:
                return f"{temp_c:.1f}C"
        if candidates:
            return f"{candidates[0][1]:.1f}C"
    except Exception:
        pass

    return "No disponible"


def read_memory():
    try:
        values = {}
        with open("/proc/meminfo", "r", encoding="utf-8") as file:
            for line in file:
                key, raw_value = line.split(":", 1)
                values[key] = int(raw_value.strip().split()[0])

        total_mb = values["MemTotal"] // 1024
        available_mb = values["MemAvailable"] // 1024
        used_mb = total_mb - available_mb
        return f"{used_mb}/{total_mb}"
    except Exception:
        return "No disponible"


def read_load_average():
    try:
        with open("/proc/loadavg", "r", encoding="utf-8") as file:
            return file.read().split()[0]
    except Exception:
        return "No disponible"


def build_jetson_status_response(msg_id):
    fields = {
        "h": clean_field(socket.gethostname(), max_length=20),
        "p": read_power_mode(),
        "u": read_uptime(),
        "t": read_cpu_temp(),
        "m": read_memory(),
        "l": read_load_average(),
    }
    status = "|".join(f"{key}={value}" for key, value in fields.items())
    return f"RESP|{msg_id}|JS|{status}"


class CountSessionController:
    def __init__(self):
        self.session = None
        self.last_result = None
        self.process = None
        self.log_file = None

    def validate_runtime(self):
        required_paths = [
            ("proyecto", Path(COUNT_PROJECT_DIR)),
            ("python env", Path(COUNT_VENV_PYTHON)),
            ("script", Path(COUNT_SCRIPT_PATH)),
            ("engine", Path(COUNT_ENGINE_PATH)),
        ]
        for label, path in required_paths:
            if not path.exists():
                return f"no existe {label}: {path}"
        return None

    def prepare(self):
        self.sync_worker_state()
        if self.is_worker_alive():
            self.log("PREPARARCONTEO rechazado: sesion activa")
            return self.response_fields(
                "BUSY",
                detail="already_running",
                session=self.session_id(),
            )

        runtime_error = self.validate_runtime()
        if runtime_error is not None:
            self.log(f"PREPARARCONTEO error: {runtime_error}")
            return self.response_fields("ERROR", detail=runtime_error, session="none")

        self.log("PREPARARCONTEO listo")
        return self.response_fields("READY", detail="ok", session="none")

    def start(self):
        self.sync_worker_state()
        if self.is_worker_alive():
            self.log("INICIARCONTEO rechazado: sesion activa")
            return self.response_fields(
                "BUSY",
                detail="already_running",
                session=self.session_id(),
            )

        runtime_error = self.validate_runtime()
        if runtime_error is not None:
            self.log(f"INICIARCONTEO error: {runtime_error}")
            self.last_result = self.new_result(
                session_id="none",
                status="ERROR",
                reason="runtime_validation_failed",
                detail=runtime_error,
            )
            return self.response_fields("ERROR", detail=runtime_error, session="none")

        session_id = self.new_session_id()
        now = time.time()
        status_file = f"/tmp/bovisense_count_{session_id}_status.json"
        result_file = f"/tmp/bovisense_count_{session_id}_result.json"
        self.session = {
            "id": session_id,
            "status": "RUNNING",
            "start_time": now,
            "end_time": None,
            "pid": None,
            "count": None,
            "reason": "",
            "detail": "starting_worker",
            "status_file": status_file,
            "result_file": result_file,
            "log_offset": 0,
        }

        try:
            command = self.build_shell_command()
            log_path = Path(COUNT_LOG_PATH)
            log_path.parent.mkdir(parents=True, exist_ok=True)
            self.log_file = open(log_path, "a", encoding="utf-8")
            self.log_file.write(
                f"\n--- INICIARCONTEO session={session_id} desde LoRa ---\n"
            )
            self.log_file.flush()
            self.session["log_offset"] = log_path.stat().st_size

            env = os.environ.copy()
            env.update(
                {
                    "BOVISENSE_SESSION_ID": session_id,
                    "BOVISENSE_STATUS_FILE": status_file,
                    "BOVISENSE_RESULT_FILE": result_file,
                }
            )

            self.log("[Conteo] Ejecutando worker:")
            self.log(f"[Conteo] {command}")
            self.log(f"[Conteo] Log: {COUNT_LOG_PATH}")
            self.process = subprocess.Popen(
                ["bash", "-lc", command],
                stdout=self.log_file,
                stderr=self.log_file,
                cwd=COUNT_PROJECT_DIR,
                env=env,
                start_new_session=True,
            )
            self.session["pid"] = self.process.pid
            self.session["detail"] = "worker_started"
            self.log(f"Sesion {session_id} RUNNING pid={self.process.pid}")
            return self.response_fields(
                "STARTED",
                detail="worker_started",
                session=session_id,
            )
        except Exception as exc:
            detail = f"launch_failed:{exc}"
            self.log(f"ERROR al lanzar run_bovino.py: {exc}")
            self.finish_session("launch_failed", status="ERROR", detail=detail)
            return self.response_fields("ERROR", detail=detail, session=session_id)

    def stop(self, reason="stopped_by_app"):
        self.sync_worker_state(skip_timeout=True)
        if self.session is None or not self.is_worker_alive():
            self.log("DETENERCONTEO sin sesion activa")
            return self.response_fields(
                "ERROR",
                detail="no_active_session",
                session=self.session_id(),
            )

        session_id = self.session_id()
        self.session["status"] = "STOPPING"
        self.session["detail"] = reason
        self.log(f"Sesion {session_id} STOPPING reason={reason}")

        killed = False
        try:
            os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
            self.process.wait(timeout=COUNT_STOP_TIMEOUT_SEC)
        except subprocess.TimeoutExpired:
            killed = True
            self.log(f"Sesion {session_id} no termino con SIGTERM; usando SIGKILL")
            os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
            self.process.wait(timeout=3)
        except ProcessLookupError:
            pass
        except Exception as exc:
            self.log(f"Error deteniendo sesion {session_id}: {exc}")
            self.finish_session("stop_error", status="ERROR", detail=str(exc))
            return self.response_fields("ERROR", detail=str(exc), session=session_id)

        finish_reason = "killed_after_timeout" if killed else reason
        self.finish_session(finish_reason, status="STOPPED", detail=finish_reason)
        return self.result_response(status="STOPPED")

    def status(self):
        self.sync_worker_state()
        if self.session is None:
            return self.response_fields(
                "IDLE",
                detail="no_active_session",
                session="none",
                alive=False,
            )

        return self.response_fields(
            self.session["status"],
            detail=self.session.get("detail", ""),
            session=self.session_id(),
        )

    def result(self):
        self.sync_worker_state()
        if self.last_result is not None:
            return self.result_response(status="RESULT")
        if self.session is not None:
            return self.response_fields(
                self.session["status"],
                detail="result_not_available_yet",
                session=self.session_id(),
            )
        return self.response_fields(
            "ERROR",
            detail="result_not_available",
            session="none",
            alive=False,
        )

    def sync_worker_state(self, skip_timeout=False):
        if self.session is None:
            return

        if self.session.get("status") in ("RUNNING", "STOPPING"):
            self.read_worker_hooks()

        if not skip_timeout and self.is_worker_alive():
            elapsed = self.elapsed_sec()
            if elapsed >= COUNT_MAX_DURATION_SEC:
                self.log(
                    f"Sesion {self.session_id()} excedio timeout "
                    f"{COUNT_MAX_DURATION_SEC}s"
                )
                self.stop(reason="timeout")
                return

        if self.process is None:
            return

        exit_code = self.process.poll()
        if exit_code is None:
            return

        if self.session["status"] in ("RUNNING", "STOPPING"):
            status = "STOPPED" if exit_code == 0 else "ERROR"
            reason = "worker_exited" if exit_code == 0 else "worker_exited_unexpectedly"
            detail = f"{reason}:code={exit_code}"
            self.finish_session(reason, status=status, detail=detail)

    def read_worker_hooks(self):
        if self.session is None:
            return
        self.read_worker_json(self.session.get("status_file"), final=False)
        self.read_worker_json(self.session.get("result_file"), final=True)
        self.read_worker_log()

    def read_worker_json(self, path, final=False):
        if not path:
            return
        file_path = Path(path)
        if not file_path.exists():
            return
        try:
            data = json.loads(file_path.read_text(encoding="utf-8"))
        except Exception as exc:
            self.session["detail"] = f"invalid_worker_json:{exc}"
            return

        count = data.get("count")
        if count is not None:
            self.session["count"] = count
        detail = data.get("detail") or data.get("status")
        if detail:
            self.session["detail"] = str(detail)
        if final:
            reason = data.get("reason") or "worker_result"
            self.finish_session(reason, status="STOPPED", detail=str(reason))

    def read_worker_log(self):
        if self.session is None:
            return
        log_path = Path(COUNT_LOG_PATH)
        if not log_path.exists():
            return
        try:
            offset = int(self.session.get("log_offset", 0))
            with open(log_path, "r", encoding="utf-8", errors="replace") as file:
                file.seek(offset)
                lines = file.readlines()
                self.session["log_offset"] = file.tell()
        except Exception:
            return

        for line in lines:
            line = line.strip()
            if line.startswith("COUNT_UPDATE|"):
                fields = self.parse_pipe_fields(line)
                if "count" in fields:
                    self.session["count"] = fields["count"]
                    self.session["detail"] = "count_update"
            elif line.startswith("COUNT_FINAL|"):
                fields = self.parse_pipe_fields(line)
                if "count" in fields:
                    self.session["count"] = fields["count"]
                self.finish_session("worker_final", status="STOPPED", detail="worker_final")
            elif line.startswith("WORKER_STATUS|"):
                fields = self.parse_pipe_fields(line)
                if "status" in fields:
                    self.session["detail"] = f"worker_{fields['status']}"

    def finish_session(self, reason, status="STOPPED", detail=""):
        if self.session is None:
            return
        self.read_worker_hooks_without_finishing()
        self.session["status"] = status
        self.session["end_time"] = time.time()
        self.session["reason"] = reason
        self.session["detail"] = detail or reason
        self.last_result = self.new_result(
            session_id=self.session["id"],
            status=status,
            reason=reason,
            detail=self.session["detail"],
            pid=self.session.get("pid"),
            elapsed=self.elapsed_sec(),
            count=self.session.get("count"),
        )
        self.log(
            f"Sesion {self.session['id']} finalizada status={status} "
            f"reason={reason} elapsed={self.last_result['elapsed']}s "
            f"count={self.count_text(self.session.get('count'))}"
        )
        self.close_log_file()

    def read_worker_hooks_without_finishing(self):
        if self.session is None:
            return
        self.read_worker_json(self.session.get("status_file"), final=False)
        self.read_worker_log_updates_only()

    def read_worker_log_updates_only(self):
        if self.session is None:
            return
        log_path = Path(COUNT_LOG_PATH)
        if not log_path.exists():
            return
        try:
            offset = int(self.session.get("log_offset", 0))
            with open(log_path, "r", encoding="utf-8", errors="replace") as file:
                file.seek(offset)
                lines = file.readlines()
                self.session["log_offset"] = file.tell()
        except Exception:
            return
        for line in lines:
            if line.startswith("COUNT_UPDATE|") or line.startswith("COUNT_FINAL|"):
                fields = self.parse_pipe_fields(line.strip())
                if "count" in fields:
                    self.session["count"] = fields["count"]

    def build_shell_command(self):
        return (
            f"cd {COUNT_PROJECT_DIR} && "
            "source env_detection/bin/activate && "
            f"python3 {COUNT_SCRIPT_PATH} "
            f"--engine {COUNT_ENGINE_PATH} "
            f"--source {COUNT_SOURCE_URL}"
        )

    def response_fields(self, status, detail="", session=None, alive=None):
        active_alive = self.is_worker_alive() if alive is None else alive
        fields = {
            "status": status,
            "session": session or self.session_id(),
            "alive": str(active_alive).lower(),
            "elapsed": str(self.elapsed_sec()),
            "pid": str(self.pid_value()),
            "count": self.count_text(self.current_count()),
        }
        if detail:
            fields["detail"] = detail
        reason = self.current_reason()
        if reason:
            fields["reason"] = reason
        return fields

    def result_response(self, status="RESULT"):
        result = self.last_result or {}
        return {
            "status": status,
            "session": str(result.get("session", self.session_id())),
            "alive": "false",
            "elapsed": str(result.get("elapsed", self.elapsed_sec())),
            "pid": str(result.get("pid", self.pid_value())),
            "count": self.count_text(result.get("count", self.current_count())),
            "reason": str(result.get("reason", self.current_reason() or "unknown")),
            "detail": str(result.get("detail", "result")),
        }

    def new_result(
        self,
        session_id,
        status,
        reason,
        detail,
        pid=None,
        elapsed=0,
        count=None,
    ):
        return {
            "session": session_id,
            "status": status,
            "reason": reason,
            "detail": detail,
            "pid": pid,
            "elapsed": elapsed,
            "count": count,
        }

    def is_worker_alive(self):
        return self.process is not None and self.process.poll() is None

    def elapsed_sec(self):
        if self.session is None:
            return 0
        end_time = self.session.get("end_time") or time.time()
        return int(max(0, end_time - self.session["start_time"]))

    def current_count(self):
        if self.session is not None:
            return self.session.get("count")
        if self.last_result is not None:
            return self.last_result.get("count")
        return None

    def current_reason(self):
        if self.session is not None:
            return self.session.get("reason", "")
        if self.last_result is not None:
            return self.last_result.get("reason", "")
        return ""

    def pid_value(self):
        if self.session is not None and self.session.get("pid"):
            return self.session["pid"]
        return "none"

    def session_id(self):
        if self.session is None:
            return "none"
        return self.session["id"]

    def close_log_file(self):
        if self.log_file is not None:
            try:
                self.log_file.flush()
                self.log_file.close()
            except Exception:
                pass
        self.log_file = None

    @staticmethod
    def new_session_id():
        return f"C{int(time.time())}"

    @staticmethod
    def count_text(value):
        if value is None or value == "":
            return "unknown"
        return str(value)

    @staticmethod
    def parse_pipe_fields(line):
        fields = {}
        for segment in line.split("|")[1:]:
            if "=" not in segment:
                continue
            key, value = segment.split("=", 1)
            fields[key.strip()] = value.strip()
        return fields

    @staticmethod
    def log(message):
        print(f"[Conteo] {message}")


count_controller = CountSessionController()


def build_count_response(msg_id, fields):
    safe_fields = []
    for key, value in fields.items():
        safe_value = clean_field(value, fallback="unknown", max_length=48)
        safe_fields.append(f"{key}={safe_value}")
    return f"RESP|{msg_id}|COUNT|" + "|".join(safe_fields)


def send_response(rx, response, label):
    print(f"LoRa TX: {response}")
    sent_count = 0
    for attempt in range(STATUS_REPLY_REPEATS):
        if attempt > 0:
            time.sleep(STATUS_REPLY_REPEAT_DELAY_S)
        if rx.transmit_text(response):
            sent_count += 1
            print(f"Respuesta {label} enviada al ESP32 ({attempt + 1}/{STATUS_REPLY_REPEATS}).")
        else:
            print(f"No se pudo enviar la respuesta {label} ({attempt + 1}/{STATUS_REPLY_REPEATS}).")
    if sent_count == 0:
        print(f"Ninguna respuesta {label} fue transmitida.")


def maybe_reply_to_command(rx, payload):
    parts = payload.strip().split("|")
    command = parts[0].upper() if parts else ""
    msg_id = "0"

    if command == "BRIDGE" and len(parts) >= 3:
        msg_id = parts[1] if parts[1].isdigit() else "0"
        command = parts[2].upper()
    elif len(parts) >= 2 and parts[1].isdigit():
        msg_id = parts[1]

    if command == "ESTADO":
        response = build_jetson_status_response(msg_id)
        send_response(rx, response, "ESTADO")
        return

    count_commands = {
        "PREPARARCONTEO": count_controller.prepare,
        "INICIARCONTEO": count_controller.start,
        "DETENERCONTEO": count_controller.stop,
        "ESTADOCONTEO": count_controller.status,
        "RESULTADOCONTEO": count_controller.result,
    }
    if command in count_commands:
        print(f"[Comando] {command} recibido msg_id={msg_id}")
        fields = count_commands[command]()
        response = build_count_response(msg_id, fields)
        send_response(rx, response, command)
        return

    print(f"[Comando] Sin accion para payload: {payload}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="BoviSense Jetson Orin Nano LoRa SX1278 RX/TX bridge"
    )
    parser.add_argument(
        "--crc-off",
        action="store_true",
        help="Desactiva CRC solo para diagnosticar si el emisor no esta usando CRC.",
    )
    parser.add_argument(
        "--debug-interval",
        type=float,
        default=DEBUG_INTERVAL_S,
        help="Segundos entre trazas de registros mientras espera paquetes.",
    )
    parser.add_argument(
        "--spi-speed",
        type=int,
        default=SPI_SPEED_HZ,
        help="Velocidad SPI en Hz. Si hay lecturas inestables, prueba 10000.",
    )
    parser.add_argument(
        "--spi-bus",
        type=int,
        default=SPI_BUS,
        help="Bus SPI. En Jetson 40-pin normalmente es 0.",
    )
    parser.add_argument(
        "--spi-dev",
        type=int,
        default=SPI_DEV,
        help="Dispositivo SPI: 0 usa CE0/pin fisico 24, 1 usa CE1/pin fisico 26.",
    )
    parser.add_argument(
        "--count-script",
        default=COUNT_SCRIPT_PATH,
        help="Ruta de run_bovino.py para INICIARCONTEO.",
    )
    parser.add_argument(
        "--count-project-dir",
        default=COUNT_PROJECT_DIR,
        help="Directorio del proyecto bovino.",
    )
    parser.add_argument(
        "--count-python",
        default=COUNT_VENV_PYTHON,
        help="Python del entorno virtual env_detection.",
    )
    parser.add_argument(
        "--count-engine",
        default=COUNT_ENGINE_PATH,
        help="Ruta del engine TensorRT.",
    )
    parser.add_argument(
        "--count-source",
        default=COUNT_SOURCE_URL,
        help="Fuente de video para run_bovino.py.",
    )
    parser.add_argument(
        "--count-log",
        default=COUNT_LOG_PATH,
        help="Archivo donde se guardan stdout/stderr de run_bovino.py.",
    )
    parser.add_argument(
        "--count-max-duration",
        type=int,
        default=COUNT_MAX_DURATION_SEC,
        help="Timeout de seguridad de una sesion de conteo en segundos.",
    )
    parser.add_argument(
        "--count-stop-timeout",
        type=int,
        default=COUNT_STOP_TIMEOUT_SEC,
        help="Segundos para esperar SIGTERM antes de SIGKILL.",
    )
    parser.add_argument(
        "--reset-pulse",
        action="store_true",
        help="Hace un pulso LOW/HIGH en RST durante el arranque si Jetson.GPIO esta disponible.",
    )
    parser.add_argument(
        "--use-gpio-rst",
        action="store_true",
        help="Mantiene RST en HIGH usando Jetson.GPIO. No usar si Jetson.GPIO falla detectando el modelo.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    global USE_RST_PULSE, USE_GPIO_RST, SPI_SPEED_HZ, SPI_BUS, SPI_DEV
    global COUNT_PROJECT_DIR, COUNT_VENV_PYTHON, COUNT_SCRIPT_PATH
    global COUNT_ENGINE_PATH, COUNT_SOURCE_URL, COUNT_LOG_PATH
    global COUNT_MAX_DURATION_SEC, COUNT_STOP_TIMEOUT_SEC
    USE_RST_PULSE = args.reset_pulse or USE_RST_PULSE
    USE_GPIO_RST = args.use_gpio_rst or USE_GPIO_RST
    SPI_SPEED_HZ = args.spi_speed
    SPI_BUS = args.spi_bus
    SPI_DEV = args.spi_dev
    COUNT_SCRIPT_PATH = args.count_script
    COUNT_PROJECT_DIR = args.count_project_dir
    COUNT_VENV_PYTHON = args.count_python
    COUNT_ENGINE_PATH = args.count_engine
    COUNT_SOURCE_URL = args.count_source
    COUNT_LOG_PATH = args.count_log
    COUNT_MAX_DURATION_SEC = args.count_max_duration
    COUNT_STOP_TIMEOUT_SEC = args.count_stop_timeout

    rx = SX1278Receiver(
        crc_enabled=not args.crc_off,
        debug_interval_s=args.debug_interval,
    )

    try:
        print("Iniciando receptor LoRa en Jetson...")

        if not rx.begin():
            print("No se pudo inicializar el SX1278.")
            print("Causa probable: RST inestable o SPI demasiado rápido.")
            return

        print("SX1278 inicializado correctamente.")
        print("Si no aparecen paquetes, revisa que el ESP32 imprima:")
        print("[LoRa] SF=7 BW=125kHz CR=4/5 CRC=ON")
        print("Para diagnostico rapido sin CRC: python3 lora_jetson_rx.py --crc-off")
        print("Esperando paquetes...\n")
        rx.print_debug_status(force=True)
        last_count_poll_at = 0.0

        while True:
            rx.print_debug_status()
            now = time.monotonic()
            if now - last_count_poll_at >= 1.0:
                count_controller.sync_worker_state()
                last_count_poll_at = now
            packet = rx.check_packet()

            if packet is not None:
                print("------------")
                if not packet["ok"]:
                    print(
                        f"Paquete con error: {packet['error']} "
                        f"| IRQ=0x{packet['irq']:02X} "
                        f"| RSSI={packet.get('rssi')} "
                        f"| SNR={packet.get('snr')}"
                    )
                else:
                    print(f"LoRa RX: {packet['payload_text']}")
                    print(f"Longitud: {packet['length']} bytes")
                    print(f"RSSI: {packet['rssi']}")
                    print(f"SNR: {packet['snr']}")
                    print(f"IRQ: 0x{packet['irq']:02X}")
                    print(f"RAW: {packet['payload_raw']}")
                    maybe_reply_to_command(rx, packet["payload_text"])

            time.sleep(0.05)

    except KeyboardInterrupt:
        print("\nSaliendo...")
    finally:
        if count_controller.is_worker_alive():
            count_controller.stop(reason="controller_shutdown")
        count_controller.close_log_file()
        rx.close()


if __name__ == "__main__":
    main()
