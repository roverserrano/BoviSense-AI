# Guía de desarrollo y pruebas

Resumen operativo para trabajar en el repositorio. Amplía
[../codebase/CONVENTIONS.md](../codebase/CONVENTIONS.md) (estilo) y
[../codebase/TESTING.md](../codebase/TESTING.md) (pruebas).

## 1. Entorno por módulo

| Módulo | Requisitos | Preparación |
|--------|-----------|-------------|
| Backend | Node.js 22-24, cuenta de servicio de Firebase, SMTP opcional | `cd backend && npm ci` |
| App | Flutter con Dart 3.10, Android SDK, teléfono o emulador | `cd frontend && flutter pub get` |
| Jetson | JetPack con TensorRT/CUDA, `spidev`, venv `env_detection`, engine `.engine` | Manual; no hay manifiesto (`PENDIENTE DE VERIFICACIÓN`) |
| Puente | Arduino IDE con core ESP32 y librería `LoRa` | Manual |
| Emuladores Firebase | `firebase-tools` con **Java 21 o superior** | `firebase emulators:exec ...` |

## 2. Comandos por módulo

```bash
# 1) Backend local con recarga automatica
cd backend && npm run dev
curl http://127.0.0.1:3000/health

# 2) Backend: pruebas
cd backend && npm test
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
  PATH=/usr/lib/jvm/java-21-openjdk-amd64/bin:$PATH \
  firebase emulators:exec --only auth,firestore --project demo-bovisense \
  "npm --prefix backend run test:integration"

# 3) App sobre telefono por USB (requiere adb reverse)
cd frontend && bash run_usb.sh

# 4) App: analisis y pruebas
cd frontend && flutter analyze && flutter test

# 5) App: release hacia un backend HTTPS
cd frontend && flutter build apk --release \
  --dart-define=API_BASE_URL=https://<host>

# 6) Jetson: pruebas y verificacion estatica
cd jetson && python3 -m unittest test_secure_protocol.py
python3 -m py_compile run_bovino.py lora_jetson_rx.py secure_protocol.py
```

## 3. Flujo de trabajo recomendado

1. **Revisar el estado**: `git status --short`. El repositorio tiene rama de
   trabajo `dev` y de integración `main`.
2. **Elegir módulo** y respetar sus límites (ver
   [../codebase/STRUCTURE.md](../codebase/STRUCTURE.md), sección 3).
3. **Implementar** siguiendo el orden natural del módulo: backend
   (`routes → controller → service`), app (`model → repository → viewmodel →
   view`) o borde (protocolo en los tres extremos a la vez).
4. **Verificar**: pruebas automatizadas del módulo y `py_compile`/`flutter
   analyze` según corresponda.
5. **Documentar**: actualizar `docs/` y la bitácora `AGENTS.md` con el cambio y
   su verificación.

## 4. Reglas de trabajo del proyecto

Tomadas de `AGENTS.md` (secciones 9 y 21) y verificadas contra el código:

- No hacer `reset`, `checkout` destructivo ni sobrescribir trabajo ajeno.
- Tratar el repositorio como fuente de código y la Jetson/ESP32 como
  instalaciones que pueden tener otra versión.
- No tocar cableado ni forzar el RST del SX1278 en LOW: va puenteado a 3.3 V y
  el pin 29 queda libre.
- Confirmar un único propietario del SPI antes de diagnosticar radio
  (`sudo fuser -v /dev/spidev0.0`).
- Separar observación de inferencia: `TxDone` es local al SX1278; sólo
  `R1 recibido` y verificado en el backend evidencia recepción.
- Mantener el alcance local: no publicar servicios, reglas, app ni secretos.

## 5. Errores frecuentes y cómo diagnosticarlos

| Síntoma | Causa habitual | Diagnóstico |
|---------|----------------|-------------|
| La app muestra "No se pudo conectar con el backend..." | Falta `adb reverse` o la URL apunta a loopback desde el teléfono | `adb reverse --list`; usar `bash frontend/run_usb.sh` |
| `/health` responde 503 | Credenciales de Firebase inválidas o sin red | Revisar `backend/.env` y la cuenta de servicio |
| `La sesión ya no está en el equipo` / conteo en ERROR | La Jetson se reinició y perdió la sesión | Volver a "Consultar equipo" (envía `H`) y reiniciar el conteo |
| Un segundo receptor no arranca | El `flock` del SPI ya está tomado por el servicio | `sudo fuser -v /dev/spidev0.0`; no ejecutar dos receptores |
| El tracker cae al modo interno | Falta `trackers`/`supervision` en el venv | Revisar el log `[TRACKER]` al arrancar |
| El conteo se corta a los 10 minutos | `COUNT_MAX_DURATION_SEC = 600` | Ajustar el parámetro si la operación lo requiere |
| `flutter test` falla por Firebase | Las páginas que usan `AuthViewModel` requieren Firebase inicializado | Probar componentes aislados (ver `TESTING.md`) |

## 6. Convenciones para contribuir

- Mensajes de commit cortos en español, como el historial existente.
- No añadir dependencias nuevas sin verificar su compatibilidad con Node 22-24,
  Dart 3.10, Python 3 del venv y `aarch64` (Jetson).
- No modificar el protocolo C1/R1 sin actualizar backend, Jetson y (si aplica)
  la app en el mismo cambio.
- No versionar secretos: `.env`, cuenta de servicio y credenciales de SSH o
  SMTP quedan fuera de Git.
- Documentar en `docs/` cualquier cambio de contrato o de flujo.

## 7. Evidencia

- `backend/package.json`, `frontend/pubspec.yaml`, `frontend/run_usb.sh`
- `AGENTS.md` secciones 7, 8, 9 y 21
- `docs/codebase/TESTING.md`, `docs/codebase/CONVENTIONS.md`
- `frontend/lib/data/services/api_client.dart` (mensajes de diagnóstico)
