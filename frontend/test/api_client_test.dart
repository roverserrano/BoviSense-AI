import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/services/api_client.dart';
import 'package:frontend/data/services/esp32_ble_bridge_service.dart';
import 'package:frontend/core/utils/request_id.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('allows cleartext HTTP only for local development hosts', () {
    for (final baseUrl in [
      'http://10.0.2.2:3000',
      'http://10.1.2.3:3000',
      'http://127.0.0.1:3000',
      'http://localhost:3000',
      'http://172.16.0.5:3000',
      'http://172.31.255.1:3000',
      'http://192.168.1.10:3000',
    ]) {
      final client = ApiClient.withProviders(
        tokenProvider: () async => 'secret',
        uidProvider: () => 'a',
        baseUrl: baseUrl,
      );
      client.close();
    }

    expect(
      () => ApiClient.withProviders(
        tokenProvider: () async => 'secret',
        uidProvider: () => 'a',
        baseUrl: 'http://servidor-publico.com',
      ),
      throwsArgumentError,
    );
    expect(
      () => ApiClient.withProviders(
        tokenProvider: () async => 'secret',
        uidProvider: () => 'a',
        baseUrl: 'http://8.8.8.8:3000',
      ),
      throwsArgumentError,
    );
    expect(
      () => ApiClient.withProviders(
        tokenProvider: () async => 'secret',
        uidProvider: () => 'a',
        baseUrl: 'http://172.32.0.1:3000',
      ),
      throwsArgumentError,
    );
  });
  test('sends authorization only over HTTPS', () async {
    final client = ApiClient.withProviders(
      tokenProvider: () async => 'secret',
      uidProvider: () => 'a',
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer secret');
        expect(request.followRedirects, false);
        return http.Response('{"ok":true}', 200);
      }),
    );
    expect(await client.get('/health'), {'ok': true});
    client.close();
  });
  test('late result after account change is rejected', () async {
    String? uid = 'a';
    final pending = Completer<http.Response>();
    final client = ApiClient.withProviders(
      tokenProvider: () async => 'secret',
      uidProvider: () => uid,
      baseUrl: 'https://example.test',
      client: MockClient((_) => pending.future),
    );
    final future = client.get('/private');
    await Future<void>.delayed(Duration.zero);
    uid = 'b';
    pending.complete(http.Response('{"private":true}', 200));
    await expectLater(future, throwsException);
    client.close();
  });
  test('connection help explains adb reverse for loopback backends', () {
    final loopback = ApiClient.connectionHelp('http://127.0.0.1:3000');
    expect(loopback, contains('adb reverse tcp:3000 tcp:3000'));
    expect(loopback, contains('--dart-define=API_BASE_URL'));

    final lan = ApiClient.connectionHelp('http://192.168.1.50:3000');
    expect(lan, isNot(contains('adb reverse')));
    expect(lan, contains('misma red'));
  });
  test('refused connection surfaces actionable guidance', () async {
    final client = ApiClient.withProviders(
      tokenProvider: () async => 'secret',
      uidProvider: () => 'a',
      baseUrl: 'http://127.0.0.1:3000',
      client: MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      ),
    );
    await expectLater(
      client.get('/api/ganadero/dashboard'),
      throwsA(
        predicate(
          (Object? error) =>
              error.toString().contains('adb reverse tcp:3000 tcp:3000'),
        ),
      ),
    );
    client.close();
  });
  test('stale session rejections are recognised', () {
    // Caso real: la Jetson se reinicia y el backend ya no tiene esa sesion.
    expect(
      Esp32BleBridgeService.isStaleSessionError(
        const ApiException(
          'No hay una sesion de conteo.',
          statusCode: 409,
          path: '/api/ganadero/iot/comandos',
        ),
      ),
      true,
    );
    expect(
      Esp32BleBridgeService.isStaleSessionError(
        const ApiException(
          'Esta sesion ya no esta en el equipo.',
          statusCode: 409,
          path: '/api/ganadero/iot/comandos',
        ),
      ),
      true,
    );
    expect(
      Esp32BleBridgeService.isStaleSessionError(
        const ApiException(
          'Comando no permitido.',
          statusCode: 400,
          path: '/api/ganadero/iot/comandos',
        ),
      ),
      false,
    );
    expect(
      Esp32BleBridgeService.isStaleSessionError(Exception('timeout')),
      false,
    );
  });
  test('request IDs are random 128-bit identifiers', () {
    final ids = List.generate(100, (_) => newRequestId());
    expect(ids.toSet().length, 100);
    expect(ids.every((id) => RegExp(r'^[a-f0-9]{32}$').hasMatch(id)), true);
  });
}
