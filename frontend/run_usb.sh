#!/usr/bin/env bash
#
# Arranca la app en un telefono Android conectado por USB.
#
# En un telefono fisico `127.0.0.1` es el propio telefono, no el PC: sin
# `adb reverse` la app nunca alcanza el backend local y muestra un error de
# conexion. Este script publica el puerto y luego ejecuta `flutter run`.
#
# Uso (desde frontend/):
#   bash run_usb.sh                          # backend en el puerto 3000
#   BOVISENSE_API_PORT=3001 bash run_usb.sh
#   bash run_usb.sh -d <device-id>

set -euo pipefail

PORT="${BOVISENSE_API_PORT:-3000}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb no esta en PATH: instala platform-tools de Android." >&2
  exit 1
fi

devices="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')"
if [ -z "$devices" ]; then
  echo "No hay dispositivos autorizados. Conecta el telefono y acepta la depuracion USB." >&2
  exit 1
fi

adb reverse "tcp:${PORT}" "tcp:${PORT}"
echo "adb reverse activo: 127.0.0.1:${PORT} del telefono -> PC:${PORT}"

exec flutter run "$@"
