import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/services/esp32_ble_bridge_service.dart';

void main() {
  test('adapter state becomes an explainable failure', () {
    expect(
      Esp32BleBridgeService.failureForAdapterState(BluetoothAdapterState.on),
      Esp32BleBridgeFailure.none,
    );
    for (final off in [
      BluetoothAdapterState.off,
      BluetoothAdapterState.turningOff,
      BluetoothAdapterState.turningOn,
      BluetoothAdapterState.unknown,
    ]) {
      expect(
        Esp32BleBridgeService.failureForAdapterState(off),
        Esp32BleBridgeFailure.bluetoothOff,
      );
    }
    expect(
      Esp32BleBridgeService.failureForAdapterState(
        BluetoothAdapterState.unauthorized,
      ),
      Esp32BleBridgeFailure.permissionDenied,
    );
    expect(
      Esp32BleBridgeService.failureForAdapterState(
        BluetoothAdapterState.unavailable,
      ),
      Esp32BleBridgeFailure.bluetoothUnavailable,
    );
  });

  test('messages explain the problem without technical jargon', () {
    final off = Esp32BleBridgeService.failureMessage(
      Esp32BleBridgeFailure.bluetoothOff,
    );
    expect(off, contains('Bluetooth'));
    expect(off.toLowerCase(), contains('apagado'));
    expect(off.toLowerCase(), contains('actívalo'));

    final busy = Esp32BleBridgeService.failureMessage(
      Esp32BleBridgeFailure.bluetoothBusy,
    );
    expect(busy, contains('audífonos'));
    expect(busy, contains('parlantes'));
    expect(busy, contains('BoviSense necesita el Bluetooth'));

    final permissions = Esp32BleBridgeService.failureMessage(
      Esp32BleBridgeFailure.permissionDenied,
    );
    expect(permissions, contains('permiso'));
    expect(permissions, contains('ajustes'));

    final notFound = Esp32BleBridgeService.failureMessage(
      Esp32BleBridgeFailure.deviceNotFound,
    );
    expect(notFound, contains('encendido'));
    expect(notFound, contains('cerca'));

    expect(
      Esp32BleBridgeService.failureMessage(Esp32BleBridgeFailure.none),
      isEmpty,
    );
    // Ninguna falla debe quedar sin explicacion.
    for (final failure in Esp32BleBridgeFailure.values) {
      if (failure == Esp32BleBridgeFailure.none) continue;
      expect(
        Esp32BleBridgeService.failureMessage(failure).length,
        greaterThan(30),
        reason: '$failure',
      );
    }
  });
}
