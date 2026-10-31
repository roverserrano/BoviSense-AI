# Comunicacion BoviSense: app, ESP32 y Jetson

El flujo vigente es **app -> backend (C1 firmado) -> BLE -> ESP32 -> LoRa ->
Jetson -> R1 firmada -> LoRa -> ESP32 -> BLE -> backend (verificacion) -> app**.
El historial exige la prueba final; una notificacion BLE o un B0 no basta.

- [Arquitectura](arquitectura-comunicacion.md)
- [Comandos, sesiones y recuperacion](flujo-comandos.md)
- [Limites BLE/LoRa y tiempos](protocolo-lora.md)
- [Cableado](../hardware/pinout-sugerido.md)
- [Detector y validacion Jetson](../../jetson/README.md)

`shared/protocol.py`, `shared/constants.py` y `shared/message_examples.json`
describen el protocolo historico JSON/WebSocket; no se usan en este enlace.

## Firmware

Carpeta: `comunicacion-iot/esp32/bridge_hotspot_lora_discovery/`. Mantener juntos el `.ino` y
`bridge_protocol.h`; abrir el `.ino` en Arduino IDE conserva el header como
parte del sketch. Identificador por puerto serie: `bovisense-c1r1-2.0`.

Compilacion local comprobada para `esp32:esp32:esp32` (ESP32 Dev Module),
Arduino-ESP32 **3.3.8**, libreria **LoRa 0.8.0** de Sandeep Mistry y BLE del core.
No instalar otra libreria BLE que sustituya la del core. No cambiar las
dependencias de una instalacion funcional sin comprobar compatibilidad.

Con esas herramientas ya disponibles:

```bash
arduino-cli compile --fqbn esp32:esp32:esp32 --warnings more \
  --build-path /tmp/bovisense-esp32-build \
  comunicacion-iot/esp32/bridge_hotspot_lora_discovery
```

Este comando solo compila. No incluye `--upload` ni puerto de dispositivo.
La compilacion local ocupo aproximadamente 84% de la particion de programa y
12% de RAM estatica; no son mediciones de heap durante ejecucion. LoRa 0.8.0
emite avisos de obsolescencia de `B111`/`B1000` dentro de la libreria, sin errores
del sketch. No se modificaron las bibliotecas instaladas.

Se conservaron nombre y UUID BLE, parametros RF y pines SS=5/RST=14/DIO0=4.
La placa seleccionada usa SPI SCK=18, MISO=19, MOSI=23. No hay cambios de
cableado; el RST de la **Jetson** sigue fijo a 3.3 V y no se pulsa.

El puente mantiene el arranque escalonado, CPU a 80 MHz y potencia BLE previa.
Ahora conserva la deteccion brownout: si reaparecen reinicios por baja tension,
revisar alimentacion. La compilacion no valida la fuente de energia.

## Pruebas locales sin equipos

Desde la raiz del repositorio:

```bash
python3 -B -m unittest discover -s comunicacion-iot/tests -p 'test_*.py'
```

Requiere Python, Node y g++ existentes. Compila el nucleo C++ de transporte en
un directorio temporal; comprueba fragmentacion, limites, rollover de reloj,
correlacion y reintentos. Genera C1 con el backend real, lo interpreta en C++
y Python; genera R1 en Python y la valida en C++ y Node. Prueba la deduplicacion
SQLite de los seis comandos con envios a los 0/6/12 s. Usa una clave publica
de prueba, sin leer `.env`, usar servicios ni tocar GPIO/SPI/BLE.

Otras suites afectadas:

```bash
cd frontend
flutter analyze --no-pub
flutter test --no-pub
```

```bash
cd backend
npm test
```

```bash
cd jetson
python3 -B -m unittest test_secure_protocol test_tracking_logic test_runtime_reliability
```

Las unitarias del backend usan Firestore en memoria. No sustituyen a la
integracion HTTP/Auth/Firestore con emuladores ni a las pruebas fisicas.
El workflow CI incluye el contrato entre lenguajes y la suite de recuperacion
del worker; la compilacion del sketch completo se verifico localmente y no
forma parte del job C++ de transporte.

## Secuencia de aceptacion en dispositivos — pendiente

El operador debe cargar la version revisada del sketch con su header y
actualizar app/backend/Jetson coherentemente. Esta mejora no cargo firmware,
no reinicio servicios y no transmitio ordenes fisicas.

1. Confirmar version por serie, BLE visible y radio inicializado despues de
   8 s. Verificar reloj sincronizado entre backend y Jetson.
2. Autenticar al usuario en la app y guardar la configuracion de finca.
3. Conectar BLE, consultar H y preparar P; iniciar S y comprobar Q periodico.
   `STARTED` no demuestra inferencia; comprobar frames/conteo en la Jetson.
4. Detener con T; verificar STOPPED/RESULT con prueba del backend, guardar una
   sola vez y consultar historial. Una escena vacia debe permitir un 0 valido.
5. Repetir C1 identico: mismo resultado, un solo lanzamiento. Interrumpir una
   primera notificacion BLE y comprobar recuperacion con la segunda R1.
6. Interrumpir BLE durante el conteo y reconectar: ningun comando encolado de
   la conexion anterior debe ejecutarse. Consultar Q/R antes de volver a iniciar.
7. Simular perdida LoRa con los radios alimentados y antenas conectadas:
   hasta tres intentos, fallo acotado, recuperacion al restaurar el enlace.
8. Reiniciar controladamente ESP32/Jetson: consultar estado, verificar reserva
   del backend y recuperar finales persistidos sin duplicar registros.
9. Ensayar errores de camara/modelo y falta de almacenamiento: ERROR sin prueba
   final. Medir latencias, heap, estabilidad de alimentacion y tasa de perdida.

BLE no incorpora emparejamiento autenticado en este cambio y LoRa no cifra los
datos. Las firmas impiden aceptar comandos/resultados alterados, pero no evitan
interferencia o denegacion de servicio. No existe confirmacion BLE de aplicacion
para cada fragmento: duplicacion y reintentos reducen perdidas, no garantizan
entrega. El backend sigue siendo necesario para emitir y verificar tickets.
