import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  String get detail => fields['detail'] ?? 'Sin detalle';
  bool get started => status == 'STARTED' || status == 'RUNNING';
  bool get running => status == 'STARTED' || status == 'RUNNING';
  bool get finalResult => status == 'STOPPED' || status == 'RESULT';
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

class Esp32BleBridgeService extends ChangeNotifier {
  static const String deviceName = 'BoviSense-Bridge';
  static final Guid serviceUuid = Guid('7d2f0001-1f3b-4a9b-8f2a-b05e00000001');
  static final Guid rxCharacteristicUuid = Guid(
    '7d2f0002-1f3b-4a9b-8f2a-b05e00000001',
  );
  static final Guid txCharacteristicUuid = Guid(
    '7d2f0003-1f3b-4a9b-8f2a-b05e00000001',
  );

  Esp32BleBridgeState _state = Esp32BleBridgeState.idle;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  String? _errorMessage;
  final Set<String> _loggedScanResults = {};
  int _scanResultBursts = 0;
  bool _useFineLocationForScan = false;
  final List<Esp32BleBridgeEvent> _events = [];
  JetsonStatusSnapshot? _latestJetsonStatus;
  JetsonCountSnapshot? _latestCountStatus;

  Esp32BleBridgeState get state => _state;
  BluetoothDevice? get device => _device;
  String? get errorMessage => _errorMessage;
  List<Esp32BleBridgeEvent> get events => List.unmodifiable(_events);
  JetsonStatusSnapshot? get latestJetsonStatus => _latestJetsonStatus;
  JetsonCountSnapshot? get latestCountStatus => _latestCountStatus;
  bool get isConnected => _state == Esp32BleBridgeState.connected;
  bool get isBusy =>
      _state == Esp32BleBridgeState.scanning ||
      _state == Esp32BleBridgeState.connecting;
  String get deviceLabel {
    final device = _device;
    if (device == null) {
      return deviceName;
    }
    final name = device.platformName.isEmpty ? deviceName : device.platformName;
    return '$name (${device.remoteId.str})';
  }

