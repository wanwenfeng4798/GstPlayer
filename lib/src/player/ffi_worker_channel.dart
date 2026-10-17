import 'dart:async';
import 'dart:isolate';

/// Monitors a serial isolate, including failures before its ready handshake.
/// Every outstanding request terminates if the isolate exits unexpectedly.
class FfiWorkerChannel {
  FfiWorkerChannel._(this._onFailure);

  final void Function() _onFailure;
  final ReceivePort _messages = ReceivePort();
  final Completer<void> _ready = Completer<void>();
  final Map<int, Completer<Object?>> _pending = {};
  Isolate? _isolate;
  SendPort? _commands;
  Object? _failure;
  var _nextId = 0;

  static Future<FfiWorkerChannel> start(
    void Function(SendPort) entry, {
    required String debugName,
    required void Function() onFailure,
    Duration startupTimeout = const Duration(seconds: 10),
  }) async {
    final channel = FfiWorkerChannel._(onFailure);
    channel._ready.future.ignore();
    channel._messages.listen(channel._onMessage);
    try {
      channel._isolate = await Isolate.spawn(
        entry,
        channel._messages.sendPort,
        onError: channel._messages.sendPort,
        onExit: channel._messages.sendPort,
        errorsAreFatal: true,
        debugName: debugName,
      );
      await channel._ready.future.timeout(startupTimeout);
      return channel;
    } catch (error, stack) {
      channel._fail(error, stack);
      channel._isolate?.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _commands = message;
      if (!_ready.isCompleted) _ready.complete();
    } else if (message is List && message.length == 3 && message[0] is int) {
      final reply = _pending.remove(message[0]);
      if (reply == null) return;
      if (message[1] == null) {
        reply.complete(message[2]);
      } else {
        reply.completeError(message[1]!, message[2] as StackTrace?);
      }
    } else {
      final error = message is List
          ? StateError('FFI isolate failed: ${message.first}')
          : StateError('FFI isolate exited unexpectedly');
      _fail(
        error,
        message is List && message.length > 1
            ? StackTrace.fromString('${message[1]}')
            : StackTrace.current,
      );
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_failure != null) return;
    _failure = error;
    if (!_ready.isCompleted) _ready.completeError(error, stack);
    for (final reply in _pending.values) {
      reply.completeError(error, stack);
    }
    _pending.clear();
    _messages.close();
    _onFailure();
  }

  Future<T> run<T>(Object request) async {
    if (_failure != null) throw _failure!;
    final id = _nextId++;
    final reply = Completer<Object?>();
    _pending[id] = reply;
    try {
      _commands!.send([id, _messages.sendPort, request]);
    } catch (_) {
      _pending.remove(id);
      rethrow;
    }
    return await reply.future as T;
  }

  /// Used when an owner explicitly shuts down its worker.
  void close() {
    _fail(StateError('FFI worker closed'), StackTrace.current);
    _isolate?.kill(priority: Isolate.immediate);
  }
}
