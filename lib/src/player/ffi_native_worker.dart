import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../domain/player_events.dart';
import '../ffi/gstp_library.dart';
import 'ffi_worker_channel.dart';

/// Serializes [headers] to JSON for the native HTTP source layer.
Pointer<Char>? encodeHttpHeadersJson(Map<String, String> headers) {
  if (headers.isEmpty) {
    return nullptr;
  }
  return jsonEncode(headers).toNativeUtf8().cast();
}

/// Long-lived isolate that serializes blocking `gstp_player_*` FFI calls.
///
/// Create / event pump / [NativeCallable] stay on the root isolate; transport
/// ops go through this queue so dispose/load cannot race across ephemeral
/// [Isolate.run] workers.
class FfiNativeWorker {
  FfiNativeWorker._(this._channel);
  final FfiWorkerChannel _channel;
  static FfiNativeWorker? _instance;
  static Future<FfiNativeWorker>? _starting;
  static bool get isStarted => _instance != null;

  static Future<FfiNativeWorker> ensureStarted() {
    if (_instance case final existing?) return Future.value(existing);
    return _starting ??= _start();
  }

  static Future<FfiNativeWorker> _start() async {
    try {
      final channel = await FfiWorkerChannel.start(
        _workerMain,
        debugName: 'gstp-ffi-worker',
        onFailure: () {
          _instance = null;
        },
      );
      return _instance = FfiNativeWorker._(channel);
    } finally {
      _starting = null;
    }
  }

  Future<T> run<T>(FfiRequest request) => _channel.run<T>(request);

  /// The worker processes messages in FIFO order, including disposal.
  Future<T> runAfterDrain<T>(FfiRequest request) => run<T>(request);
}

