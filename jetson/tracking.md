Actúa como un ingeniero senior especializado en **visión por computadora, Multi-Object Tracking (MOT), NVIDIA Jetson Orin, TensorRT, GStreamer y Python**.

Estás trabajando sobre un proyecto de grado de detección y conteo de bovinos/becerros mediante un dron.

Tu tarea es **analizar y modificar cuidadosamente el archivo existente `run_bovino.py` para añadir seguimiento persistente de bovinos**, manteniendo intacto todo lo que actualmente funciona.

# REGLA PRINCIPAL

**NO debes reescribir el programa desde cero.**

**NO debes reemplazar la detección existente.**

**NO debes romper ni cambiar innecesariamente el conteo de bovinos que actualmente funciona.**

**NO debes modificar la captura CSI/GStreamer si actualmente funciona.**

**NO debes modificar el motor TensorRT ni la inferencia MobileNet si actualmente funciona.**

**NO debes modificar la comunicación LoRa existente salvo que sea estrictamente necesario para transportar información que ya genera el sistema.**

La implementación debe ser **incremental, modular y mínimamente invasiva**.

El archivo principal y único que debes modificar es:

```text
run_bovino.py
```

Antes de modificar cualquier cosa, analiza completamente ese archivo y entiende:

- inicialización;
- argumentos CLI;
- carga del engine TensorRT;
- captura CSI/GStreamer;
- preprocesamiento;
- inferencia;
- postprocesamiento;
- formato de bounding boxes;
- NMS;
- clases;
- confidence threshold;
- visualización;
- contador existente;
- condiciones bajo las cuales actualmente se incrementa el conteo;
- estructuras de estado existentes;
- threads;
- callbacks;
- comunicación LoRa;
- inicio y detención del conteo;
- cualquier estado compartido.

No hagas suposiciones sobre cómo funciona `run_bovino.py`.

Primero entiéndelo y después intégrate con su arquitectura real.

---

# CONTEXTO DEL DETECTOR

El detector existente es:

```text
MobileNet SSD
Entrada: 640x640 px
TensorRT
Clase objetivo: bovino/becerro
Hardware: NVIDIA Jetson Orin
Cámara: CSI
Plataforma: dron en movimiento
```

Actualmente la detección y el conteo ya funcionan.

El problema que queremos resolver ahora es el seguimiento temporal.

Una misma vaca puede aparecer durante cientos de frames:

```text
Frame 1   -> bovino
Frame 2   -> bovino
Frame 3   -> bovino
...
Frame 200 -> bovino
```

Estas detecciones deben convertirse en:

```text
Frame 1   -> ID 7
Frame 2   -> ID 7
Frame 3   -> ID 7
...
Frame 200 -> ID 7
```

El sistema debe distinguir entre:

```text
DETECCIÓN
TRACKING
CONTEO
```

La detección seguirá siendo responsabilidad del MobileNet existente.

El tracker debe recibir únicamente las detecciones ya producidas por MobileNet.

---

# OBJETIVO

Implementar una arquitectura aproximadamente equivalente a:

```text
CSI CAMERA
     |
     v
GStreamer / NVMM
     |
     v
MobileNet SSD TensorRT
640x640
     |
     | bbox + confidence + class
     v
TRACKER
BoT-SORT preferiblemente
     |
     | tracker_id
     v
TRACK MANAGER
     |
     | confirmed tracks
     v
COUNT MANAGER EXISTENTE
     |
     v
LoRa / salida actual
```

La prioridad es:

```text
MobileNet
+
BoT-SORT
+
Global Motion Compensation
+
persistencia de IDs
+
protección contra doble conteo
```

---

# MUY IMPORTANTE: NO CAMBIAR EL DETECTOR

El tracker debe ser completamente posterior a la inferencia.

Debes conservar:

```text
MobileNet -> detecciones
```

y añadir:

```text
MobileNet -> detecciones -> tracker
```

NO hagas:

```text
MobileNet -> reemplazar detector
```

NO sustituyas MobileNet por YOLO.

NO cambies el engine TensorRT.

NO cambies 640x640.

NO vuelvas a entrenar el modelo.

NO introduzcas Ultralytics como detector.

---

# TRACKER RECOMENDADO

La primera opción debe ser:

```text
BoT-SORT
```

porque la cámara estará montada sobre un dron y, por tanto:

```text
movimiento observado =
movimiento del bovino
+
movimiento de la cámara
```

