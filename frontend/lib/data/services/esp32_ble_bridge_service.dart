import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../viewmodels/session_notifier.dart';
import '../../core/utils/command_queue.dart';
import '../../core/utils/request_id.dart';
import '../repositories/ganadero_repository.dart';
import 'api_client.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum Esp32BleBridgeState {
  idle,
  permissionDenied,
  adapterOff,
  scanning,
  connecting,
  connected,
  disconnected,
  error,
}

/// Motivo concreto por el que no se pudo conectar, para poder explicarselo a
/// un usuario que no conoce detalles tecnicos.
enum Esp32BleBridgeFailure {
  none,
  bluetoothOff,
  bluetoothUnavailable,
  permissionDenied,
  deviceNotFound,
  bluetoothBusy,
  connectionFailed,
}

/// Falla de conexion con su motivo tipado.
class BleConnectException implements Exception {
  const BleConnectException(this.failure, this.message);

  final Esp32BleBridgeFailure failure;
  final String message;

  @override
  String toString() => message;
}

class Esp32BleBridgeEvent {
  const Esp32BleBridgeEvent({
    required this.message,
    required this.createdAt,
    required this.direction,
  });

  final String message;
  final DateTime createdAt;
  final String direction;
}

class JetsonStatusSnapshot {
  const JetsonStatusSnapshot({
    required this.fields,
    required this.receivedAt,
    required this.rawMessage,
  });

  final Map<String, String> fields;
  final DateTime receivedAt;
  final String rawMessage;

  String get hostname => fields['hostname'] ?? 'No disponible';
  String get powerMode =>
      fields['power_mode'] ?? fields['p'] ?? 'No disponible';
  String get uptime => fields['uptime'] ?? fields['u'] ?? 'No disponible';
  String get cpuTemp => fields['cpu_temp'] ?? fields['t'] ?? 'No disponible';
  String get memory {
    final value = fields['memory'] ?? fields['m'];
    if (value == null || value.isEmpty) {
      return 'No disponible';
    }
    if (value.contains('MB') || value == 'No disponible') {
      return value;
    }
    return '$value MB';
  }

  String get loadAverage =>
      fields['load_avg'] ?? fields['l'] ?? 'No disponible';
}

class JetsonCountSnapshot {
  const JetsonCountSnapshot({
    required this.fields,
    required this.receivedAt,
    required this.rawMessage,
  });

  final Map<String, String> fields;
  final DateTime receivedAt;
  final String rawMessage;

  String get status => fields['status'] ?? 'UNKNOWN';
  String get sessionId => fields['session'] ?? fields['sessionId'] ?? 'none';
  String get pid => fields['pid'] ?? 'No disponible';
  String get elapsedSec => fields['elapsed'] ?? fields['elapsedSec'] ?? '0';
  String get count => fields['count'] ?? 'unknown';
  String get reason => fields['reason'] ?? fields['finishReason'] ?? '';
  String get detail => fields['detail'] ?? '';
  bool get started => status == 'STARTED' || status == 'RUNNING';
  bool get running => status == 'STARTED' || status == 'RUNNING';
  String? get proof => fields['proof'];
  bool get finalResult =>
      (status == 'STOPPED' || status == 'RESULT') && proof != null;
  bool get failed => status == 'ERROR';
  bool get busy => status == 'BUSY';
  bool get ready => status == 'READY';

  String get countLabel {
    if (count.isEmpty || count == 'unknown' || count == 'null') {
      return 'No disponible';
    }
    return count;
  }
}

class Esp32BleBridgeService extends SessionNotifier {
  Esp32BleBridgeService(this._repository) {
    // Vigila el adaptador desde el inicio: si el Bluetooth esta apagado, la
    // pantalla de conteo lo avisa antes de que el usuario intente conectar.
    _watchAdapter();
  }
  final GanaderoRepository _repository;

  /// Comandos que solo tienen sentido con una sesion viva en el equipo.
  static const sessionCommands = {
    'ESTADOCONTEO',
    'DETENERCONTEO',
    'RESULTADOCONTEO',
  };

