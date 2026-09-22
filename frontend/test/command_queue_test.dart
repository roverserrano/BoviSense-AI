import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/command_queue.dart';

void main() {
  test('tasks run one at a time in order', () async {
    final queue = CommandQueue();
    final log = <String>[];
    final gate = Completer<void>();

    final first = queue.add(() async {
      log.add('inicio-a');
      await gate.future;
      log.add('fin-a');
    });
    final second = queue.add(() async {
      log.add('b');
      return 2;
    });

    await Future<void>.delayed(Duration.zero);
    // La segunda tarea espera: no se solapan comandos hacia el equipo.
    expect(log, ['inicio-a']);
    expect(queue.isBusy, true);

    gate.complete();
    expect(await second, 2);
    await first;
    expect(log, ['inicio-a', 'fin-a', 'b']);
    expect(queue.isBusy, false);
  });

  test('a failed task does not block the queue', () async {
    final queue = CommandQueue();

    await expectLater(
      queue.add<int>(() async => throw Exception('boom')),
      throwsException,
    );
    expect(await queue.add(() async => 7), 7);
    expect(queue.isBusy, false);
  });
}
