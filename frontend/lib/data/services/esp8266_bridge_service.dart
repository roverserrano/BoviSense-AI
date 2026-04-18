import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Esp8266BridgeStatus {
  const Esp8266BridgeStatus({
    required this.device,
    required this.mode,
    required this.ssid,
    required this.ip,
    required this.wifiConnected,
    required this.wifiRssi,
    required this.loraReady,
    required this.localAddress,
    required this.remoteAddress,
    required this.tx,
    required this.rx,
    required this.lastRxMessage,
    required this.lastRxSender,
    required this.lastRxRssi,
    required this.lastRxSnr,
  });

  final String device;
  final String mode;
  final String ssid;
  final String ip;
  final bool wifiConnected;
  final int wifiRssi;
  final bool loraReady;
  final String localAddress;
  final String remoteAddress;
  final int tx;
  final int rx;
  final String lastRxMessage;
  final String lastRxSender;
  final int lastRxRssi;
  final double lastRxSnr;

  factory Esp8266BridgeStatus.fromJson(Map<String, dynamic> json) {
    return Esp8266BridgeStatus(
      device: (json['device'] ?? '').toString(),
      mode: (json['mode'] ?? '').toString(),
      ssid: (json['ssid'] ?? '').toString(),
      ip: (json['ip'] ?? '').toString(),
      wifiConnected: json['wifiConnected'] == true,
      wifiRssi: _toInt(json['wifiRssi']),
      loraReady: json['loraReady'] == true,
      localAddress: (json['localAddress'] ?? '').toString(),
      remoteAddress: (json['remoteAddress'] ?? '').toString(),
      tx: _toInt(json['tx']),
      rx: _toInt(json['rx']),
      lastRxMessage: (json['lastRxMessage'] ?? '').toString(),
      lastRxSender: (json['lastRxSender'] ?? '').toString(),
      lastRxRssi: _toInt(json['lastRxRssi']),
      lastRxSnr: _toDouble(json['lastRxSnr']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class Esp8266BridgeService {
  Esp8266BridgeService({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final cleanBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$cleanBase$cleanPath',
    ).replace(queryParameters: queryParameters);
  }

  Future<bool> ping() async {
    final response = await _client
        .get(_uri('/ping'))
        .timeout(const Duration(seconds: 4));

    debugPrint('ESP8266 PING -> ${response.statusCode} ${response.body}');
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<Esp8266BridgeStatus> status() async {
    final response = await _client
        .get(_uri('/status'))
        .timeout(const Duration(seconds: 4));

    debugPrint('ESP8266 STATUS -> ${response.statusCode} ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del ESP8266');
    }

    return Esp8266BridgeStatus.fromJson(decoded);
  }

  Future<void> sendLoraMessage(String message) async {
    final response = await _client
        .get(_uri('/send', {'msg': message}))
        .timeout(const Duration(seconds: 4));

    debugPrint('ESP8266 SEND -> ${response.statusCode} ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo encolar el mensaje LoRa');
    }
  }

  void close() {
    _client.close();
  }
}
