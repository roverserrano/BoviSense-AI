# Diagramas de arquitectura

Diagramas elaborados a partir del código y la configuración reales del
repositorio. Cada diagrama indica su fuente. Renderizables en cualquier visor
compatible con Mermaid (GitHub, GitLab, VS Code, mermaid.live).

## 1. C4 — Nivel 1: contexto del sistema

Fuente: `README.md`, `backend/src/app.js`, `frontend/lib/main.dart`,
`jetson/lora_jetson_rx.py`, `comunicacion-iot/esp32/.../*.ino`.

```mermaid
graph TB
  GAN["Ganadero<br/>operacion de campo"]
  ADM["Administrador<br/>gestion de usuarios"]
  SYS["BoviSense-AI<br/>conteo de bovinos asistido por dron"]
  FB["Firebase<br/>Auth + Firestore"]
  SMTP["Servidor SMTP<br/>envio de credenciales"]
  VERCEL["Vercel<br/>hosting serverless (config detectada)"]

  GAN -->|"usa la app Android"| SYS
  ADM -->|"usa la app Android"| SYS
  SYS -->|"identidad, datos y coordinacion"| FB
  SYS -->|"correo de activacion"| SMTP
  SYS -.->|"puede desplegarse como funcion"| VERCEL
```

## 2. C4 — Nivel 2: contenedores

Fuente: `backend/src/app.js:59-60`, `backend/vercel.json`,
`frontend/lib/main.dart:127-160`, `frontend/lib/data/services/esp32_ble_bridge_service.dart`,
`jetson/lora_jetson_rx.py:1318`, `jetson/run_bovino.py:2483`,
`comunicacion-iot/esp32/.../*.ino:31-47`.

```mermaid
graph TB
  subgraph Telefono["Telefono Android"]
    APP["App Flutter<br/>MVVM + Provider"]
  end

  subgraph Nube["Servicios gestionados"]
    API["API Express<br/>Node.js 22-24"]
    AUTH["Firebase Auth"]
    DB["Cloud Firestore"]
    MAIL["SMTP"]
  end

  subgraph Campo["Equipo de campo"]
    ESP["ESP32 Bridge<br/>BLE + LoRa 433 MHz"]
    JET["Jetson Orin Nano<br/>receptor LoRa + detector TensorRT"]
    CAM["Camara CSI<br/>IMX219"]
    DRON["Dron<br/>plataforma en movimiento"]
  end

  APP -->|"HTTPS/HTTP + ID token"| API
  APP -->|"login (SDK)"| AUTH
  APP -->|"lectura del perfil propio"| DB
  API -->|"Admin SDK"| AUTH
  API -->|"Admin SDK"| DB
  API -->|"nodemailer"| MAIL
  APP -->|"BLE GATT: trama C1"| ESP
  ESP -->|"LoRa: trama C1"| JET
  JET -->|"LoRa: trama R1"| ESP
  ESP -->|"BLE: trama R1"| APP
  CAM -->|"frames"| JET
  DRON -.->|"transporta"| CAM
```

## 3. Componentes del backend

Fuente: `backend/src/app.js`, `backend/src/routes/*.js`,
`backend/src/controllers/*.js`, `backend/src/services/*.js`,
`backend/src/middlewares/authMiddleware.js`, `backend/src/utils/*.js`.

