import 'dart:async';
import 'dart:isolate';

import '../ffi/gstp_library.dart';
import 'ffi_native_worker.dart';
import 'ffi_worker_channel.dart';

/// Dedicated isolate queue for blocking [FfiThumbnailCaptureRequest] work.
///
/// Keeps headless `gstp_thumbnail_capture` off the transport [FfiNativeWorker]
/// so play/pause/seek are not stalled by scrub previews. Latest-wins: at most
/// one capture runs; a newer request supersedes any queued predecessor.
class FfiThumbnailWorker {
  FfiThumbnailWorker._(this._channel);
  final FfiWorkerChannel _channel;
  var _generation = 0;
  FfiThumbnailCaptureRequest? _queued;
  Completer<Map<String, Object?>>? _queuedCompleter;
  var _draining = false;
  static FfiThumbnailWorker? _instance;
  static Future<FfiThumbnailWorker>? _starting;
  static bool get isStarted => _instance != null;

  static Future<FfiThumbnailWorker> ensureStarted() {
    if (_instance case final existing?) return Future.value(existing);
    return _starting ??= _start();
  }

  static Future<FfiThumbnailWorker> _start() async {
    try {
      final channel = await FfiWorkerChannel.start(
        _thumbnailWorkerMain,
        debugName: 'gstp-ffi-thumbnail',
        onFailure: () {
          _instance = null;
        },
      );
      return _instance = FfiThumbnailWorker._(channel);
    } finally {
      _starting = null;
    }
  }

  /// Capture with latest-wins coalescing (max one in-flight native capture).
  Future<Map<String, Object?>> capture(FfiThumbnailCaptureRequest request) {
    final completer = Completer<Map<String, Object?>>();
    final prev = _queuedCompleter;
    if (prev != null && !prev.isCompleted) {
      prev.completeError(const ThumbnailSupersededException());
    }
    _generation++;
    GstpLibrary.instance.bindings.gstp_thumbnail_cancel();
    _queued = request;
    _queuedCompleter = completer;
    unawaited(_drain());
    return completer.future;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queued != null) {
        final request = _queued!;
        final reply = _queuedCompleter!;
        final gen = _generation;
        _queued = null;
        _queuedCompleter = null;
        try {
          final map = await _channel.run<Map<String, Object?>>(request);
          if (gen != _generation) {
            if (!reply.isCompleted) {
              reply.completeError(const ThumbnailSupersededException());
            }
            continue;
          }
          if (!reply.isCompleted) {
            reply.complete(map);
          }
        } catch (e, st) {
          if (!reply.isCompleted) {
            reply.completeError(e, st);
          }
        }
      }
    } finally {
      _draining = false;
      if (_queued != null) {
        unawaited(_drain());
      }
    }
  }
}

/// Thrown when a newer scrub-preview capture replaces this request.
class ThumbnailSupersededException implements Exception {
  const ThumbnailSupersededException();

  @override
  String toString() => 'ThumbnailSupersededException';
}

@pragma('vm:entry-point')
void _thumbnailWorkerMain(SendPort ready) {
  final commands = ReceivePort();
  GstpLibrary.instance;
  ready.send(commands.sendPort);

  commands.listen((message) {
    final list = message as List<dynamic>;
    final id = list[0] as int;
    final reply = list[1] as SendPort;
    final request = list[2] as FfiRequest;
    try {
      final result = request.execute();
      reply.send(<Object?>[id, null, result]);
    } catch (e, st) {
      reply.send(<Object?>[id, e, st]);
    }
  });
}
