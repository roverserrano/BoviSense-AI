# Flujo de Comandos

## PING

Verifica vida del Jetson. Respuesta: `alive=true`.

## GET_STATUS

Devuelve estado logico del servicio y tarea simulada.

## GET_DEVICE_INFO

Devuelve nombre del nodo, version y modo. No expone secretos.

## START_TASK

Inicia una tarea simulada segura. No arranca procesos del sistema.

## STOP_TASK

Detiene la tarea simulada segura. No mata procesos del sistema.