```mermaid
graph LR
  subgraph HTTP["Capa HTTP"]
    MW["helmet + CORS + rate limit<br/>+ Cache-Control + trazas X-Request-Id"]
    HEALTH["GET /health"]
    RA["/api/admin/usuarios<br/>requireRoles(['administrador'])"]
    RG["/api/ganadero<br/>requireRoles(['usuario','ganadero'])"]
    ERR["Manejador de errores<br/>404 + respondError"]
  end

  subgraph AUTHZ["Autorizacion"]
    TOK["verifyIdToken(token, revocado)"]
    PERF["Perfil en Usuarios + estado + operacion_pendiente"]
  end

  subgraph CTRL["Controladores"]
    CU["usuarioController"]
    CG["ganaderoController"]
  end

  subgraph SVC["Servicios de dominio"]
    US["userService<br/>alta/edicion/baja idempotente"]
    IS["iotService<br/>tickets + lease + verificacion"]
    IP["iotProtocol<br/>C1/R1 + HMAC"]
    MS["mailService<br/>nodemailer"]
  end

  subgraph INFRA["Infraestructura"]
    FA["Firebase Admin (Auth)"]
    FS["Firestore"]
    SM["SMTP externo"]
  end

  MW --> HEALTH
  MW --> RA --> TOK --> PERF --> CU
  MW --> RG --> TOK
  PERF --> CG
  CU --> US --> FA
  CU --> MS --> SM
  CG --> IS --> IP
  IS --> FS
  US --> FS
  CG --> FS
  MW --> ERR
```

## 4. Componentes de la aplicación Flutter

Fuente: `frontend/lib/main.dart`, `frontend/lib/views/`,
`frontend/lib/viewmodels/`, `frontend/lib/data/`.

```mermaid
graph TB
  subgraph UI["Vistas"]
    LOGIN["login_page + recuperar/ cambiar contrasena"]
    AUTHG["AuthGate"]
    ADMV["admin_dashboard + usuario_form"]
    GANV["ganadero: dashboard, finca, conteo, historial, detalle"]
    COMMON["common: splash, logo, session_actions, exit_confirm"]
  end

  subgraph VM["Viewmodels (ChangeNotifier)"]
    AVM["AuthViewModel"]
    ADMVM["AdminUsuariosViewModel"]
    GVM["GanaderoViewModel"]
    SN["SessionNotifier (disposed)"]
  end

  subgraph REPO["Repositorios"]
    AR["AuthRepository"]
    AUR["AdminUsuarioRepository"]
    GR["GanaderoRepository<br/>cursores de paginacion"]
  end

  subgraph SRV["Servicios"]
    APIC["ApiClient<br/>HTTPS + token + abort en cambio de sesion"]
    BLE["Esp32BleBridgeService<br/>escaneo, GATT, cola, sondeo, fallas tipadas"]
    Q["CommandQueue"]
    FCM["firebase_options / SDK Auth + Firestore"]
  end

  AUTHG --> LOGIN
  AUTHG --> ADMV
  AUTHG --> GANV
  AUTHG --> COMMON
  LOGIN --> AVM --> AR --> FCM
  ADMV --> ADMVM --> AUR --> APIC
  GANV --> GVM --> GR --> APIC
  GANV --> BLE
  BLE --> Q
  BLE --> APIC
  BLE -->|"BLE GATT"| ESP["ESP32 Bridge"]
  SN --> AVM
  SN --> ADMVM
  SN --> GVM
```

## 5. Secuencia — inicio de sesión y carga del panel

Fuente: `frontend/lib/views/auth/login_page.dart:34-51`,
`frontend/lib/data/repositories/auth_repository.dart`,
`frontend/lib/views/auth_gate.dart:11-33`,
`frontend/lib/viewmodels/ganadero_view_model.dart:40-55`,
`backend/src/middlewares/authMiddleware.js:13-103`.

```mermaid
sequenceDiagram
  participant U as Usuario
  participant L as LoginPage
  participant A as AuthRepository
  participant FB as Firebase Auth/Firestore
  participant G as AuthGate
  participant VM as GanaderoViewModel
  participant API as Backend Express

  U->>L: correo y contrasena
  L->>A: signIn(email, password)
  A->>FB: signInWithEmailAndPassword
  FB-->>A: credencial + uid
  A->>FB: get(Usuarios/uid, Source.server)
  FB-->>A: perfil (rol, estado)
  A-->>L: UsuarioModel
  L->>G: cambio de estado (Provider)
  G->>VM: loadDashboard() + loadAlertas()
  VM->>API: GET /api/ganadero/dashboard (Bearer ID token)
  API->>FB: verifyIdToken + perfil (rol/estado)
  API-->>VM: dashboard JSON
  VM-->>U: panel con resumen, historial y alertas
```

