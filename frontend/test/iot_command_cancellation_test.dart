import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/repositories/ganadero_repository.dart';
import 'package:frontend/data/services/api_client.dart';
import 'package:frontend/data/services/esp32_ble_bridge_service.dart';
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a queued command cancelled by disconnect never reports success',
    () async {
      var requests = 0;
      final api = ApiClient.withProviders(
        tokenProvider: () async => 'test-token',
        uidProvider: () => 'test-user',
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          requests++;
          throw StateError('A cancelled command must not request a ticket');
        }),
      );
      final bridge = Esp32BleBridgeService(GanaderoRepository(apiClient: api));
      addTearDown(() {
        bridge.dispose();
        api.close();
      });

      // Invalidate synchronously before the queue's first microtask runs.
      // There is no BLE connection, platform device or network call in this test.
      final command = bridge.startCounting();
      final assertion = expectLater(
        command,
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('Conexion interrumpida'),
          ),
        ),
      );
      await bridge.disconnect();
      await assertion;
      expect(requests, 0);
      expect(bridge.latestCountStatus, isNull);
      expect(bridge.isSending, isFalse);
    },
  );
}