Se necesita, siempre que la implementación utilizada lo permita:

```text
Global Motion Compensation (GMC)
```

para compensar:

- traslación;
- rotación;
- movimiento global de cámara.

BoT-SORT debe utilizar conceptualmente:

```text
Kalman Filter
+
data association
+
Hungarian matching
+
IoU/motion
+
track buffer
+
GMC
```

No implementes desde cero BoT-SORT si existe una librería mantenida y compatible con Python/aarch64.

Preferentemente evalúa el paquete moderno:

```text
trackers
```

de Roboflow.

NO confundas `supervision` con un tracker.

`supervision` puede utilizarse únicamente como estructura auxiliar para representar detecciones si realmente simplifica la integración.

Si `sv.ByteTrack` aparece en ejemplos antiguos, no lo introduzcas automáticamente porque se encuentra deprecado en versiones actuales.

---

# FALLBACK

Si por una incompatibilidad real y demostrable con el entorno Jetson no es posible utilizar inmediatamente BoT-SORT, estructura el código para poder utilizar:

```text
ByteTrack
```

como fallback.

Pero NO reemplaces silenciosamente BoT-SORT sin explicarlo.

La arquitectura debe permitir que en el futuro se puedan comparar:

```text
BoT-SORT
ByteTrack
OC-SORT
```

sin modificar la inferencia.

Idealmente introduce una abstracción sencilla del estilo:

```python
tracker = create_tracker(...)
```

pero sin sobreingeniería.

---

# REQUISITO CRÍTICO: COMPATIBILIDAD CON LAS DETECCIONES ACTUALES

Localiza exactamente dónde `run_bovino.py` obtiene actualmente algo equivalente a:

```python
bbox
confidence
class_id
```

Adapta esos datos al tracker.

No cambies la estructura original antes de confirmar cómo se representa.

El tracker debería recibir conceptualmente:

```text
[x1, y1, x2, y2]
confidence
class_id
```

Si las cajas están en otro formato:

```text
xywh
cxcywh
normalized coordinates
```

haz únicamente la conversión requerida para el tracker.

---

# LETTERBOX / ESCALADO

Analiza cuidadosamente cómo MobileNet procesa la imagen.

Si la imagen CSI original tiene una resolución distinta de 640x640, determina si se utiliza:

```text
resize directo
```

o:

```text
letterbox
```

No supongas.

Si existe letterbox, debes respetar:

```text
scale
pad_x
pad_y
```

al transformar bounding boxes.

Una conversión incorrecta de coordenadas provocaría errores de tracking.

No cambies el preprocesamiento existente salvo que exista un bug confirmado.

---

# FILTRO DE KALMAN

No añadas un segundo filtro de Kalman independiente si BoT-SORT ya lo incorpora.

Debe existir una sola lógica coherente de predicción del tracker.

El filtro se utilizará para mantener estimaciones temporales de:

```text
posición
tamaño de bbox
velocidad
```

pero recuerda:

**Kalman NO identifica al bovino por apariencia.**

---

# ESTADOS DE TRACK

Debes manejar estados equivalentes a:

```text
tentative
confirmed
lost
removed
```

La nomenclatura exacta puede depender de la librería.

No contabilices automáticamente cualquier detección de un único frame como un nuevo animal.

Un track debe alcanzar un estado suficientemente confiable antes de ser utilizado por la lógica anti-duplicado.

Conceptualmente:

```text
detección
detección
detección
      |
      v
confirmed track
```

Esto debe ayudar a reducir falsos positivos.

---

# TRACK BUFFER

No elimines un ID porque MobileNet falle durante uno o pocos frames.

Ejemplo:

```text
ID 12
ID 12
ID 12
MISS
MISS
ID 12
```

El tracker debe poder conservar temporalmente ese track.

Utiliza el mecanismo de:

```text
track buffer
lost track
max age
```

que proporcione el tracker seleccionado.

Los valores NO deben colocarse arbitrariamente.

Ponlos como constantes configurables o argumentos CLI claramente documentados.

---

# MOVIMIENTO DEL DRON

Este es un requisito central.

La cámara NO será fija.

Por tanto:

```text
bovino aparentemente desplazándose en la imagen
```

puede ser consecuencia de:

```text
movimiento del dron
```

y no solamente del bovino.

Activa/utiliza Global Motion Compensation de BoT-SORT si la implementación seleccionada lo soporta.

Evalúa la opción compatible más razonable entre:

