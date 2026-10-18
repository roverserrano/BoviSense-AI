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
  int _epoch = 0;

  /// Hay al menos una tarea en ejecucion o esperando turno.
  bool get isBusy => _pending > 0;

  /// Descarta las tareas que aun esperan turno.
  ///
  /// Se usa al desconectar o reconectar: una tarea encolada para una conexion
  /// que ya no existe no debe ejecutarse contra la conexion siguiente.
  void invalidate() {
    _epoch++;
  }

  /// Encola [action] y devuelve su resultado, o `null` si la cola se invalido
  /// antes de que le tocara el turno. Un fallo de una tarea no corta la cola:
  /// la siguiente se ejecuta igual.
  Future<T?> add<T>(Future<T> Function() action) {
    _pending++;
    final epoch = _epoch;
    final Future<T?> task = _tail.then<T?>(
      (_) => epoch == _epoch ? action() : null,
      onError: (Object _) => epoch == _epoch ? action() : null,
    );
    _tail = task
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() => _pending--);
    return task;
  }
}