  /// El backend o el equipo ya no reconocen la sesion que la app mostraba.
  ///
  /// Pasa cuando la Jetson se reinicia: no hay que presentarlo como falla del
  /// equipo, sino descartar el estado viejo y dejar iniciar un conteo nuevo.
  @visibleForTesting
  static bool isStaleSessionError(Object error) {
    return error is ApiException &&
        error.statusCode == 409 &&
        error.message.toLowerCase().contains('sesion');
  }

  /// Traduce el estado del adaptador a una falla explicable.
  @visibleForTesting
  static Esp32BleBridgeFailure failureForAdapterState(
    BluetoothAdapterState state,
  ) {
    switch (state) {
      case BluetoothAdapterState.on:
        return Esp32BleBridgeFailure.none;
      case BluetoothAdapterState.unauthorized:
        return Esp32BleBridgeFailure.permissionDenied;
      case BluetoothAdapterState.unavailable:
        return Esp32BleBridgeFailure.bluetoothUnavailable;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
      case BluetoothAdapterState.turningOn:
      case BluetoothAdapterState.unknown:
        return Esp32BleBridgeFailure.bluetoothOff;
    }
  }

  /// Texto que ve el ganadero. Evita tecnicismos y dice que hacer.
  static String failureMessage(Esp32BleBridgeFailure failure) {
    switch (failure) {
      case Esp32BleBridgeFailure.none:
        return '';
      case Esp32BleBridgeFailure.bluetoothOff:
        return 'El Bluetooth del teléfono está apagado. BoviSense lo necesita para '
            'comunicarse con el equipo de conteo. Actívalo y volvemos a intentar.';
      case Esp32BleBridgeFailure.bluetoothUnavailable:
        return 'El Bluetooth del teléfono no está disponible en este momento. '
            'Espera unos segundos y vuelve a intentar.';
      case Esp32BleBridgeFailure.permissionDenied:
        return 'BoviSense necesita permiso de Bluetooth para conectarse al equipo '
            'de conteo. Actívalo en los ajustes de la aplicación.';
      case Esp32BleBridgeFailure.deviceNotFound:
        return 'No se encontró el equipo de conteo. Verifica que esté encendido, '
            'con batería y cerca del teléfono.';
      case Esp32BleBridgeFailure.bluetoothBusy:
        return 'El Bluetooth del teléfono está ocupado con otros dispositivos '
            '(audífonos, parlantes o reloj). BoviSense necesita el Bluetooth para '
            'conectarse al sistema de conteo: desconéctalos o apaga y enciende el '
            'Bluetooth, y vuelve a intentar.';
      case Esp32BleBridgeFailure.connectionFailed:
        return 'El equipo de conteo está cerca pero no aceptó la conexión. '
            'Apágalo y enciéndelo, y vuelve a intentar.';
    }
  }

  static const deviceName = 'BoviSense-Bridge';
  static final serviceUuid = Guid('7d2f0001-1f3b-4a9b-8f2a-b05e00000001');
  static final rxCharacteristicUuid = Guid(
    '7d2f0002-1f3b-4a9b-8f2a-b05e00000001',
  );
  static final txCharacteristicUuid = Guid(
    '7d2f0003-1f3b-4a9b-8f2a-b05e00000001',
  );
  Esp32BleBridgeState _state = Esp32BleBridgeState.idle;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  StreamSubscription<List<ScanResult>>? _scan;
  StreamSubscription<BluetoothConnectionState>? _connection;
  StreamSubscription<List<int>>? _notifications;
  Completer<String>? _reply;
  Completer<BluetoothDevice?>? _found;
  String? _requestId;
  String _buffer = '';
  bool _receiving = false;
  bool _sending = false;
  int _generation = 0;
  Timer? _poll;
  int _pollFailures = 0;
  bool _paused = false;
  final CommandQueue _commands = CommandQueue();
  StreamSubscription<BluetoothAdapterState>? _adapterWatch;
  Esp32BleBridgeFailure _failure = Esp32BleBridgeFailure.none;
  List<String> _otherBluetoothDevices = const [];
  String? _errorMessage;
  JetsonStatusSnapshot? _latestJetsonStatus;
  JetsonCountSnapshot? _latestCountStatus;
  final List<Esp32BleBridgeEvent> _events = [];