```text
ORB
ECC
```

sin introducir una carga absurda de procesamiento.

No implementes todavía fusión GPS/IMU si esos datos no están ya disponibles dentro de `run_bovino.py`.

Diseña solamente la arquitectura para que pueda añadirse posteriormente.

---

# REID

NO implementar todavía un modelo ReID adicional.

No queremos introducir actualmente:

```text
MobileNet
+
otro CNN ReID
```

porque:

- incrementa uso de GPU;
- incrementa latencia;
- requiere entrenamiento específico de bovinos;
- puede complicar innecesariamente esta primera integración.

Deja la arquitectura preparada para una posible futura incorporación, pero NO la implementes ahora.

---

# REQUISITO MÁS IMPORTANTE: NO ROMPER EL CONTEO EXISTENTE

Debes localizar exactamente cómo funciona actualmente el conteo.

NO lo elimines.

NO lo reemplaces completamente.

NO modifiques sus condiciones funcionales salvo donde sea estrictamente necesario para impedir que un mismo track produzca más de un evento de conteo.

La nueva lógica debe integrarse alrededor del conteo existente.

Conceptualmente queremos pasar de:

```text
detección
    |
    v
lógica existente de conteo
```

a:

```text
detección
    |
    v
tracker
    |
    v
tracker_id
    |
    +----------------+
    |                |
    v                v
lógica existente   anti-duplicado
de conteo
    |
    v
TOTAL
```

El tracker NO debe cambiar arbitrariamente cuándo un bovino cumple las condiciones actuales para ser contado.

Debe proporcionar una identidad temporal que permita saber si ese animal ya produjo un evento de conteo.

---

# COUNTED IDS

Introduce una estructura equivalente a:

```python
counted_track_ids = set()
```

pero NO incrementes el contador simplemente porque aparece un nuevo ID.

Primero debe cumplirse la condición de conteo que ya existe en `run_bovino.py`.

Solamente cuando el sistema existente determine:

```text
este bovino debe ser contado
```

debes consultar:

```python
if tracker_id not in counted_track_ids:
```

y entonces permitir:

```python
counted_track_ids.add(tracker_id)
```

y ejecutar EXACTAMENTE el mecanismo de incremento existente.

En pseudocódigo:

```python
if existing_count_condition:
    if track_is_confirmed:
        if tracker_id not in counted_track_ids:
            counted_track_ids.add(tracker_id)

            # mantener aquí el mecanismo existente
            # que incrementa / transmite / registra el conteo
            existing_count_increment()
```

No implementes literalmente esta función si el código real utiliza otra arquitectura.

Adáptate al código existente.

---

# MUY IMPORTANTE SOBRE LOS IDS

Un `tracker_id` NO garantiza identidad global eterna.

Si:

```text
ID 7
sale completamente del campo visual
```

y después:

```text
ID 48
reaparece
```

podría tratarse del mismo bovino.

Por eso `counted_track_ids` solamente evita duplicados mientras el tracker conserva adecuadamente la identidad.

En esta fase implementaremos protección temporal basada en tracking.

NO inventes todavía una solución falsa de identidad global.

Deja comentarios claros explicando que una fase futura podrá utilizar:

```text
GPS
IMU
ground projection
spatial history
Cow ReID
```

para reidentificación global.

---

# RESET DEL CONTEO

Este punto es extremadamente importante.

Analiza cómo actualmente se inicia, reinicia y detiene una sesión de conteo.

Cuando el sistema existente haga un RESET/NUEVA SESIÓN de conteo, también deben limpiarse coherentemente:

```python
counted_track_ids
```

y cualquier estado del tracker que deba corresponder a una nueva misión/sesión.

NO dejes IDs de una sesión anterior contaminando una nueva sesión.

Si existe algo como:

```text
INICIARCONTEO
DETENERCONTEO
RESET
```

respeta exactamente ese flujo.

---

# DETECCIONES REPETIDAS VS DOBLE CONTEO

No intentes impedir que MobileNet detecte al mismo animal en cada frame.

Eso sería incorrecto.

Un bovino visible durante 5 segundos puede producir cientos de detecciones.

Lo correcto es:

```text
200 detecciones
        |
        v
1 track
        |
        v
1 tracker_id
        |
        v
máximo 1 evento de conteo
```

Mantén claramente separadas estas responsabilidades.

---

# VISUALIZACIÓN

Si `run_bovino.py` actualmente dibuja bounding boxes, conserva la visualización existente.

