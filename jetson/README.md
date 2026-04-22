# Jetson LoRa controller files

Estos archivos son copias desplegables de los scripts encontrados fuera del
workspace en:

- `/home/spartano/Documentos/chat_local/received_files/lora_jetson_rx.py`
- `/home/spartano/Documentos/chat_local/received_files/run_bovino.py`

El repo no contenia el script Jetson original en su arbol. Para aplicar el MVP
en la Jetson, copia `jetson/lora_jetson_rx.py` sobre la ruta real del receptor
LoRa y, si quieres hooks estructurados del worker, copia tambien
`jetson/run_bovino.py` sobre `/home/cow/Documents/proyecto/run_bovino.py`.

`lora_jetson_rx.py` funciona aunque `run_bovino.py` no emita resultados
estructurados: mantiene estado real del proceso y reporta `count=unknown` hasta
que el worker publique un conteo confiable.
