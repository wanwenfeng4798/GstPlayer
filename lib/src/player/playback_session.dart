import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../controls/playback_controls_model.dart';
import '../domain/player_events.dart';
import '../enum/video_rotation.dart';
import '../ffi/init_timing.dart';
import '../media/frame_image.dart';
import '../media/media_source_resolver.dart';
import '../model/video_source.dart';
import '../presentation/playback_presentation_model.dart';
import '../surface/texture_surface.dart';
import 'command_port.dart';

/// 深度编排模块：ChangeNotifier 状态、事件分发、open 生命周期与 transport /
/// Deep orchestration: ChangeNotifier state, event dispatch, open lifecycle, transport.
///
/// [GstPlayerController] 的核心实现。维护可监听状态，订阅 [PlayerCommandPort.events]，
/// 将 [PlayerEvent] 映射到字段；命令经 `_guard` 捕获异常并写入 [error]。
/// Core of [GstPlayerController]. Maintains listenable state, listens to [PlayerCommandPort.events],
/// maps [PlayerEvent] to fields; commands run through `_guard` to capture errors into [error].
///
/// Seek/volume 等命令会先乐观更新 UI（`_preview*`），再异步调用 Rust。
/// Seek/volume and similar commands optimistically update UI (`_preview*`) before async Rust calls.
class PlaybackSession extends ChangeNotifier
    implements PlaybackControlsModel, PlaybackPresentationModel {
  /// 创建会话；可注入测试用 [port] 与 [mediaSourceResolver] / Creates a session with optional test doubles.
  PlaybackSession({
    PlayerCommandPort? port,
    MediaSourceResolver? mediaSourceResolver,
  }) : _port = port ?? ProductionPlayerCommandPort(),
       _mediaSourceResolver =
           mediaSourceResolver ?? const MediaSourceResolver();

  final PlayerCommandPort _port;

  final MediaSourceResolver _mediaSourceResolver;

  PlayerState _state = PlayerState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Size _videoSize = Size.zero;
  int _bufferingPercent = 100;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _looping = false;
  bool _muted = false;
  String? _error;
  int? _playerId;
  bool _initialized = false;
  List<MediaTrack> _tracks = const [];
  VideoMetadata? _videoMetadata;
  bool _isSeekable = true;
  bool _supportsTracks = true;
  bool _supportsOrientation = false;
  int _mediaGeneration = 0;
  VideoRotation _videoRotation = VideoRotation.deg0;
  VideoSource? _mediaSource;

  StreamSubscription<PlayerEvent>? _sub;
  bool _disposed = false;

  /// 每次 [open] 递增；供 View 在切换媒体时重置 UI 状态 / Increments on each [open]; lets views reset UI state on media switch.
  int get mediaGeneration => _mediaGeneration;

  /// 是否正在播放 / Whether `state == playing`.
  @override
  bool get isPlaying => _state == PlayerState.playing;

  /// 是否已 EOS / Whether playback completed.
  bool get isCompleted => _state == PlayerState.completed;

  /// 显示宽高比；优先 DAR，否则由 [videoSize] 推算（均为 post-orient 尺寸）。
  /// Display aspect from DAR or [videoSize] (post-orient pipeline size).
  @override
  double get aspectRatio {
    final meta = _videoMetadata;
    if (meta != null &&
        meta.displayAspectWidth > 0 &&
        meta.displayAspectHeight > 0) {
      return meta.displayAspectWidth / meta.displayAspectHeight;
    }
    final s = _videoSize;
    return (s.width > 0 && s.height > 0) ? s.width / s.height : 16 / 9;
  }

  @override
  bool get initialized => _initialized;
  @override
  int? get playerId => _playerId;
  @override
  PlayerState get state => _state;
  @override
  Duration get position => _position;
  @override
  Duration get duration => _duration;
  Size get videoSize => _videoSize;
  @override
  int get bufferingPercent => _bufferingPercent;
  @override
  double get volume => _volume;
  @override
  double get speed => _speed;
  @override
  bool get looping => _looping;
  @override
  bool get muted => _muted;
  String? get error => _error;
  @override
  List<MediaTrack> get tracks => _tracks;
  VideoMetadata? get videoMetadata => _videoMetadata;
  @override
  bool get isSeekable => _isSeekable;
  @override
  bool get supportsTracks => _supportsTracks;
  @override
  bool get supportsOrientation => _supportsOrientation;
  @override
  VideoRotation get videoRotation => _videoRotation;

  /// 当前已打开的媒体源 / Currently open media source.
  @override
  VideoSource? get mediaSource => _mediaSource;

  /// 创建原生 player 并订阅事件流 / Creates native player and subscribes to events.
  Future<void> initialize() async {
    if (_initialized) return;
    final total = Stopwatch()..start();
    await _port.create();
    final id = _port.playerId;
    if (id == null) {
      throw StateError('PlayerCommandPort.create() did not assign playerId');
    }
    _playerId = id;
    _initialized = true;
    notifyListeners();
    _sub = _port.events.listen(
      _onEvent,
      onError: (Object e) => _applyError(e.toString()),
    );
    gstpInitTiming('controller_total', total);
  }

  void _onEvent(PlayerEvent event) {
    if (_disposed) return;
    if (event.kind == PlayerEventKind.tracksChanged) {
      unawaited(_refreshTracksFromPort());
      return;
    }
    _applyEvent(event);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _applyError(e.toString());
    }
  }

  /// 经统一解析器加载 [source] / Loads [source] via the unified media resolver.
  ///
  /// 调用前 [_resetForOpen] 清空上一媒体状态，并 [setVideoRotation] 同步 native 为 0°；
  /// 加载后更新 pipeline 能力并刷新轨道。
  /// Clears prior media state via [_resetForOpen]; resets native rotation before load.
  Future<void> open(VideoSource source, {bool autoPlay = false}) async {
    _resetForOpen();
    _mediaSource = source;
    await _guard(() async {
      await _port.setVideoRotation(0);
      await _port.loadSource(
        _mediaSourceResolver.resolve(source),
        autoPlay: autoPlay,
      );
      _setPipelineCapabilities(await _port.getPipelineCapabilities());
      await _refreshTracksFromPort();
    });
  }

  /// 播放；EOS 后手动 replay 会将 [speed] 重置为 1.0 并从 0 起播 / Plays; resets speed and position after EOS replay.
  Future<void> play() {
    // Manual replay after EOS resets speed to 1x (engine resets its rate too);
    // keep the UI in sync. Normal pause->resume (not completed) keeps the speed.
    if (_state == PlayerState.completed) {
      _speed = 1.0;
      _position = Duration.zero;
      notifyListeners();
    }
    return _guard(_port.play);
  }

  Future<void> pause() => _guard(_port.pause);

  Future<void> stop() => _guard(_port.stop);

  @override
  Future<void> togglePlayPause() => isPlaying ? pause() : play();

  /// 跳转；仅更新位置预览，缓冲态由 native BUFFERING 事件驱动 / Seeks; position preview only — buffering from native events.
  @override
  Future<void> seek(Duration position) async {
    _previewSeek(position, showBuffering: false);
    await _guard(() => _port.seek(position));
  }

  @override
  Future<void> setVolume(double volume) async {
    _previewVolume(volume);
    await _guard(() => _port.setVolume(_volume));
  }

  Future<void> setMuted(bool muted) async {
    _previewMuted(muted);
    await _guard(() => _port.setMute(muted));
  }

  @override
  Future<void> toggleMuted() => setMuted(!_muted);

  @override
  Future<void> setSpeed(double speed) async {
    _previewSpeed(speed);
    await _guard(() => _port.setSpeed(_speed));
  }

  @override
  Future<void> setLooping(bool looping) async {
    _previewLooping(looping);
    await _guard(() => _port.setLooping(looping));
  }

  /// 从 port 重新拉取轨道 / Refreshes tracks from the port.
  Future<void> refreshTracks() => _refreshTracksFromPort();

  @override
  Future<void> selectTrack(MediaTrack track, {bool enable = true}) =>
      _guard(() => _port.selectTrack(track, enable: enable));

  @override
  Future<void> setVideoRotation(VideoRotation rotation) async {
    _videoRotation = rotation;
    notifyListeners();
    await _guard(() => _port.setVideoRotation(rotation.degrees));
  }

  @override
  Future<void> setAspectRatioMode(AspectRatioMode mode) =>
      _guard(() => _port.setAspectRatioMode(mode));

  /// 截取当前最新画面为 PNG / Captures the latest decoded frame as PNG.
  Future<Uint8List> captureCurrentFrame() async {
    final map = await _port.captureCurrentFrame();
    return CapturedBgraFrame.fromMap(map).toPng();
  }

  @override
  Future<Uint8List?> captureFramePng() async {
    try {
      return await captureCurrentFrame();
    } catch (_) {
      return null;
    }
  }

  /// 取消订阅、销毁 player 并释放监听 / Cancels subscription, disposes player and listeners.
  ///
  /// Releases the native Flutter texture while [playerId] is still valid, then
  /// clears ids before awaiting port dispose so late events cannot race.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final id = _playerId;
    if (id != null) {
      await disposeNativePlayerTexture(id);
    }
    _playerId = null;
    _initialized = false;
    await _sub?.cancel();
    await _port.dispose();
    super.dispose();
  }

  Future<void> _refreshTracksFromPort() async {
    try {
      _tracks = await _port.getTracks();
      notifyListeners();
    } catch (e) {
      _applyError(e.toString());
    }
  }

  void _resetForOpen() {
    _error = null;
    // Optimistic loading UI until native BUFFERING / READY / PLAYING events.
    _bufferingPercent = 0;
    _videoSize = Size.zero;
    _videoMetadata = null;
    _tracks = const [];
    _speed = 1.0;
    _state = PlayerState.buffering;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isSeekable = true;
    _volume = 1.0;
    _muted = false;
    _looping = false;
    _videoRotation = VideoRotation.deg0;
    _mediaGeneration++;
    notifyListeners();
  }

  void _applyEvent(PlayerEvent event) {
    switch (event.kind) {
      case PlayerEventKind.durationChanged:
        _duration = Duration(milliseconds: event.durationMs);
      case PlayerEventKind.positionChanged:
        _position = Duration(milliseconds: event.positionMs);
      case PlayerEventKind.videoSize:
        _videoSize = Size(
          event.width.toDouble(),
          event.height.toDouble(),
        );
      case PlayerEventKind.metadataChanged:
        _videoMetadata = VideoMetadata(
          width: event.width,
          height: event.height,
          fps: event.fps,
          pixelAspectWidth: event.pixelAspectWidth,
          pixelAspectHeight: event.pixelAspectHeight,
          displayAspectWidth: event.displayAspectWidth,
          displayAspectHeight: event.displayAspectHeight,
          interlaced: event.interlaced,
          colorMatrix: event.colorMatrix,
          colorRange: event.colorRange,
          hdrFormat: event.hdrFormat,
        );
      case PlayerEventKind.stateChanged:
        _state = event.state;
      case PlayerEventKind.buffering:
        _bufferingPercent = event.bufferingPercent;
        // Native may pause during rebuffer; restore transport state from the event.
        if (event.bufferingPercent < 100) {
          _state = PlayerState.buffering;
        } else {
          // Buffering finished but native may still be waiting for surface /
          // deferred play — do not fake playing (masks "not actually playing").
          _state = event.state == PlayerState.buffering
              ? PlayerState.ready
              : event.state;
        }
      case PlayerEventKind.eos:
        _state = PlayerState.completed;
        _position = _duration;
      case PlayerEventKind.error:
        _error = event.message;
        _state = PlayerState.error;
        _bufferingPercent = 100;
      case PlayerEventKind.tracksChanged:
        break;
    }
    if (event.kind != PlayerEventKind.tracksChanged) {
      notifyListeners();
    }
  }

  void _applyError(String message) {
    _error = message;
    _state = PlayerState.error;
    _bufferingPercent = 100;
    notifyListeners();
  }

  void _setPipelineCapabilities(PipelineCapabilitiesDto caps) {
    _isSeekable = caps.seek;
    _supportsTracks = caps.tracks;
    _supportsOrientation = caps.orientation;
    notifyListeners();
  }

  void _previewSeek(Duration position, {required bool showBuffering}) {
    _position = position;
    if (showBuffering) {
      _state = PlayerState.buffering;
    }
    notifyListeners();
  }

  void _previewVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    _volume = v;
    if (v > 0 && _muted) {
      _muted = false;
    }
    notifyListeners();
  }

  void _previewMuted(bool muted) {
    _muted = muted;
    notifyListeners();
  }

  void _previewSpeed(double speed) {
    _speed = speed <= 0 ? 1.0 : speed;
    notifyListeners();
  }

  void _previewLooping(bool looping) {
    _looping = looping;
    notifyListeners();
  }
}