Añade, con el mínimo cambio posible, el `tracker_id` sobre cada bovino.

Ejemplo:

```text
Becerro ID: 7 | 0.91
```

o respetando el formato visual actual.

No destruyas ni sustituyas labels existentes.

Si el track está todavía en estado tentative, evita presentarlo como un bovino contado si eso pudiera generar confusión.

---

# DEBUG

Añade logs útiles pero controlables.

Necesitamos poder observar eventos como:

```text
TRACK CREATED
TRACK CONFIRMED
TRACK LOST
TRACK RECOVERED
TRACK REMOVED
COUNT ACCEPTED
COUNT REJECTED_ALREADY_COUNTED
```

Evita imprimir cientos de mensajes por segundo.

Utiliza el mecanismo de logging existente si el archivo ya dispone de uno.

NO añadas un framework de logging nuevo si no es necesario.

---

# ARGUMENTOS CLI

Analiza el sistema actual de argumentos.

Si encaja con su estructura, añade parámetros opcionales equivalentes a:

```text
--tracker
--track-high-thresh
--track-low-thresh
--track-buffer
--match-thresh
```

pero:

1. no rompas argumentos existentes;
2. no cambies sus nombres;
3. no cambies sus defaults;
4. no conviertas argumentos anteriormente opcionales en obligatorios.

Idealmente:

```text
--tracker botsort
```

debe seleccionar BoT-SORT.

También sería útil permitir:

```text
--tracker none
```

para ejecutar el pipeline exactamente como antes.

Esto es muy importante para poder hacer pruebas A/B.

---

# COMPATIBILIDAD HACIA ATRÁS

Debe existir una forma clara de ejecutar el comportamiento original.

Idealmente:

```bash
python3 run_bovino.py ... --tracker none
```

debe reproducir prácticamente el comportamiento previo.

Y:

```bash
python3 run_bovino.py ... --tracker botsort
```

debe activar tracking.

Si el código existente no se presta a esta implementación sin cambios grandes, utiliza la alternativa mínima equivalente.

---

# RENDIMIENTO

El sistema debe continuar funcionando en tiempo real en Jetson Orin.

Evita:

- copias innecesarias de frames;
- conversiones repetitivas CPU↔GPU;
- estructuras gigantes;
- procesamiento duplicado;
- inferencias adicionales;
- guardar frames innecesariamente;
- ReID adicional.

Mide o deja instrumentación para:

```text
FPS detector
FPS total
tiempo tracking/frame
```

pero sin afectar apreciablemente el rendimiento.

---

# THREAD SAFETY

Si `run_bovino.py` utiliza múltiples threads, analiza cuidadosamente qué variables son compartidas.

No introduzcas:

```text
race conditions
```

con:

```text
tracker
counted_track_ids
contador
estado de misión
```

Si ya existe un lock utilizado para el contador/estado, reutilízalo cuando corresponda.

No añadas locks indiscriminadamente.

---

# LORA

El tracking NO debe romper los mensajes LoRa actuales.

Si actualmente LoRa transmite:

```text
conteo
estado
```

debe seguir haciéndolo exactamente como antes.

NO cambies el protocolo LoRa en esta tarea.

Los `tracker_id` son inicialmente información local.

No los transmitas por LoRa salvo que el código existente ya contemple un campo compatible y haya una razón clara para hacerlo.

---

# MANEJO DE DEPENDENCIAS

Antes de importar una librería nueva:

1. verifica cuál es la API actual;
2. verifica compatibilidad con Python;
3. evita APIs deprecadas;
4. no inventes clases o métodos.

Si hace falta instalar una dependencia nueva, NO modifiques otros archivos automáticamente.

Al finalizar indícame exactamente:

```bash
pip install ...
```

que debo ejecutar dentro de:

```text
env_detection
```

Si existe riesgo de incompatibilidad aarch64/Jetson, explícalo.

No sustituyas paquetes NVIDIA existentes.

---

# NO HACER

Está explícitamente prohibido:

```text
- reemplazar MobileNet por YOLO
- cambiar el engine TensorRT
- cambiar el tamaño 640x640
- reescribir run_bovino.py desde cero
- modificar lora_jetson_rx.py
- modificar scripts que no sean run_bovino.py
- eliminar la lógica actual de conteo
- eliminar argumentos CLI existentes
- cambiar el protocolo LoRa
- implementar ReID todavía
- introducir GPS/IMU ficticios
- inventar datos no disponibles
- usar IDs del índice del array como tracker_id
- contar cada detección
- contar inmediatamente cualquier nuevo track
```

