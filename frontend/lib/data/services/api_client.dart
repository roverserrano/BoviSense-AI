import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    required FirebaseAuth auth,
    required String baseUrl,
    http.Client? client,
  }) : _auth = auth,
       _baseUrl = baseUrl,
       _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final String _baseUrl;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final token = await _auth.currentUser?.getIdToken(true);

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUri(String path) {
    final cleanBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  Future<dynamic> get(String path) async {
    final uri = _buildUri(path);
    debugPrint('API GET -> $uri');

    try {
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } on SocketException {
      throw Exception(
        'No se pudo conectar con el backend. Verifica la IP y que el servidor Node esté encendido.',
      );
    } on TimeoutException {
      throw Exception('El backend tardó demasiado en responder.');
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    debugPrint('API POST -> $uri');
    debugPrint('API BODY -> ${jsonEncode(body)}');

    try {
      final response = await _client
          .post(uri, headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } on SocketException {
      throw Exception(
        'No se pudo conectar con el backend. Verifica la IP y que el servidor Node esté encendido.',
      );
    } on TimeoutException {
      throw Exception(
        'La creación del usuario tardó demasiado. Revisa el envío de correo o el backend.',
      );
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final uri = _buildUri(path);
    debugPrint('API PUT -> $uri');
    debugPrint('API BODY -> ${jsonEncode(body)}');

    try {
      final response = await _client
          .put(uri, headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } on SocketException {
      throw Exception(
        'No se pudo conectar con el backend. Verifica la IP y que el servidor Node esté encendido.',
      );
    } on TimeoutException {
      throw Exception('La actualización tardó demasiado.');
    }
  }

  Future<dynamic> delete(String path) async {
    final uri = _buildUri(path);
    debugPrint('API DELETE -> $uri');

    try {
      final response = await _client
          .delete(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } on SocketException {
      throw Exception(
        'No se pudo conectar con el backend. Verifica la IP y que el servidor Node esté encendido.',
      );
    } on TimeoutException {
      throw Exception('La eliminación tardó demasiado.');
    }
  }

  dynamic _handleResponse(http.Response response) {
    debugPrint('API STATUS -> ${response.statusCode}');
    debugPrint('API RESPONSE -> ${response.body}');

    dynamic body;

    if (response.body.trim().isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic> && body['message'] != null) {
      throw Exception(body['message']);
    }

    if (body is String && body.isNotEmpty) {
      throw Exception(body);
    }

    throw Exception('Error HTTP ${response.statusCode}');
  }
}