  Esp32BleBridgeState get state => _state;
  BluetoothDevice? get device => _device;
  String get deviceLabel => _device?.platformName.isNotEmpty == true
      ? _device!.platformName
      : deviceName;
  String? get errorMessage => _errorMessage;

  /// Motivo concreto de la ultima falla de conexion.
  Esp32BleBridgeFailure get failure => _failure;

  /// Dispositivos que el telefono tiene conectados por Bluetooth (audifonos,
  /// parlantes, reloj). Sirve para explicar que el Bluetooth esta ocupado.
  List<String> get otherBluetoothDevices =>
      List.unmodifiable(_otherBluetoothDevices);
  List<Esp32BleBridgeEvent> get events => List.unmodifiable(_events);
  JetsonStatusSnapshot? get latestJetsonStatus => _latestJetsonStatus;
  JetsonCountSnapshot? get latestCountStatus => _latestCountStatus;
  bool get isConnected => _state == Esp32BleBridgeState.connected;
  bool get isSending => _sending;
  bool get isBusy =>
      _state == Esp32BleBridgeState.scanning ||
      _state == Esp32BleBridgeState.connecting;
  bool _current(int generation) => !disposed && generation == _generation;

  String _shortId(String? value) {
    if (value == null || value.length < 8) return value ?? '-';
    return value.substring(0, 8);
  }

  void pausePolling() {
    _paused = true;
    _poll?.cancel();
    _poll = null;
  }

  /// Descarta el conteo terminado y deja el equipo listo para uno nuevo.
  ///
  /// Se usa despues de guardar: las pantallas del ganadero viven en un
  /// IndexedStack, asi que sin esto el resultado (y el boton "Guardar")
  /// seguian apareciendo al volver a la vista de conteo.
  void resetCountSession() {
    _poll?.cancel();
    _poll = null;
    _pollFailures = 0;
    _latestCountStatus = null;
    _errorMessage = null;
    _failure = Esp32BleBridgeFailure.none;
    if (disposed) return;
    _event('Conteo guardado; listo para iniciar otro.', direction: 'STATUS');
    notifyListeners();
  }

  void resumePolling() {
    _paused = false;
    if (disposed || !isConnected) return;
    if (_sending) {
      _scheduleCountPoll();
      return;
    }
    unawaited(
      requestCountingStatus().catchError((Object _) {
        if (disposed) return;
        _errorMessage = 'No se pudo recuperar el estado del conteo.';
        notifyListeners();
        _scheduleCountPoll(failures: _pollFailures + 1);
      }),
    );
  }

  /// Mantiene viva la consulta periodica del conteo.
  ///
  /// Antes se reprogramaba solo cuando la respuesta llegaba a tiempo: si el
  /// equipo tardaba, respondia BUSY o fallaba la verificacion, la cadena moria
  /// y la pantalla quedaba congelada en el ultimo conteo conocido. Ahora cada
  /// intento fallido se reintenta con espera creciente.
  void _scheduleCountPoll({int failures = 0, Duration? delay}) {
    _poll?.cancel();
    _poll = null;
    _pollFailures = failures;
    if (disposed || _paused || !isConnected) return;
    if (_latestCountStatus?.running != true) return;
    _poll = Timer(
      delay ?? _pollDelay(failures),
      () => unawaited(_runCountPoll()),
    );
  }

  /// Cadencia objetivo entre consultas de conteo.
  static const countPollCadence = Duration(seconds: 4);

  static Duration _pollDelay(int failures) {
    const schedule = [
      countPollCadence,
      Duration(seconds: 5),
      Duration(seconds: 8),
      Duration(seconds: 12),
    ];
    return schedule[failures.clamp(0, schedule.length - 1)];
  }