---

# METODOLOGÍA OBLIGATORIA

Antes de editar el archivo:

## 1. Analiza `run_bovino.py`

Identifica con precisión:

```text
A. captura
B. preprocessing
C. inferencia
D. postprocessing
E. detecciones finales
F. dibujo
G. conteo
H. estado de sesión
I. LoRa
J. threads
```

## 2. Identifica el punto exacto de integración

Debe estar después de:

```text
detecciones finales / NMS
```

y antes de utilizar las detecciones para lógica que se beneficie de identidad temporal.

## 3. Diseña cambios mínimos

Reutiliza las estructuras actuales siempre que sea posible.

## 4. Implementa tracking

Preferentemente BoT-SORT + GMC.

## 5. Integra tracker_id con el conteo existente

Sin cambiar las reglas actuales de cuándo debe contarse un bovino.

## 6. Añade reset correcto del tracking/conteo

Cuando empieza una nueva sesión.

## 7. Ejecuta validaciones estáticas

Como mínimo:

```bash
python3 -m py_compile run_bovino.py
```

Si el entorno permite ejecutar tests adicionales que NO necesiten la cámara física, ejecútalos.

## 8. Revisa el diff

Asegúrate de no haber realizado cambios innecesarios.

---

# CRITERIOS DE ACEPTACIÓN

La tarea se considera correcta solamente si se cumplen TODOS estos puntos:

- `run_bovino.py` sigue siendo el archivo principal.
- MobileNet SSD sigue realizando la detección.
- La entrada del modelo sigue siendo 640x640.
- TensorRT existente se conserva.
- CSI/GStreamer existente se conserva.
- Las detecciones existentes continúan generándose.
- Se asigna un ID persistente a un mismo bovino entre frames consecutivos.
- Una detección perdida brevemente no destruye inmediatamente el track.
- El tracker considera el movimiento de cámara mediante GMC cuando esté disponible.
- El contador existente continúa funcionando.
- Un mismo `tracker_id` no puede generar dos incrementos dentro de la misma sesión de conteo.
- Los estados del tracker se reinician correctamente al reiniciar la sesión.
- LoRa continúa funcionando.
- Los argumentos existentes continúan funcionando.
- Existe una forma de desactivar tracking para comparar contra el comportamiento anterior.
- `python3 -m py_compile run_bovino.py` termina correctamente.
- No se modifican archivos innecesarios.

---

# SALIDA QUE QUIERO DE TI

No te limites a pegar código sin explicación.

Después de analizar e implementar los cambios, proporciona:

## 1. Diagnóstico del código actual

Explica brevemente:

```text
- dónde se produce la detección;
- dónde está el conteo;
- dónde integraste el tracker.
```

## 2. Cambios realizados

Enumera exactamente qué bloques o funciones fueron modificados.

## 3. Tracker utilizado

Indica:

```text
BoT-SORT / ByteTrack / otro
```

y por qué.

## 4. Dependencias

Indica exactamente qué debo instalar, si corresponde.

## 5. Nuevos argumentos

Indica sus nombres y defaults.

## 6. Comandos de prueba

Proporciona comandos reales para:

```text
A. comportamiento anterior sin tracker
B. ejecución con BoT-SORT
```

utilizando los argumentos existentes de `run_bovino.py`.

## 7. Validación

Confirma el resultado de:

```bash
python3 -m py_compile run_bovino.py
```

## 8. Riesgos pendientes

Indica claramente cualquier limitación, por ejemplo:

```text
ID switch después de una salida prolongada del FOV
GMC fallando en terreno visualmente homogéneo
necesidad futura de GPS/IMU
necesidad futura de Cow ReID
```

---

# PRIORIDAD DE DISEÑO

Si tienes que elegir entre:

```text
A. código sofisticado que modifica muchas cosas
```

y:

```text
B. integración sencilla que conserva todo lo que ya funciona
```

elige **B**.

La prioridad es:

```text
1. NO ROMPER detección actual
2. NO ROMPER conteo actual
3. NO ROMPER LoRa
4. añadir tracking persistente
5. reducir doble conteo
6. mantener tiempo real
7. dejar arquitectura preparada para mejoras futuras
```

Trabaja directamente sobre el `run_bovino.py` existente y realiza la implementación de forma conservadora.