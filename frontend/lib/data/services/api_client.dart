import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(
    this.message, {
    required this.statusCode,
    required this.path,
  });

  final String message;
  final int statusCode;
  final String path;

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required FirebaseAuth auth,
    required String baseUrl,
    http.Client? client,
  }) : this.withProviders(
         tokenProvider: () async => auth.currentUser?.getIdToken(),
         uidProvider: () => auth.currentUser?.uid,
         baseUrl: baseUrl,
         client: client,
       );

  ApiClient.withProviders({
    required Future<String?> Function() tokenProvider,
    required String? Function() uidProvider,
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _tokenProvider = tokenProvider,
       _uidProvider = uidProvider,
       _base = Uri.parse(baseUrl),
       _client = client ?? http.Client() {
    if (!_isAllowedBaseUrl(_base)) {
      throw ArgumentError('La API requiere HTTPS.');
    }
  }
  final Future<String?> Function() _tokenProvider;
  final String? Function() _uidProvider;
  final Uri _base;
  final http.Client _client;
  final Duration timeout;
  bool _closed = false;

  String get baseOrigin => _base.origin;

  static bool _isAllowedBaseUrl(Uri uri) {
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;
    return _isLocalDevelopmentHost(uri.host);
  }

  static bool _isLocalDevelopmentHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '10.0.2.2') {
      return true;
    }

    final parts = normalized.split('.');
    if (parts.length != 4) return false;

    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      octets.add(value);
    }

    final first = octets[0];
    final second = octets[1];
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body);
  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uid = _uidProvider();
    if (_closed || uid == null) throw Exception('Inicia sesion nuevamente.');
    var expired = false;
    final abort = Completer<void>();
    try {
      return await (() async {
        final token = await _tokenProvider();
        if (expired || _closed || _uidProvider() != uid || token == null) {
          throw Exception('La sesion ha cambiado. Inicia sesion nuevamente.');
        }
        final uri = _base.resolve(path);
        if (uri.origin != _base.origin) {
          throw ArgumentError('Destino no permitido.');
        }
        debugPrint('API $method -> $uri');
        final request =
            http.AbortableRequest(method, uri, abortTrigger: abort.future)
              ..followRedirects = false
              ..headers.addAll({
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              });
        if (body != null) request.body = jsonEncode(body);
        final streamed = await _client.send(request);
        final bytes = <int>[];
        await for (final chunk in streamed.stream) {
          if (bytes.length + chunk.length > 1024 * 1024) {
            throw Exception('Respuesta demasiado grande.');
          }
          bytes.addAll(chunk);
        }
        if (expired || _closed || _uidProvider() != uid) {
          throw Exception('La sesion ha cambiado.');
        }
        dynamic data;
        try {
          data = jsonDecode(utf8.decode(bytes));
        } on FormatException {
          throw Exception('El servidor no devolvio una respuesta valida.');
        }
        if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
          debugPrint('API $method <- ${streamed.statusCode} $uri');
          return data;
        }
        debugPrint('API $method <- ${streamed.statusCode} $uri');
        final message =
            data is Map &&
                data['message'] is String &&
                (data['message'] as String).length <= 300
            ? data['message'] as String
            : 'No se pudo completar la solicitud (${streamed.statusCode}).';
        throw ApiException(
          message,
          statusCode: streamed.statusCode,
          path: uri.path,
        );
      })().timeout(
        timeout,
        onTimeout: () {
          expired = true;
          if (!abort.isCompleted) abort.complete();
          throw TimeoutException('Request expired');
        },
      );
    } on TimeoutException {
      throw Exception('La solicitud tardo demasiado. Puedes reintentar.');
    } on http.ClientException {
      throw Exception(connectionHelp(baseOrigin));
    } on SocketException {
      throw Exception(connectionHelp(baseOrigin));
    }
  }

  /// Explica por que fallo la conexion segun el destino configurado.
  ///
  /// En un telefono fisico `127.0.0.1` es el propio telefono, no el PC donde
  /// corre el backend: sin `adb reverse` o sin la IP de la LAN la app no llega
  /// nunca al servidor, aunque el backend este sano.
  static String connectionHelp(String origin) {
    final uri = Uri.parse(origin);
    final host = uri.host.toLowerCase();
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

    if (!isLoopback) {
      return 'No se pudo conectar con el backend en $origin. '
          'Revisa que el telefono siga en la misma red y que el backend este en ejecucion.';
    }

    return 'No se pudo conectar con el backend en $origin. '
        'En un telefono por USB ejecuta "adb reverse tcp:$port tcp:$port"; '
        'por WiFi compila con --dart-define=API_BASE_URL=http://<ip-de-la-laptop>:$port.';
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
