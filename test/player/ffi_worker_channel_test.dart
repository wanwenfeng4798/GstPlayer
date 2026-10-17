import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/player/ffi_worker_channel.dart';

void _failedStartup(SendPort ready) {
  throw StateError('failed before ready');
}

void _worker(SendPort ready) {
  final commands = ReceivePort();
  ready.send(commands.sendPort);
  commands.listen((dynamic message) {
    final list = message as List;
    if (list[2] == 'crash') throw StateError('worker crash');
    (list[1] as SendPort).send([list[0], null, list[2]]);
  });
}

void _exits(SendPort ready) {
  Isolate.exit();
}

void _neverReady(SendPort ready) {
  ReceivePort().listen((_) {});
}

void main() {
  test('startup errors and exits fail promptly', () async {
    for (final entry in [_failedStartup, _exits]) {
      var failed = false;
      await expectLater(
        FfiWorkerChannel.start(
          entry,
          debugName: 'test-fail',
          onFailure: () => failed = true,
        ),
        throwsStateError,
      );
      expect(failed, isTrue);
    }
  });
  test(
    'worker crash completes every pending request; a new worker can start',
    () async {
      var failures = 0;
      final channel = await FfiWorkerChannel.start(
        _worker,
        debugName: 'test-worker',
        onFailure: () => failures++,
      );
      expect(await channel.run<String>('hello'), 'hello');
      final first = expectLater(channel.run<Object>('crash'), throwsStateError);
      final second = expectLater(
        channel.run<Object>('pending'),
        throwsStateError,
      );
      await Future.wait([first, second]);
      expect(failures, 1);
      final replacement = await FfiWorkerChannel.start(
        _worker,
        debugName: 'test-restart',
        onFailure: () {},
      );
      expect(await replacement.run<int>(42), 42);
      replacement.close();
    },
  );
  test('missing handshake has a bounded timeout', () async {
    await expectLater(
      FfiWorkerChannel.start(
        _neverReady,
        debugName: 'test-timeout',
        onFailure: () {},
        startupTimeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