## 6. Secuencia — sesión de conteo completa

Fuente: `frontend/lib/data/services/esp32_ble_bridge_service.dart`,
`backend/src/services/iotService.js:11-103`,
`jetson/lora_jetson_rx.py:1318-1345`, `jetson/secure_protocol.py:60-100`,
`backend/src/controllers/ganaderoController.js:329-368`.

```mermaid
sequenceDiagram
  participant APP as App Flutter
  participant API as Backend
  participant ESP as ESP32
  participant JET as Jetson
  participant FS as Firestore

  APP->>API: POST /api/ganadero/iot/comandos {command: INICIARCONTEO}
  API->>FS: transaccion: crea IotSessions + lease en IotDevices
  API-->>APP: frame C1 firmado + request_id + session_id
  APP->>ESP: BLE ~C1...\n (fragmentos de 18 bytes)
  ESP->>JET: LoRa trama C1 completa
  JET->>JET: parse_command (firma, expiracion, sesion)
  JET->>JET: antirreplay SQLite (nueva solicitud)
  JET->>JET: lanza run_bovino.py (worker de deteccion)
  JET-->>ESP: R1|...|STARTED (firmada)
  ESP-->>APP: BLE notificacion con R1
  APP->>API: POST /api/ganadero/iot/respuestas {frame}
  API->>API: responseFrame (HMAC + estados)
  API->>FS: guarda response; actualiza sesion/dispositivo
  API-->>APP: {status: STARTED, session, count}

  loop Cada 4 s mientras corre
    APP->>API: POST /iot/comandos {command: ESTADOCONTEO}
    API-->>APP: C1 (comando Q)
    APP->>ESP: BLE
    ESP->>JET: LoRa
    JET-->>ESP: R1 RUNNING con count parcial
    ESP-->>APP: BLE
    APP->>API: POST /iot/respuestas
    API-->>APP: {status: RUNNING, count}
  end

  APP->>API: POST /iot/comandos {command: DETENERCONTEO}
  API-->>APP: C1 (comando T)
  APP->>ESP: BLE
  ESP->>JET: LoRa
  JET->>JET: detiene worker y firma resultado
  JET-->>ESP: R1 STOPPED con count y completed_at
  ESP-->>APP: BLE
  APP->>API: POST /iot/respuestas
  API-->>APP: {status: STOPPED, count, proof}
  APP->>API: POST /api/ganadero/conteos {session_id, proof}
  API->>FS: crea Conteos + Alertas si hay diferencia
  API-->>APP: 201 conteo guardado
```

## 7. Secuencia — alta de usuario por el administrador

Fuente: `frontend/lib/views/admin/usuario_form_page.dart:65-98`,
`backend/src/controllers/usuarioController.js:45-58`,
`backend/src/services/userService.js:12-108`.

```mermaid
sequenceDiagram
  participant ADM as Administrador
  participant FORM as UsuarioFormPage
  participant API as Backend
  participant FS as Firestore
  participant AUTH as Firebase Auth
  participant SMTP as SMTP

  ADM->>FORM: datos + request_id (generado por el repositorio)
  FORM->>API: POST /api/admin/usuarios
  API->>API: validarPayload (nombre, cedula, correo, rol, estado)
  API->>FS: transaccion: OperacionesUsuarios (pending) + CedulasUsuarios
  API->>AUTH: createUser(uid, email, password aleatoria, disabled?)
  API->>FS: transaccion: escribe Usuarios + marca operacion done
  API->>AUTH: generatePasswordResetLink
  API->>SMTP: enviarActivacion
  alt correo enviado
    SMTP-->>API: aceptado
    API-->>FORM: 201 + activation_pending false
  else correo falla
    API-->>FORM: 201 + activation_pending true (recuperable por "Recuperar contrasena")
  end
  FORM-->>ADM: aviso + lista recargada
```