@pragma('vm:entry-point')
void _workerMain(SendPort ready) {
  final commands = ReceivePort();
  // Bindings must be ready before advertising a usable worker.
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

sealed class FfiRequest {
  const FfiRequest();
  Object? execute();
}

final class FfiDisposeRequest extends FfiRequest {
  const FfiDisposeRequest(this.playerId);
  final int playerId;

  @override
  Object? execute() {
    GstpLibrary.instance.bindings.gstp_player_dispose(playerId);
    return null;
  }
}

final class FfiLoadUriRequest extends FfiRequest {
  const FfiLoadUriRequest(
    this.playerId,
    this.uri,
    this.autoPlay,
    this.httpHeaders, {
    this.allowInsecureTls = false,
  });
  final int playerId;
  final String uri;
  final bool autoPlay;
  final Map<String, String> httpHeaders;
  final bool allowInsecureTls;

  @override
  Object? execute() {
    final ptr = uri.toNativeUtf8();
    final headersPtr = encodeHttpHeadersJson(httpHeaders);
    try {
      return GstpLibrary.instance.bindings.gstp_player_load_uri_with_tls(
        playerId,
        ptr.cast(),
        autoPlay,
        headersPtr ?? nullptr,
        !allowInsecureTls,
      );
    } finally {
      malloc.free(ptr);
      if (headersPtr != null) {
        malloc.free(headersPtr);
      }
    }
  }
}

final class FfiLoadAssetRequest extends FfiRequest {
  FfiLoadAssetRequest(this.playerId, this.assetKey, this.bytes, this.autoPlay);
  final int playerId;
  final String assetKey;
  final Uint8List bytes;
  final bool autoPlay;

  @override
  Object? execute() {
    final b = GstpLibrary.instance.bindings;
    final keyPtr = assetKey.toNativeUtf8();
    final ptr = malloc<Uint8>(bytes.length);
    try {
      ptr.asTypedList(bytes.length).setAll(0, bytes);
      return b.gstp_player_load_asset(
        playerId,
        keyPtr.cast(),
        nullptr,
        ptr,
        bytes.length,
        autoPlay,
      );
    } finally {
      malloc.free(keyPtr);
      malloc.free(ptr);
    }
  }
}

final class FfiCapabilitiesRequest extends FfiRequest {
  const FfiCapabilitiesRequest(this.playerId);
  final int playerId;

  @override
  Object? execute() {
    final seek = malloc<Bool>();
    final tracks = malloc<Bool>();
    final orientation = malloc<Bool>();
    try {
      final code = GstpLibrary.instance.bindings.gstp_player_get_capabilities(
        playerId,
        seek,
        tracks,
        orientation,
      );
      if (code != 0) {
        throw StateError('get_capabilities failed with code $code');
      }
      return <String, bool>{
        'seek': seek.value,
        'tracks': tracks.value,
        'orientation': orientation.value,
      };
    } finally {
      malloc.free(seek);
      malloc.free(tracks);
      malloc.free(orientation);
    }
  }
}

final class FfiGetTracksRequest extends FfiRequest {
  const FfiGetTracksRequest(this.playerId);
  final int playerId;

  @override
  Object? execute() {
    final b = GstpLibrary.instance.bindings;
    final count = b.gstp_player_get_track_count(playerId);
    final out = <Map<String, Object?>>[];
    final outId = malloc<Int32>();
    final outType = malloc<Int32>();
    final selected = malloc<Bool>();
    final language = malloc<Char>(32);
    final label = malloc<Char>(128);
    try {
      for (var i = 0; i < count; i++) {
        final rc = b.gstp_player_get_track(
          playerId,
          i,
          outId,
          outType,
          language,
          32,
          label,
          128,
          selected,
        );
        if (rc != 0) {
          continue;
        }
        out.add(<String, Object?>{
          'id': outId.value,
          'type': outType.value,
          'language': language.cast<Utf8>().toDartString(),
          'label': label.cast<Utf8>().toDartString(),
          'selected': selected.value,
        });
      }
    } finally {
      malloc.free(outId);
      malloc.free(outType);
      malloc.free(selected);
      malloc.free(language);
      malloc.free(label);
    }
    return out;
  }
}

final class FfiIntOpRequest extends FfiRequest {
  const FfiIntOpRequest(
    this.op,
    this.playerId, [
    this.arg0,
    this.arg1,
    this.arg2,
  ]);
  final String op;
  final int playerId;
  final Object? arg0;
  final Object? arg1;
  final Object? arg2;

  @override
  Object? execute() {
    final b = GstpLibrary.instance.bindings;
    switch (op) {
      case 'play':
        return b.gstp_player_play(playerId);
      case 'pause':
        return b.gstp_player_pause(playerId);
      case 'stop':
        return b.gstp_player_stop(playerId);
      case 'seek':
        return b.gstp_player_seek(
          playerId,
          arg0! as int,
          arg1 as bool? ?? false,
        );
      case 'set_volume':
        return b.gstp_player_set_volume(playerId, arg0! as double);
      case 'set_mute':
        return b.gstp_player_set_mute(playerId, arg0! as bool);
      case 'set_speed':
        return b.gstp_player_set_speed(playerId, arg0! as double);
      case 'set_looping':
        return b.gstp_player_set_looping(playerId, arg0! as bool);
      case 'select_track':
        return b.gstp_player_select_track(
          playerId,
          arg0! as int,
          arg1! as int,
          arg2! as bool,
        );
      case 'set_video_rotation':
        return b.gstp_player_set_video_rotation(playerId, arg0! as int);
      case 'set_aspect_ratio_mode':
        return b.gstp_player_set_aspect_ratio_mode(playerId, arg0! as int);
      default:
        throw StateError('Unknown FFI op: $op');
    }
  }
}

PipelineCapabilitiesDto capabilitiesFromMap(Map<String, bool> map) {
  return PipelineCapabilitiesDto(
    seek: map['seek'] ?? false,
    tracks: map['tracks'] ?? false,
    orientation: map['orientation'] ?? false,
  );
}

List<MediaTrack> tracksFromMaps(List<Map<String, Object?>> maps) {
  final types = TrackType.values;
  return maps.map((m) {
    final typeIdx = m['type']! as int;
    return MediaTrack(
      id: m['id']! as int,
      trackType: typeIdx >= 0 && typeIdx < types.length
          ? types[typeIdx]
          : TrackType.audio,
      language: m['language']! as String,
      label: m['label']! as String,
      selected: m['selected']! as bool,
    );
  }).toList();
}

Map<String, Object?> _readCapturedFrame({
  required int Function(
    Pointer<Pointer<Uint8>>,
    Pointer<Uint32>,
    Pointer<Int32>,
    Pointer<Int32>,
    Pointer<Int32>,
  )
  capture,
  required String op,
  String? notReadyMessage,
}) {
  final outPtr = malloc<Pointer<Uint8>>();
  final outLen = malloc<Uint32>();
  final outW = malloc<Int32>();
  final outH = malloc<Int32>();
  final outStride = malloc<Int32>();
  Pointer<Uint8> nativePixels = nullptr;
  try {
    final code = capture(outPtr, outLen, outW, outH, outStride);
    if (code != 0) {
      // GSTP_ERR_NOT_READY == -3
      if (code == -3 && notReadyMessage != null) {
        throw StateError(notReadyMessage);
      }
      throw StateError('$op failed with code $code');
    }
    final len = outLen.value;
    final ptr = outPtr.value;
    nativePixels = ptr;
    if (ptr == nullptr || len == 0) {
      throw StateError(notReadyMessage ?? '$op returned empty frame');
    }
    final bytes = Uint8List.fromList(ptr.asTypedList(len));
    return <String, Object?>{
      'bytes': bytes,
      'width': outW.value,
      'height': outH.value,
      'stride': outStride.value,
    };
  } finally {
    if (nativePixels != nullptr) {
      GstpLibrary.instance.bindings.gstp_thumbnail_free(nativePixels);
    }
    malloc.free(outPtr);
    malloc.free(outLen);
    malloc.free(outW);
    malloc.free(outH);
    malloc.free(outStride);
  }
}

final class FfiThumbnailCaptureRequest extends FfiRequest {
  const FfiThumbnailCaptureRequest({
    required this.uri,
    required this.positionMs,
    required this.maxWidth,
    this.httpHeaders = const {},
    this.allowInsecureTls = false,
  });

  final String uri;
  final int positionMs;
  final int maxWidth;
  final Map<String, String> httpHeaders;
  final bool allowInsecureTls;

  @override
  Object? execute() {
    final uriPtr = uri.toNativeUtf8();
    final headersPtr = encodeHttpHeadersJson(httpHeaders);
    try {
      return _readCapturedFrame(
        op: 'gstp_thumbnail_capture($uri)',
        capture: (outPtr, outLen, outW, outH, outStride) {
          return GstpLibrary.instance.bindings.gstp_thumbnail_capture_with_tls(
            uriPtr.cast(),
            positionMs,
            maxWidth,
            headersPtr ?? nullptr,
            !allowInsecureTls,
            outPtr,
            outLen,
            outW,
            outH,
            outStride,
          );
        },
      );
    } finally {
      malloc.free(uriPtr);
      if (headersPtr != null) {
        malloc.free(headersPtr);
      }
    }
  }
}

final class FfiPlayerCaptureFrameRequest extends FfiRequest {
  const FfiPlayerCaptureFrameRequest(this.playerId);
  final int playerId;

  @override
  Object? execute() {
    return _readCapturedFrame(
      op: 'gstp_player_capture_frame($playerId)',
      notReadyMessage: '尚未解码出画面，请稍后再截帧',
      capture: (outPtr, outLen, outW, outH, outStride) {
        return GstpLibrary.instance.bindings.gstp_player_capture_frame(
          playerId,
          outPtr,
          outLen,
          outW,
          outH,
          outStride,
        );
      },
    );
  }
}