  Future<void> _runCountPoll() async {
    _poll = null;
    if (disposed || _paused || !isConnected) return;
    if (_latestCountStatus?.running != true) return;
    if (_sending) {
      _scheduleCountPoll(failures: _pollFailures + 1);
      return;
    }
    final startedAt = DateTime.now();
    try {
      await requestCountingStatus();
      // Mantiene la cadencia real aunque la consulta tarde: el intervalo se
      // cuenta desde que empezo, no desde que respondio.
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = countPollCadence - elapsed;
      _scheduleCountPoll(
        delay: remaining.isNegative ? const Duration(seconds: 1) : remaining,
      );
    } catch (_) {
      if (disposed) return;
      _errorMessage = 'No se pudo actualizar el conteo. Consulta su estado.';
      notifyListeners();
      _scheduleCountPoll(failures: _pollFailures + 1);
    }
  }

  void _setState(Esp32BleBridgeState value) {
    _state = value;
    notifyListeners();
  }

  Future<void> scanAndConnect() async {
    if (disposed || isBusy || isConnected) return;
    final generation = ++_generation;
    _errorMessage = null;
    _failure = Esp32BleBridgeFailure.none;
    _otherBluetoothDevices = const [];
    _latestCountStatus = null;
    _latestJetsonStatus = null;
    _event('Buscando puente BLE', direction: 'BLE');
    _setState(Esp32BleBridgeState.scanning);
    try {
      await _release();
      if (!_current(generation)) return;
      await _ensureBluetoothPermissions();
      if (!_current(generation)) return;
      await _ensureBluetoothOn();
      if (!_current(generation)) return;
      _watchAdapter();
      final found = Completer<BluetoothDevice?>();
      _found = found;
      _scan = FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            if (_current(generation) &&
                !found.isCompleted &&
                result.advertisementData.serviceUuids.contains(serviceUuid)) {
              found.complete(result.device);
              break;
            }
          }
        },
        onError: (Object error) {
          if (!found.isCompleted) found.complete(null);
        },
      );
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 12),
      );
      final device = await found.future.timeout(
        const Duration(seconds: 13),
        onTimeout: () => null,
      );
      await FlutterBluePlus.stopScan();
      await _scan?.cancel();
      _scan = null;
      _found = null;
      if (!_current(generation)) return;
      if (device == null) {
        // Sin puente a la vista: puede ser que el equipo este apagado o que el
        // Bluetooth del telefono este ocupado con otros dispositivos.
        final others = await _systemBluetoothDevices();
        _otherBluetoothDevices = others;
        throw BleConnectException(
          others.isEmpty
              ? Esp32BleBridgeFailure.deviceNotFound
              : Esp32BleBridgeFailure.bluetoothBusy,
          failureMessage(
            others.isEmpty
                ? Esp32BleBridgeFailure.deviceNotFound
                : Esp32BleBridgeFailure.bluetoothBusy,
          ),
        );
      }
      _device = device;
      _event('Puente encontrado: ${device.remoteId}', direction: 'BLE');
      _setState(Esp32BleBridgeState.connecting);
      try {
        await device.connect(
          timeout: const Duration(seconds: 12),
          autoConnect: false,
        );
      } catch (error) {
        if (!_current(generation)) return;
        final others = await _systemBluetoothDevices();
        _otherBluetoothDevices = others;
        throw BleConnectException(
          others.isEmpty
              ? Esp32BleBridgeFailure.connectionFailed
              : Esp32BleBridgeFailure.bluetoothBusy,
          failureMessage(
            others.isEmpty
                ? Esp32BleBridgeFailure.connectionFailed
                : Esp32BleBridgeFailure.bluetoothBusy,
          ),
        );
      }
      if (!_current(generation)) {
        await device.disconnect();
        return;
      }
      final services = await device.discoverServices().timeout(
        const Duration(seconds: 10),
      );
      if (!_current(generation)) return;
      final service = services.where((s) => s.uuid == serviceUuid).firstOrNull;
      _rx = service?.characteristics
          .where((c) => c.uuid == rxCharacteristicUuid)
          .firstOrNull;
      final tx = service?.characteristics
          .where((c) => c.uuid == txCharacteristicUuid)
          .firstOrNull;
      if (_rx == null || tx == null) {
        throw const BleConnectException(
          Esp32BleBridgeFailure.connectionFailed,
          'El equipo respondió pero no es un puente BoviSense actualizado. '
          'Verifica el firmware del equipo.',
        );
      }
      _event('Servicio BLE descubierto', direction: 'BLE');
      _notifications = tx.onValueReceived.listen(
        _receive,
        onError: (Object error) {
          unawaited(disconnect());
        },
      );
      await tx.setNotifyValue(true).timeout(const Duration(seconds: 5));
      if (!_current(generation)) return;
      _connection = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            _current(generation)) {
          unawaited(disconnect());
        }
      });
      if (!device.isConnected) {
        throw Exception('Se perdio la conexion Bluetooth.');
      }
      _setState(Esp32BleBridgeState.connected);
      _event('Puente conectado');
    } catch (error) {
      if (_current(generation)) {
        await _release();
        final failure = _failureFor(error);
        _failure = failure;
        _errorMessage = error is BleConnectException
            ? error.message
            : failureMessage(failure);
        _setState(_stateForFailure(failure));
        _event(_errorMessage!, direction: 'ERROR');
      }
    }
  }

  static Esp32BleBridgeFailure _failureFor(Object error) {
    if (error is BleConnectException) return error.failure;
    if (error is TimeoutException) {
      return Esp32BleBridgeFailure.bluetoothUnavailable;
    }
    return Esp32BleBridgeFailure.connectionFailed;
  }

  static Esp32BleBridgeState _stateForFailure(Esp32BleBridgeFailure failure) {
    switch (failure) {
      case Esp32BleBridgeFailure.bluetoothOff:
        return Esp32BleBridgeState.adapterOff;
      case Esp32BleBridgeFailure.permissionDenied:
        return Esp32BleBridgeState.permissionDenied;
      case Esp32BleBridgeFailure.none:
      case Esp32BleBridgeFailure.bluetoothUnavailable:
      case Esp32BleBridgeFailure.deviceNotFound:
      case Esp32BleBridgeFailure.bluetoothBusy:
      case Esp32BleBridgeFailure.connectionFailed:
        return Esp32BleBridgeState.error;
    }
  }

  Future<void> _ensureBluetoothPermissions() async {
    if (!Platform.isAndroid) return;
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final scanOk = permissions[Permission.bluetoothScan]?.isGranted == true;
    final connectOk =
        permissions[Permission.bluetoothConnect]?.isGranted == true;
    final locationOk =
        permissions[Permission.locationWhenInUse]?.isGranted == true;
    if (scanOk && connectOk) return;
    if (locationOk) return;
    throw BleConnectException(
      Esp32BleBridgeFailure.permissionDenied,
      failureMessage(Esp32BleBridgeFailure.permissionDenied),
    );
  }

  /// Exige Bluetooth encendido. Si esta apagandose o encendiendose espera un
  /// momento antes de darse por vencido.
  Future<void> _ensureBluetoothOn() async {
    var state = FlutterBluePlus.adapterStateNow;
    if (state == BluetoothAdapterState.unknown) {
      state = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 8), onTimeout: () => state);
    }

    if (state == BluetoothAdapterState.turningOn ||
        state == BluetoothAdapterState.turningOff) {
      state = await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () => state);
    }

    final failure = failureForAdapterState(state);
    if (failure == Esp32BleBridgeFailure.none) return;
    throw BleConnectException(failure, failureMessage(failure));
  }

  /// Pide al sistema activar el Bluetooth (Android muestra su propio aviso).
  Future<bool> requestBluetoothEnable() async {
    if (disposed || !Platform.isAndroid) return false;
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
      return true;
    }
    try {
      await FlutterBluePlus.turnOn();
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    } catch (_) {
      _event(
        'No se pudo activar el Bluetooth automaticamente',
        direction: 'ERROR',
      );
      return false;
    }
  }

  /// Dispositivos que el telefono tiene conectados (audifonos, parlantes...).
  Future<List<String>> _systemBluetoothDevices() async {
    if (!Platform.isAndroid) return const [];
    final names = <String>[];

    // Perfiles de audio clasicos (audifonos, parlantes, manos libres): el
    // plugin BLE no los ve porque solo expone conexiones GATT.
    try {
      final devices = await FlutterBluePlus.systemDevices(const []);
      for (final device in devices) {
        final name = device.platformName.trim().isEmpty
            ? device.remoteId.str
            : device.platformName.trim();
        if (name.isNotEmpty && !names.contains(name)) names.add(name);
      }
    } catch (_) {
      // Sin permiso o sin soporte: seguimos con el canal nativo.
    }

    try {
      final audio = await _bluetoothChannel.invokeMethod<List<dynamic>>(
        'connectedAudioDeviceNames',
      );
      for (final item in audio ?? const []) {
        final name = item.toString().trim();
        if (name.isNotEmpty && !names.contains(name)) names.add(name);
      }
    } on PlatformException {
      // Canal no disponible (por ejemplo, otra plataforma).
    } on MissingPluginException {
      // Version antigua de la app sin el canal nativo.
    }

    return names;
  }

  static const _bluetoothChannel = MethodChannel('bovisense/bluetooth');

  /// Mantiene al dia el estado del adaptador: avisa cuando el Bluetooth esta
  /// apagado (o el usuario lo apaga en medio de una conexion) y se recupera
  /// solo cuando vuelve a encenderse.
  void _watchAdapter() {
    if (_adapterWatch != null) return;
    try {
      _adapterWatch = FlutterBluePlus.adapterState.listen(
        _onAdapterStateChanged,
        onError: (Object _) {
          // Plataforma sin Bluetooth disponible: se avisa al intentar conectar.
        },
      );
    } catch (_) {
      _adapterWatch = null;
    }
  }

  void _onAdapterStateChanged(BluetoothAdapterState state) {
    if (disposed) return;
    if (state == BluetoothAdapterState.on) {
      if (_state == Esp32BleBridgeState.adapterOff) {
        _failure = Esp32BleBridgeFailure.none;
        _errorMessage = null;
        _setState(Esp32BleBridgeState.idle);
      }
      return;
    }
    if (state != BluetoothAdapterState.off &&
        state != BluetoothAdapterState.turningOff) {
      return;
    }
    if (_state == Esp32BleBridgeState.adapterOff) return;
    final active =
        _state == Esp32BleBridgeState.connected ||
        _state == Esp32BleBridgeState.scanning ||
        _state == Esp32BleBridgeState.connecting;
    _failure = Esp32BleBridgeFailure.bluetoothOff;
    _errorMessage = failureMessage(Esp32BleBridgeFailure.bluetoothOff);
    if (active) unawaited(_release());
    _setState(Esp32BleBridgeState.adapterOff);
  }

  void _receive(List<int> bytes) {
    if (disposed) return;
    for (final byte in bytes) {
      if (byte == 126) {
        _buffer = '';
        _receiving = true;
      } else if (byte == 10 && _receiving) {
        final frame = _buffer;
        _buffer = '';
        _receiving = false;
        final parts = frame.split('|');
        if (parts.length == 8 &&
            parts[0] == 'R1' &&
            parts[1] == _requestId &&
            _reply != null &&
            !_reply!.isCompleted) {
          _event(
            'R1 recibido id=${_shortId(parts[1])} estado=${parts[3]}',
            direction: 'BLE RX',
          );
          _reply!.complete(frame);
        } else if (parts.isNotEmpty && parts.first == 'R1') {
          _event(
            'R1 ignorado id=${parts.length > 1 ? _shortId(parts[1]) : '-'}',
            direction: 'BLE RX',
          );
        } else if (parts.length >= 4 &&
            parts[0] == 'B0' &&
            parts[1] == _requestId &&
            _reply != null &&
            !_reply!.isCompleted) {
          final reason = parts.sublist(3).join('|');
          _event('Puente reporto error: $reason', direction: 'BLE RX');
          _reply!.complete(frame);
        }
      } else if (_receiving &&
          byte >= 32 &&
          byte <= 126 &&
          _buffer.length < 200) {
        _buffer += String.fromCharCode(byte);
      } else {
        _receiving = false;
        _buffer = '';
      }
    }
  }

  /// Encola un comando hacia el equipo.
  ///
  /// Encolar en vez de rechazar evita que el sondeo automatico (que dura
  /// varios segundos) bloquee "Detener" o "Actualizar conteo".
  Future<void> sendCommand(String command) {
    return _commands.add(() => _sendCommand(command));
  }

  Future<void> _sendCommand(String command) async {
    if (disposed || !isConnected || _rx == null) {
      throw Exception('Conecta primero el puente BLE.');
    }
    if (_sending) throw Exception('Espera la respuesta del equipo.');
    _errorMessage = null;
    _sending = true;
    notifyListeners();
    final generation = _generation;
    try {
      _event(
        'Solicitando ticket: $command -> ${_repository.apiBaseOrigin}',
        direction: 'API',
      );
      final ticket = await _repository.issueCommand(command, newRequestId());
      if (!_current(generation) || !isConnected) {
        throw Exception('Conexion interrumpida.');
      }
      _requestId = ticket['request_id'] as String;
      _event(
        'Ticket listo cmd=${ticket['command']} id=${_shortId(_requestId)} session=${_shortId(ticket['session_id'] as String?)}',
        direction: 'API',
      );
      _reply = Completer<String>();
      // Attach the timeout before writing so disconnects never produce unhandled futures.
      final response = _reply!.future.timeout(const Duration(seconds: 25));
      final payload = ascii.encode('~${ticket['frame']}\n');
      try {
        for (var offset = 0; offset < payload.length; offset += 18) {
          if (!_current(generation) || _rx == null) {
            throw Exception('Conexion interrumpida.');
          }
          await _rx!.write(
            payload.sublist(offset, (offset + 18).clamp(0, payload.length)),
            withoutResponse: false,
          );
        }
        _event(
          'Comando enviado al ESP32 (${payload.length} bytes)',
          direction: 'BLE TX',
        );
      } catch (_) {
        _event('No se pudo escribir el comando por BLE', direction: 'ERROR');
        if (!_reply!.isCompleted) _reply!.complete('');
      }
      _event('Esperando respuesta R1 de Jetson', direction: 'LoRa');
      final frame = await response;
      if (frame.isEmpty) {
        throw Exception(
          'Conexion interrumpida. Consulta el estado al reconectar.',
        );
      }
      if (frame.startsWith('B0|')) {
        throw Exception(_bridgeErrorMessage(frame));
      }
      _event('Verificando R1 con backend', direction: 'API');
      final verified = await _repository.verifyResponse(frame);
      if (!_current(generation)) return;
      final fields = verified.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      if (verified['proof'] == null) fields.remove('proof');
      if (command == 'ESTADO') {
        _latestJetsonStatus = JetsonStatusSnapshot(
          fields: {'hostname': fields['device_id'] ?? 'Jetson'},
          receivedAt: DateTime.now(),
          rawMessage: '',
        );
        // El receptor informa que no tiene sesion de conteo: cualquier
        // instantanea anterior quedo obsoleta. Se conserva solo si es un
        // resultado final que el usuario todavia puede guardar.
        if (fields['status'] == 'IDLE' &&
            _latestCountStatus?.finalResult != true) {
          _latestCountStatus = null;
        }
      } else {
        _latestCountStatus = JetsonCountSnapshot(
          fields: fields,
          receivedAt: DateTime.now(),
          rawMessage: '',
        );
        _scheduleCountPoll();
      }
      _event('Respuesta verificada: ${fields['status']}');
      if (fields['status'] == 'ERROR' || fields['status'] == 'BUSY') {
        throw Exception(
          'El equipo no pudo ejecutar el comando. Consulta su estado.',
        );
      }
    } on TimeoutException {
      _event('Timeout esperando R1 de Jetson', direction: 'ERROR');
      throw Exception(
        'El prototipo no respondio. Consulta el estado antes de repetir.',
      );
    } catch (error) {
      if (sessionCommands.contains(command) && isStaleSessionError(error)) {
        _event(
          'La sesion ya no existe en el equipo; inicia un conteo nuevo.',
          direction: 'STATUS',
        );
        if (_latestCountStatus?.finalResult != true) {
          _latestCountStatus = null;
          _errorMessage = null;
        }
        return;
      }
      final message = _commandFailureMessage(error);
      _event(message, direction: 'ERROR');
      throw Exception(message);
    } finally {
      _reply = null;
      _requestId = null;
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> prepareCounting() => sendCommand('PREPARARCONTEO');
  Future<void> startCounting() => sendCommand('INICIARCONTEO');
  Future<void> stopCounting() => sendCommand('DETENERCONTEO');
  Future<void> requestCountingStatus() => sendCommand('ESTADOCONTEO');
  Future<void> requestCountingResult() => sendCommand('RESULTADOCONTEO');

  String _commandFailureMessage(Object error) {
    if (error is ApiException) {
      if (error.isNotFound && error.path.startsWith('/api/ganadero/iot/')) {
        return 'Ruta IoT no encontrada en ${_repository.apiBaseOrigin}. El backend desplegado no tiene /api/ganadero/iot/comandos o la app apunta a un deployment anterior.';
      }
      return 'API ${error.statusCode}: ${error.message}';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _bridgeErrorMessage(String frame) {
    final parts = frame.split('|');
    final reason = parts.length >= 4 ? parts.sublist(3).join('|') : '';
    switch (reason) {
      case 'lora_not_ready':
        return 'El puente BLE esta conectado, pero LoRa aun no esta listo.';
      case 'empty_lora_payload':
        return 'El puente recibio un comando vacio.';
      case 'lora_payload_too_long':
        return 'El comando supera el tamano permitido por LoRa.';
      case 'lora_send_failed':
        return 'El puente no pudo enviar el comando por LoRa.';
      case 'bridge_busy_waiting_lora':
        return 'El puente esta esperando una respuesta anterior de Jetson.';
      case 'jetson_response_timeout':
        return 'El puente envio el comando, pero Jetson no respondio por LoRa.';
      default:
        return 'El puente reporto un error de comunicacion LoRa.';
    }
  }

  void _event(String message, {String direction = 'STATUS'}) {
    _events.insert(
      0,
      Esp32BleBridgeEvent(
        message: message,
        createdAt: DateTime.now(),
        direction: direction,
      ),
    );
    if (_events.length > 30) _events.removeLast();
    notifyListeners();
  }

  Future<void> _release() async {
    _poll?.cancel();
    _poll = null;
    _pollFailures = 0;
    if (_reply != null && !_reply!.isCompleted) _reply!.complete('');
    if (_found != null && !_found!.isCompleted) _found!.complete(null);
    final scan = _scan;
    _scan = null;
    final connection = _connection;
    _connection = null;
    final notifications = _notifications;
    _notifications = null;
    final device = _device;
    _device = null;
    _rx = null;
    _buffer = '';
    _receiving = false;
    await scan?.cancel();
    await connection?.cancel();
    await notifications?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      /* Adapter may be unavailable. */
    }
    try {
      await device?.disconnect();
    } catch (_) {
      /* Already disconnected. */
    }
  }

  Future<void> disconnect() async {
    ++_generation;
    _latestCountStatus = null;
    _latestJetsonStatus = null;
    _setState(Esp32BleBridgeState.disconnected);
    await _release();
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
    unawaited(_adapterWatch?.cancel() ?? Future<void>.value());
    unawaited(_release());
  }
}
