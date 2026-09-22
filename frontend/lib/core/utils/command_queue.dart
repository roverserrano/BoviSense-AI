import 'dart:async';

/// Serializa operaciones asincronas: cada tarea espera a que termine la
/// anterior.
///
/// Se usa para no solapar comandos hacia el equipo. Antes, si el sondeo
/// automatico del conteo estaba en vuelo, una accion del usuario fallaba con
/// "Espera la respuesta del equipo"; ahora espera su turno y se ejecuta.
class CommandQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  /// Hay al menos una tarea en ejecucion o esperando turno.
  bool get isBusy => _pending > 0;

  /// Encola [action] y devuelve su resultado. Un fallo de una tarea no corta
  /// la cola: la siguiente se ejecuta igual.
  Future<T> add<T>(Future<T> Function() action) {
    _pending++;
    final Future<T> task = _tail.then<T>(
      (_) => action(),
      onError: (Object _) => action(),
    );
    _tail = task
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() => _pending--);
    return task;
  }
}
