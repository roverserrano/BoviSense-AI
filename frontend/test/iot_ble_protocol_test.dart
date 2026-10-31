import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/iot_ble_protocol.dart';

void main() {
  final request = 'a' * 32;
  final session = 'b' * 32;
  final response =
      'R1|$request|$session|STOPPED|27|2000000000|2000000000|${'c' * 32}';

  test(
    'R1 fragmented at every possible boundary is reconstructed unchanged',
    () {
      final bytes = ascii.encode('~$response\n');
      for (var offset = 0; offset <= bytes.length; offset++) {
        final decoder = IotBleFrameDecoder();
        expect(
          [
            ...decoder.add(bytes.sublist(0, offset)),
            ...decoder.add(bytes.sublist(offset)),
          ],
          [response],
        );
      }
    },
  );

  test('second R1 replaces an incomplete first notification', () {
    final decoder = IotBleFrameDecoder();
    expect(decoder.add(ascii.encode('~${response.substring(0, 25)}')), isEmpty);
    expect(decoder.add(ascii.encode('~$response\n')), [response]);
    expect(decoder.add(ascii.encode('~$response\n')), [response]);
  });

  test('stale fragments and connection changes do not complete a frame', () {
    var now = 0;
    final decoder = IotBleFrameDecoder(nowMilliseconds: () => now);
    decoder.add(ascii.encode('~${response.substring(0, 25)}'));
    now = 5000;
    expect(decoder.add(ascii.encode('${response.substring(25)}\n')), isEmpty);
    decoder.add(ascii.encode('~$response'));
    decoder.reset();
    expect(decoder.add([10]), isEmpty);
    expect(decoder.add(ascii.encode('~$response\n')), [response]);
  });

  test(
    'oversized and non ASCII frames are discarded without preventing recovery',
    () {
      final decoder = IotBleFrameDecoder();
      expect(decoder.add(ascii.encode('~${'a' * 201}\n')), isEmpty);
      expect(decoder.add([126, 65, 255, 10]), isEmpty);
      expect(decoder.add(ascii.encode('~$response\n')), [response]);
    },
  );

  test('responses must match both request and session', () {
    expect(IotBleProtocol.matchesReply(response, request, session), isTrue);
    expect(IotBleProtocol.matchesReply(response, session, session), isFalse);
    expect(IotBleProtocol.matchesReply(response, request, request), isFalse);
    expect(IotBleProtocol.matchesReply(response, null, null), isFalse);
    expect(
      IotBleProtocol.matchesReply('$response|extra', request, session),
      isFalse,
    );
  });

  test('B0 is a correlated error and cannot impersonate a result', () {
    expect(
      IotBleProtocol.matchesReply(
        'B0|$request|ERROR|lora_tx_timeout',
        request,
        session,
      ),
      isTrue,
    );
    expect(
      IotBleProtocol.matchesReply('B0|$request|RESULT|27', request, session),
      isFalse,
    );
    expect(
      IotBleProtocol.matchesReply(
        'B0|$request|ERROR|x|extra',
        request,
        session,
      ),
      isFalse,
    );
  });
}