  Future<void> scanAndConnect() async {
    if (isBusy) {
      return;
    }

    _errorMessage = null;
    _loggedScanResults.clear();
    _scanResultBursts = 0;
    _setState(Esp32BleBridgeState.scanning);
    _addEvent('Buscando $deviceName por BLE', 'STATUS');

    final permissionsOk = await _requestPermissions();
    if (!permissionsOk) {
      _errorMessage = 'Permisos BLE/ubicacion denegados.';
      _setState(Esp32BleBridgeState.permissionDenied);
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _errorMessage = 'Bluetooth está apagado.';
      _setState(Esp32BleBridgeState.adapterOff);
      return;
    }

    await _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: (Object error) {
        _errorMessage = 'Error escaneando BLE: $error';
        _setState(Esp32BleBridgeState.error);
      },
    );

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: _useFineLocationForScan,
        // On some Android OEMs BLE scan returns 0 results if system location is off.
        androidCheckLocationServices: true,
      );
      await Future<void>.delayed(const Duration(seconds: 15));
      if (_state == Esp32BleBridgeState.scanning) {
        if (_scanResultBursts == 0) {
          _errorMessage =
              'Escaneo BLE sin resultados. Verifica ubicacion del sistema y que el ESP32 este anunciando BLE.';
        } else {
          _errorMessage = 'No se encontró $deviceName.';
        }
        _setState(Esp32BleBridgeState.disconnected);
      }
    } catch (e) {
      _errorMessage = 'No se pudo iniciar escaneo BLE: $e';
      _setState(Esp32BleBridgeState.error);
    }
  }

  Future<void> disconnect() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;

    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // El dispositivo puede estar ya desconectado.
      }
    }

    _addEvent('BLE desconectado', 'STATUS');
    _setState(Esp32BleBridgeState.disconnected);
  }

  Future<void> sendCommand(String command) async {
    final cleanCommand = command.trim();
    if (cleanCommand.isEmpty) {
      throw Exception('El comando no puede estar vacío.');
    }
    if (!isConnected || _rxCharacteristic == null) {
      throw Exception('Conecta primero el puente BLE.');
    }

    final payload = cleanCommand.startsWith('CMD:')
        ? cleanCommand
        : 'CMD:$cleanCommand';

    await _rxCharacteristic!.write(
      utf8.encode(payload),
      withoutResponse: false,
    );
    _addEvent(payload, 'APP_TX');
  }

  Future<void> prepareCounting() => sendCommand('PREPARARCONTEO');

  Future<void> startCounting() => sendCommand('INICIARCONTEO');

  Future<void> stopCounting() => sendCommand('DETENERCONTEO');

  Future<void> requestCountingStatus() => sendCommand('ESTADOCONTEO');

  Future<void> requestCountingResult() => sendCommand('RESULTADOCONTEO');

  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    if (scanOk && connectOk) {
      _useFineLocationForScan = false;
      return true;
    }

    final locationOk =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;
    if (locationOk) {
      _useFineLocationForScan = true;
      return true;
    }

    _useFineLocationForScan = false;
    return false;
  }

  void _handleScanResults(List<ScanResult> results) {
    if (_state != Esp32BleBridgeState.scanning) {
      return;
    }
    if (results.isNotEmpty) {
      _scanResultBursts++;
    }

    for (final result in results) {
      _logScanResult(result);

      final advertisedName = result.advertisementData.advName
          .trim()
          .toLowerCase();
      final platformName = result.device.platformName.trim().toLowerCase();

      final matchesService = result.advertisementData.serviceUuids.any(
        (uuid) => uuid.str128.toLowerCase() == serviceUuid.str128.toLowerCase(),
      );
      final expectedName = deviceName.toLowerCase();
      final matchesName =
          advertisedName.contains('bovisense') ||
          platformName.contains('bovisense') ||
          advertisedName == expectedName ||
          platformName == expectedName;

      if (matchesService || matchesName) {
        unawaited(_connectToDevice(result.device));
        return;
      }
    }
  }

  void _logScanResult(ScanResult result) {
    final advertisedName = result.advertisementData.advName;
    final platformName = result.device.platformName;
    final serviceUuids = result.advertisementData.serviceUuids
        .map((uuid) => uuid.str128)
        .join(',');
    final hasUsefulData =
        advertisedName.isNotEmpty ||
        platformName.isNotEmpty ||
        serviceUuids.isNotEmpty;

    if (!hasUsefulData) {
      return;
    }

    final key =
        '${result.device.remoteId.str}|$advertisedName|$platformName|$serviceUuids';
    if (!_loggedScanResults.add(key)) {
      return;
    }

    debugPrint(
      'ESP32 BLE SCAN <- id=${result.device.remoteId.str} '
      'name=$platformName adv=$advertisedName rssi=${result.rssi} '
      'services=[$serviceUuids]',
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_state != Esp32BleBridgeState.scanning) {
      return;
    }

    _setState(Esp32BleBridgeState.connecting);
    _device = device;
    _addEvent('Conectando a ${device.remoteId.str}', 'STATUS');

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      await device.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (!message.contains('already') && !message.contains('connected')) {
        _errorMessage = 'No se pudo conectar por BLE: $e';
        _setState(Esp32BleBridgeState.error);
        return;
      }
    }

    if (Platform.isAndroid) {
      try {
        await device.requestMtu(247);
      } catch (_) {
        // Algunos telefonos negocian el MTU automaticamente o no permiten cambiarlo.
      }
    }

    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected &&
          _state == Esp32BleBridgeState.connected) {
        _rxCharacteristic = null;
        _txCharacteristic = null;
        _addEvent('BLE desconectado', 'STATUS');
        _setState(Esp32BleBridgeState.disconnected);
      }
    });

    final services = await device.discoverServices();
    final bridgeService = services
        .where((service) => service.uuid == serviceUuid)
        .firstOrNull;
    if (bridgeService == null) {
      _errorMessage = 'El dispositivo no expone el servicio BoviSense.';
      _setState(Esp32BleBridgeState.error);
      return;
    }

    for (final characteristic in bridgeService.characteristics) {
      if (characteristic.uuid == rxCharacteristicUuid) {
        _rxCharacteristic = characteristic;
      } else if (characteristic.uuid == txCharacteristicUuid) {
        _txCharacteristic = characteristic;
      }
    }

    if (_rxCharacteristic == null || _txCharacteristic == null) {
      _errorMessage = 'No se encontraron las characteristics RX/TX.';
      _setState(Esp32BleBridgeState.error);
      return;
    }

    _notificationSubscription = _txCharacteristic!.onValueReceived.listen((
      value,
    ) {
      final message = utf8.decode(value, allowMalformed: true).trim();
      if (message.isNotEmpty) {
        _handleBridgeNotification(message);
      }
    });
    await _txCharacteristic!.setNotifyValue(true);

    _errorMessage = null;
    _addEvent('Conectado a $deviceName', 'STATUS');
    _setState(Esp32BleBridgeState.connected);
  }

  void _handleBridgeNotification(String message) {
    if (message.startsWith('JETSON_STATUS:')) {
      final rawStatus = message.substring('JETSON_STATUS:'.length);
      _latestJetsonStatus = JetsonStatusSnapshot(
        fields: _parseStatusFields(rawStatus),
        receivedAt: DateTime.now(),
        rawMessage: rawStatus,
      );
    } else if (message.startsWith('JETSON_COUNT:')) {
      final rawStatus = message.substring('JETSON_COUNT:'.length);
      _latestCountStatus = JetsonCountSnapshot(
        fields: _parseStatusFields(rawStatus),
        receivedAt: DateTime.now(),
        rawMessage: rawStatus,
      );
    }

    _addEvent(message, 'ESP_RX');
  }

  Map<String, String> _parseStatusFields(String rawStatus) {
    final fields = <String, String>{};
    for (final segment in rawStatus.split('|')) {
      final separatorIndex = segment.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final key = segment.substring(0, separatorIndex).trim();
      final value = segment.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        fields[key] = value;
      }
    }
    if (fields.containsKey('h') && !fields.containsKey('hostname')) {
      fields['hostname'] = fields['h']!;
    }
    return fields;
  }

  void _addEvent(String message, String direction) {
    _events.insert(
      0,
      Esp32BleBridgeEvent(
        message: message,
        createdAt: DateTime.now(),
        direction: direction,
      ),
    );
    if (_events.length > 30) {
      _events.removeRange(30, _events.length);
    }
    debugPrint('ESP32 BLE $direction -> $message');
    notifyListeners();
  }

  void _setState(Esp32BleBridgeState nextState) {
    if (_state == nextState) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _device?.disconnect();
    super.dispose();
  }
}
