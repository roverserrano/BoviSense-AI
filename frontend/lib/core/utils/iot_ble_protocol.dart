/// Contrato de transporte compartido con bridge_protocol.h y C1/R1.
/// La validacion de firma siempre corresponde al backend.
class IotBleProtocol {
  static const commandLimit = 180;
  static const responseLimit = 200;
  static const chunkSize = 18;
  static const assemblyTimeout = Duration(seconds: 5);
  static const writeTimeout = Duration(seconds: 5);
  static const responseTimeout = Duration(seconds: 25);

  static bool matchesReply(String frame, String? request, String? session) {
    if (request == null || session == null) return false;
    final fields = frame.split('|');
    if (fields.length == 8 && fields[0] == 'R1') {
      return fields[1] == request && fields[2] == session;
    }
    return fields.length == 4 &&
        fields[0] == 'B0' &&
        fields[1] == request &&
        fields[2] == 'ERROR';
  }
}

/// Reconstruye notificaciones, descarta fragmentos vencidos y permite que una
/// segunda copia R1 recupere una primera copia incompleta.
class IotBleFrameDecoder {
  IotBleFrameDecoder({int Function()? nowMilliseconds})
    : _nowMilliseconds = nowMilliseconds;

  final int Function()? _nowMilliseconds;
  final Stopwatch _clock = Stopwatch()..start();
  String _buffer = '';
  bool _receiving = false;
  int? _lastByteAt;

  void reset() {
    _buffer = '';
    _receiving = false;
    _lastByteAt = null;
  }

  List<String> add(List<int> bytes) {
    final frames = <String>[];
    final now = _nowMilliseconds?.call() ?? _clock.elapsedMilliseconds;
    if (_lastByteAt != null &&
        now - _lastByteAt! >= IotBleProtocol.assemblyTimeout.inMilliseconds) {
      reset();
    }
    for (final byte in bytes) {
      if (byte == 126) {
        _buffer = '';
        _receiving = true;
      } else if (byte == 10 && _receiving) {
        frames.add(_buffer);
        reset();
      } else if (_receiving &&
          byte >= 32 &&
          byte <= 126 &&
          _buffer.length < IotBleProtocol.responseLimit) {
        _buffer += String.fromCharCode(byte);
      } else {
        reset();
      }
    }
    _lastByteAt = now;
    return frames;
  }
}