## 8. Máquina de estados de la sesión de conteo

Fuente: `backend/src/services/iotProtocol.js:4-5`,
`jetson/secure_protocol.py:12`, `jetson/lora_jetson_rx.py:985-1040,1132`.

```mermaid
stateDiagram-v2
  [*] --> IDLE
  IDLE --> READY: P (PREPARARCONTEO)
  READY --> STARTED: S (INICIARCONTEO)
  STARTED --> RUNNING: worker activo
  RUNNING --> STOPPED: T (DETENERCONTEO)
  RUNNING --> RESULT: R (resultado solicitado)
  STOPPED --> RESULT: resultado firmado disponible
  RUNNING --> ERROR: fallo del worker o timeout
  STOPPED --> IDLE: nueva sesion (reinicio del receptor)
  ERROR --> IDLE: equipo liberado por el backend
  RESULT --> IDLE: sesion cerrada y conteo guardado
  BUSY --> RUNNING: conflicto resuelto
  note right of IDLE
    El backend libera el dispositivo
    (lease en cero) cuando recibe IDLE.
  end note
```

## 9. Flujo interno de detección y tracking en la Jetson

Fuente: `jetson/run_bovino.py` (hilos de captura, inferencia y dibujo),
`jetson/lora_jetson_rx.py` (sesión y lectura de hooks).

```mermaid
flowchart TD
  A["lora_jetson_rx.py<br/>recibe C1 S"] --> B["CountSessionController.start()"]
  B --> C["subprocess: run_bovino.py --engine ... --source csi://0"]
  C --> D["capture_worker<br/>GStreamer CSI/NVMM o archivo"]
  D --> E["infer_worker<br/>TRTDetector.preprocess + infer"]
  E --> F["decode_detections<br/>NMS + umbral de confianza"]
  F --> G["tracker.update<br/>BoT-SORT + GMC ORB"]
  G --> H{"track confirmado<br/>e identidad nueva?"}
  H -->|"si"| I["COUNT_ACCEPTED + COUNT_UPDATE"]
  H -->|"no"| J["COUNT_REJECTED_ALREADY_COUNTED"]
  I --> K["stdout + archivo JSON de estado"]
  J --> K
  E --> L["PIPELINE_METRIC / TRACK_METRIC cada 5 s"]
  K --> M["lora_jetson_rx lee hooks y log"]
  M --> N["responde R1 (status, count, completed_at)"]
```

## 10. Despliegue

Fuente: `backend/vercel.json`, `backend/api/index.js`,
`frontend/android/app/build.gradle.kts`, `frontend/run_usb.sh`,
`jetson/systemd/unbuffered.conf`, `docs/seguridad-y-despliegue.md`.

```mermaid
graph TB
  subgraph Dev["Equipo de desarrollo"]
    PC["Backend local<br/>npm run dev en 0.0.0.0:3000"]
    ADBR["adb reverse tcp:3000"]
  end

  subgraph Cloud["Nube"]
    VER["Vercel<br/>api/index.js (maxDuration 30)"]
    FBC["Firebase Auth + Firestore"]
  end

  subgraph Phone["Telefono"]
    APK["APK debug/release<br/>API_BASE_URL via dart-define"]
  end

  subgraph Edge["Jetson"]
    SVC["bovisense-lora.service<br/>EnvironmentFile=/etc/bovisense/iot.env"]
    DROP["drop-in unbuffered.conf<br/>PYTHONUNBUFFERED=1"]
    VENV["venv env_detection"]
    ENG["engine TensorRT (fuera del repo)"]
  end

  APK -->|"debug: HTTP 127.0.0.1:3000"| ADBR --> PC
  APK -->|"release: HTTPS"| VER
  PC --> FBC
  VER --> FBC
  SVC --> VENV
  SVC --> ENG
  DROP --> SVC
```
