import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

enum Esp8266DiscoveryState { notStarted, listening, found, offline, error }

class Esp8266DiscoveredDevice {
  const Esp8266DiscoveredDevice({
    required this.device,
    required this.id,
    required this.ip,
    required this.port,
    required this.baseUrl,
    required this.lastSeen,
    required this.sourceAddress,
  });

  final String device;
  final String id;
  final String ip;
  final int port;
  final String baseUrl;
  final DateTime lastSeen;
  final String sourceAddress;

  Esp8266DiscoveredDevice copyWith({
    String? device,
    String? id,
    String? ip,
    int? port,
    String? baseUrl,
    DateTime? lastSeen,
    String? sourceAddress,
  }) {
    return Esp8266DiscoveredDevice(
      device: device ?? this.device,
      id: id ?? this.id,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      baseUrl: baseUrl ?? this.baseUrl,
      lastSeen: lastSeen ?? this.lastSeen,
      sourceAddress: sourceAddress ?? this.sourceAddress,
    );
  }
}

class Esp8266DiscoveryService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _presenceTimer;
  Timer? _discoveryRequestTimer;
  Esp8266DiscoveredDevice? _device;
  Esp8266DiscoveryState _state = Esp8266DiscoveryState.notStarted;
  String? _errorMessage;
  bool _isHttpScanning = false;
  DateTime? _lastHttpScan;

  Esp8266DiscoveryState get state => _state;
  Esp8266DiscoveredDevice? get device => _device;
  String? get errorMessage => _errorMessage;
  String? get baseUrl => isAvailable ? _device?.baseUrl : null;
  bool get isAvailable => _state == Esp8266DiscoveryState.found;
  bool get isListening =>
      _state == Esp8266DiscoveryState.listening ||
      _state == Esp8266DiscoveryState.found ||
      _state == Esp8266DiscoveryState.offline;

  Future<void> start() async {
    if (_socket != null) {
      return;
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConfig.esp8266DiscoveryPort,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      _subscription = _socket!.listen(_handleSocketEvent);
      _presenceTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _markOfflineIfExpired(),
      );
      _discoveryRequestTimer = Timer.periodic(
        AppConfig.esp8266DiscoveryRequestInterval,
        (_) => _sendDiscoveryRequest(),
      );
      _setState(Esp8266DiscoveryState.listening);
      debugPrint(
        'ESP8266 DISCOVERY -> listening UDP ${AppConfig.esp8266DiscoveryPort}',
      );
      unawaited(_sendDiscoveryRequest());
      unawaited(_scanLocalSubnetsIfNeeded(force: true));
    } catch (e) {
      _errorMessage = 'No se pudo iniciar descubrimiento UDP: $e';
      _setState(Esp8266DiscoveryState.error);
      debugPrint('ESP8266 DISCOVERY ERROR -> $_errorMessage');
    }
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> requestNow() {
    return _requestDiscoveryNow();
  }

  Future<void> _requestDiscoveryNow() async {
    await _sendDiscoveryRequest();
    await _scanLocalSubnetsIfNeeded(force: true);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _discoveryRequestTimer?.cancel();
    _discoveryRequestTimer = null;
    _socket?.close();
    _socket = null;
    _setState(Esp8266DiscoveryState.notStarted);
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    Datagram? datagram;
    while ((datagram = _socket?.receive()) != null) {
      _handleDatagram(datagram!);
    }
  }

  Future<void> _sendDiscoveryRequest() async {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    final payload = utf8.encode(AppConfig.esp8266DiscoveryRequest);
    final targets = <InternetAddress>{
      InternetAddress('255.255.255.255'),
      ...await _localSubnetBroadcastTargets(),
    };

    for (final target in targets) {
      try {
        socket.send(payload, target, AppConfig.esp8266DiscoveryPort);
      } catch (e) {
        debugPrint('ESP8266 DISCOVERY request failed -> $target $e');
      }
    }

    debugPrint(
      'ESP8266 DISCOVERY request sent -> ${targets.map((e) => e.address).join(', ')}',
    );

    unawaited(_scanLocalSubnetsIfNeeded());
  }

  Future<List<InternetAddress>> _localSubnetBroadcastTargets() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final targets = <InternetAddress>[];
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final parts = address.address.split('.');
          if (parts.length != 4) {
            continue;
          }
          targets.add(
            InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'),
          );
        }
      }
      return targets;
    } catch (e) {
      debugPrint('ESP8266 DISCOVERY interfaces failed -> $e');
      return const [];
    }
  }

  void _handleDatagram(Datagram datagram) {
    final message = utf8.decode(datagram.data, allowMalformed: true).trim();
    if (message == AppConfig.esp8266DiscoveryRequest) {
      return;
    }

    final parsed = _parseDiscoveryMessage(message);
    if (parsed == null) {
      debugPrint('ESP8266 DISCOVERY ignored <- $message');
      return;
    }

    final ip = parsed['ip'];
    final port = int.tryParse(parsed['port'] ?? '');
    if (ip == null || port == null || port <= 0 || port > 65535) {
      debugPrint('ESP8266 DISCOVERY malformed <- $message');
      return;
    }

    final address = InternetAddress.tryParse(ip);
    if (address == null || address.type != InternetAddressType.IPv4) {
      debugPrint('ESP8266 DISCOVERY invalid ip <- $message');
      return;
    }

    _registerDiscoveredDevice(
      device: parsed['device']!,
      id: parsed['id']!,
      ip: ip,
      port: port,
      sourceAddress: datagram.address.address,
      source: 'udp',
    );
  }

  void _registerDiscoveredDevice({
    required String device,
    required String id,
    required String ip,
    required int port,
    required String sourceAddress,
    required String source,
  }) {
    final baseUrl = port == 80 ? 'http://$ip' : 'http://$ip:$port';
    final nextDevice = Esp8266DiscoveredDevice(
      device: device,
      id: id,
      ip: ip,
      port: port,
      baseUrl: baseUrl,
      lastSeen: DateTime.now(),
      sourceAddress: sourceAddress,
    );

    final changed =
        _device?.ip != nextDevice.ip ||
        _device?.port != nextDevice.port ||
        _device?.id != nextDevice.id ||
        _state != Esp8266DiscoveryState.found;

    _device = nextDevice;
    _errorMessage = null;
    _state = Esp8266DiscoveryState.found;

    if (changed) {
      debugPrint('ESP8266 DISCOVERY found ($source) -> $baseUrl');
    }
    notifyListeners();
  }

  Future<void> _scanLocalSubnetsIfNeeded({bool force = false}) async {
    if (_isHttpScanning) {
      return;
    }
    if (!force && _lastHttpScan != null) {
      final elapsed = DateTime.now().difference(_lastHttpScan!);
      if (elapsed < AppConfig.esp8266HttpScanInterval) {
        return;
      }
    }

    _isHttpScanning = true;
    _lastHttpScan = DateTime.now();
    try {
      await _scanLocalSubnets();
    } finally {
      _isHttpScanning = false;
    }
  }

  Future<void> _scanLocalSubnets() async {
    final prefixes = await _localIpv4Prefixes();
    if (prefixes.isEmpty) {
      debugPrint('ESP8266 HTTP scan -> no local IPv4 prefixes');
      return;
    }

    debugPrint('ESP8266 HTTP scan prefixes -> ${prefixes.join(', ')}');
    for (final prefix in prefixes) {
      for (
        var start = 1;
        start <= 254;
        start += AppConfig.esp8266HttpScanBatchSize
      ) {
        if (_state == Esp8266DiscoveryState.found) {
          return;
        }

        final end = (start + AppConfig.esp8266HttpScanBatchSize - 1)
            .clamp(1, 254)
            .toInt();
        final checks = <Future<bool>>[];
        for (var host = start; host <= end; host++) {
          checks.add(_checkHttpCandidate('$prefix.$host'));
        }
        final results = await Future.wait(checks);
        if (results.any((found) => found)) {
          return;
        }
      }
    }
  }

  Future<List<String>> _localIpv4Prefixes() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final prefixes = <String>{};
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final parts = address.address.split('.');
          if (parts.length != 4 || !_isPrivateIpv4(parts)) {
            continue;
          }
          prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
      return prefixes.toList()..sort();
    } catch (e) {
      debugPrint('ESP8266 HTTP scan interfaces failed -> $e');
      return const [];
    }
  }

  bool _isPrivateIpv4(List<String> parts) {
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    if (first == null || second == null) {
      return false;
    }
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  Future<bool> _checkHttpCandidate(String ip) async {
    final uri = Uri.parse('http://$ip/status');
    try {
      final response = await http
          .get(uri)
          .timeout(AppConfig.esp8266HttpScanTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final device = decoded['device']?.toString();
      final id = decoded['id']?.toString();
      final mode = decoded['mode']?.toString();

      if (device != AppConfig.esp8266ExpectedDevice) {
        debugPrint('ESP8266 HTTP scan rejected $ip -> device=$device');
        return false;
      }

      final hasExpectedId = id == AppConfig.esp8266ExpectedId;
      final hasCompatibleMode =
          id == null && mode == AppConfig.esp8266ExpectedMode;
      if (!hasExpectedId && !hasCompatibleMode) {
        debugPrint('ESP8266 HTTP scan rejected $ip -> id=$id mode=$mode');
        return false;
      }

      _registerDiscoveredDevice(
        device: device!,
        id: id ?? AppConfig.esp8266ExpectedId,
        ip: ip,
        port: 80,
        sourceAddress: ip,
        source: 'http-scan',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String>? _parseDiscoveryMessage(String message) {
    final parts = message.split('|');
    if (parts.isEmpty || parts.first != AppConfig.esp8266DiscoveryPrefix) {
      return null;
    }

    final data = <String, String>{};
    for (final part in parts.skip(1)) {
      final separatorIndex = part.indexOf('=');
      if (separatorIndex <= 0 || separatorIndex == part.length - 1) {
        return null;
      }
      data[part.substring(0, separatorIndex)] = part.substring(
        separatorIndex + 1,
      );
    }

    if (data['device'] != AppConfig.esp8266ExpectedDevice ||
        data['id'] != AppConfig.esp8266ExpectedId) {
      return null;
    }

    return data;
  }

  void _markOfflineIfExpired() {
    final device = _device;
    if (device == null || _state != Esp8266DiscoveryState.found) {
      return;
    }

    final elapsed = DateTime.now().difference(device.lastSeen);
    if (elapsed <= AppConfig.esp8266PresenceTimeout) {
      return;
    }

    _setState(Esp8266DiscoveryState.offline);
    debugPrint('ESP8266 DISCOVERY offline -> ${device.baseUrl}');
  }

  void _setState(Esp8266DiscoveryState nextState) {
    if (_state == nextState) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _discoveryRequestTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    super.dispose();
  }
}
