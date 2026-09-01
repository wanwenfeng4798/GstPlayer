import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controls/playback_controls_model.dart';
import '../gstplayer.dart';
import '../domain/player_events.dart';
import '../domain/seek_failure_reason.dart';
import '../enum/video_rotation.dart';
import '../enum/video_source_type.dart';
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
/// Seek/volume 等命令会先乐观更新 UI（`_preview*`），再异步调用 native FFI。
/// Seek/volume and similar commands optimistically update UI (`_preview*`) before async native FFI calls.
class PlaybackSession extends ChangeNotifier
    implements PlaybackControlsModel, PlaybackPresentationModel {
  static const Duration _transportDebounce = Duration(milliseconds: 200);

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

  /// Latest play/pause intent while transport ops are in flight / 传输进行中的最新播放意图.
  bool? _wantPlaying;
  int _transportGen = 0;
  int? _wantGen;
  int? _sentTransportGen;
  Future<void>? _transportFlush;

  /// True after [open] until first frame is playable; ignores bogus preroll position.
  bool _loadingMedia = false;

  /// Pins UI position after user seek until native timing catches up.
  int? _seekPinMs;
  DateTime? _seekPinUntil;

  SeekFailureReason? _lastSeekFailure;
  int _seekFailureGeneration = 0;

  /// Last seek failure reason for UI feedback; cleared on successful seek or [open].
  SeekFailureReason? get lastSeekFailure => _lastSeekFailure;

  /// Increments when [lastSeekFailure] is set so views can show one-shot toasts.
  int get seekFailureGeneration => _seekFailureGeneration;

  /// 每次 [open] 递增；供 View 在切换媒体时重置 UI 状态 / Increments on each [open]; lets views reset UI state on media switch.
  @override
  int get mediaGeneration => _mediaGeneration;

  /// 加载期遮挡视频表面（切源/重播），rebuffer 不遮挡 / Covers video during load; not mid-playback rebuffer.
  @override
  bool get hideVideoSurface => _loadingMedia;

  /// 与 [hideVideoSurface] 同生命周期，驱动 loading 指示器 / Loading spinner during initial load.
  @override
  bool get showLoadingOverlay => _loadingMedia;

  /// 当前视频帧尺寸 / Decoded video frame size.
  @override
  Size get presentationVideoSize => _videoSize;

  /// 是否正在播放 / Whether playback should show as playing (honors pending intent).
  @override
  bool get isPlaying {
    final want = _wantPlaying;
    if (want != null) return want;
    return _state == PlayerState.playing;
  }

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

  /// 播放；EOS 后手动 replay 与 [open] 相同路径重新加载当前源 / Plays; after EOS, reloads current source like [open].
  Future<void> play() {
    if (_state == PlayerState.completed) {
      final source = _mediaSource;
      if (source != null) {
        return open(source, autoPlay: true);
      }
    }
    _setWantPlaying(true);
    return _flushTransport();
  }

  Future<void> pause() {
    _setWantPlaying(false);
    return _flushTransport();
  }

  Future<void> stop() async {
    _clearTransportIntent();
    _state = PlayerState.stopped;
    notifyListeners();
    // Wait for any in-flight play/pause before stop so native order stays sane.
    final inFlight = _transportFlush;
    if (inFlight != null) {
      await inFlight;
    }
    await _guard(_port.stop);
  }

  @override
  Future<void> togglePlayPause() {
    if (_state == PlayerState.completed) {
      return play();
    }
    if (isPlaying) {
      return pause();
    }
    return play();
  }

  void _setWantPlaying(bool want) {
    _wantPlaying = want;
    _wantGen = ++_transportGen;
    if (want) {
      if (_state != PlayerState.buffering) {
        _state = PlayerState.playing;
      }
    } else {
      _state = PlayerState.paused;
    }
    notifyListeners();
  }

  void _clearTransportIntent() {
    _wantPlaying = null;
    _wantGen = null;
    _sentTransportGen = null;
  }

  Future<void> _flushTransport() {
    return _transportFlush ??= _runTransportFlush();
  }

  /// Serializes play/pause and coalesces to the latest intent so rapid toggles
  /// cannot leave UI "playing" while native ends on pause (or vice versa).
  ///
  /// Native play/pause returns immediately (async GST apply). Keep
  /// [_wantPlaying] until a confirming state event so a late PAUSED from an
  /// earlier pause cannot clobber a newer play (UI playing, pipeline paused).
  Future<void> _runTransportFlush() async {
    try {
      while (!_disposed) {
        // Coalesce rapid taps so we don't hammer Android codec state changes.
        await Future<void>.delayed(_transportDebounce);
        final want = _wantPlaying;
        final gen = _wantGen;
        if (want == null || gen == null) break;
        if (_sentTransportGen == gen) break;
        try {
          if (want) {
            await _port.play();
          } else {
            await _port.pause();
          }
        } catch (e) {
          _applyError(e.toString());
          if (_wantGen == gen) {
            _clearTransportIntent();
          }
          break;
        }
        if (_wantGen == gen) {
          _sentTransportGen = gen;
        }
        // Newer tap while awaiting — loop and send the latest intent.
        if (_wantGen != gen) {
          continue;
        }
        // Leave [_wantPlaying] set; [_applyEvent] clears on confirming state.
        break;
      }
    } finally {
      _transportFlush = null;
      if (!_disposed &&
          _wantPlaying != null &&
          _wantGen != null &&
          _sentTransportGen != _wantGen) {
        unawaited(_flushTransport());
      }
    }
  }

  /// 跳转；仅更新位置预览，缓冲态由 native BUFFERING 事件驱动 / Seeks; position preview only — buffering from native events.
  ///
  /// Soft-fails: a native seek error rolls position back to the pre-seek value
  /// and does not promote the session to [PlayerState.error] (scrub must stay
  /// recoverable).
  @override
  Future<void> seek(Duration position) async {
    final beforeSeek = _position;
    final ms = position.inMilliseconds;
    _seekPinMs = ms;
    _seekPinUntil = DateTime.now().add(const Duration(seconds: 5));
    _previewSeek(position, showBuffering: false);
    try {
      await _port.seek(position);
      if (_lastSeekFailure != null) {
        _lastSeekFailure = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('gstplayer: seek soft-fail: $e');
      _seekPinMs = null;
      _seekPinUntil = null;
      _position = beforeSeek;
      _lastSeekFailure = _classifySeekFailure();
      _seekFailureGeneration++;
      notifyListeners();
    }
  }

  SeekFailureReason _classifySeekFailure() {
    if (!_isSeekable) {
      return SeekFailureReason.notSeekable;
    }
    final source = _mediaSource;
    if (source?.type == VideoSourceType.network && _bufferingPercent < 100) {
      return SeekFailureReason.bufferingIncomplete;
    }
    return SeekFailureReason.notSeekable;
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
    /* All platforms: GStreamer screenshot path (official snapshot-style thumbnail).
     * Android display sink has no appsink branch, so go straight to thumbnail. */
    if (!kIsWeb && Platform.isAndroid) {
      return _captureThumbnailFallback();
    }
    try {
      return await captureCurrentFrame();
    } catch (_) {
      return _captureThumbnailFallback();
    }
  }

  Future<Uint8List?> _captureThumbnailFallback() async {
    final source = _mediaSource;
    if (source == null) return null;
    try {
      return await GstPlayer.captureThumbnail(
        source,
        at: _position,
        maxWidth: 720,
      );
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
    _clearTransportIntent();
    _loadingMedia = true;
    // Optimistic loading UI until native BUFFERING / READY / PLAYING events.
    _bufferingPercent = 0;
    _videoSize = Size.zero;
    _videoMetadata = null;
    _tracks = const [];
    _speed = 1.0;
    _state = PlayerState.buffering;
    _position = Duration.zero;
    _duration = Duration.zero;
    _seekPinMs = null;
    _seekPinUntil = null;
    _lastSeekFailure = null;
    _seekFailureGeneration = 0;
    _isSeekable = true;
    _volume = 1.0;
    _muted = false;
    // Preserve [_looping] — EOS loop reload uses open() without toggling loop off.
    _videoRotation = VideoRotation.deg0;
    _mediaGeneration++;
    notifyListeners();
  }

  /// Clears load gate once video size, buffering, and PLAYING are all ready.
  void _clearLoadingMediaIfReady() {
    if (!_loadingMedia) return;
    if (_videoSize.width <= 0 || _videoSize.height <= 0) return;
    if (_bufferingPercent < 100) return;
    if (_state != PlayerState.playing) return;
    _loadingMedia = false;
  }

  static const Duration _maxPosition = Duration(hours: 24);

  Duration _clampPosition(Duration position, Duration duration) {
    if (_state == PlayerState.idle ||
        _state == PlayerState.ready ||
        _state == PlayerState.stopped ||
        _state == PlayerState.error) {
      return Duration.zero;
    }
    var ms = position.inMilliseconds;
    if (ms < 0) {
      ms = 0;
    }
    if (duration <= Duration.zero) {
      // Reject one-shot bogus preroll; allow monotonic advance before duration.
      if (_position.inMilliseconds <= 0 && ms > 120000) {
        ms = 0;
      } else if (ms > _position.inMilliseconds + 15000) {
        ms = _position.inMilliseconds;
      }
    }
    final maxMs = _maxPosition.inMilliseconds;
    if (ms > maxMs) {
      ms = maxMs;
    }
    if (duration > Duration.zero) {
      final durMs = duration.inMilliseconds;
      if (ms > durMs) {
        ms = durMs;
      }
    }
    return Duration(milliseconds: ms);
  }

  void _applyEvent(PlayerEvent event) {
    switch (event.kind) {
      case PlayerEventKind.durationChanged:
        _duration = Duration(milliseconds: event.durationMs);
        _isSeekable = event.isSeekable;
      case PlayerEventKind.positionChanged:
        if (_loadingMedia) {
          break;
        }
        var eventMs = event.positionMs;
        if (_seekPinMs != null && _seekPinUntil != null) {
          if (DateTime.now().isBefore(_seekPinUntil!)) {
            final pin = _seekPinMs!;
            final delta = (eventMs - pin).abs();
            final tol = math.max(
              3000,
              (_duration.inMilliseconds * 0.05).round(),
            );
            if (delta > tol) {
              break;
            }
            if (delta <= tol) {
              _seekPinMs = null;
              _seekPinUntil = null;
            }
          } else {
            _seekPinMs = null;
            _seekPinUntil = null;
          }
        }
        _position = _clampPosition(Duration(milliseconds: eventMs), _duration);
      case PlayerEventKind.videoSize:
        _videoSize = Size(event.width.toDouble(), event.height.toDouble());
        _clearLoadingMediaIfReady();
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
        _isSeekable = event.isSeekable;
        if (_wantPlaying != null) {
          // Confirm or ignore while an intent is in flight.
          switch (event.state) {
            case PlayerState.playing:
              if (_wantPlaying == true) {
                _clearTransportIntent();
                _state = event.state;
                _clearLoadingMediaIfReady();
              }
            case PlayerState.paused:
              if (_wantPlaying == false) {
                _clearTransportIntent();
                _state = event.state;
              }
            case PlayerState.ready:
              break;
            case PlayerState.stopped:
              break;
            case PlayerState.completed:
            case PlayerState.error:
            case PlayerState.idle:
              _clearTransportIntent();
              _state = event.state;
            case PlayerState.buffering:
              _state = event.state;
          }
        } else {
          _state = event.state;
          _clearLoadingMediaIfReady();
        }
      case PlayerEventKind.buffering:
        final incoming = event.bufferingPercent;
        if (_loadingMedia && incoming < 100 && incoming < _bufferingPercent) {
          // Ignore download-queue regressions during initial MOV/AVI fill.
        } else {
          _bufferingPercent = incoming;
        }
        // Mid-playback rebuffer: keep playing state so video surface stays visible.
        if (event.bufferingPercent < 100) {
          if (_loadingMedia || _videoSize == Size.zero) {
            _state = PlayerState.buffering;
          }
        } else if (_wantPlaying != null) {
          _state = _wantPlaying! ? PlayerState.playing : PlayerState.paused;
        } else if (!_loadingMedia) {
          // Buffering finished but native may still be waiting for surface /
          // deferred play — do not fake playing (masks "not actually playing").
          _state = event.state == PlayerState.buffering
              ? PlayerState.ready
              : event.state;
        }
        _clearLoadingMediaIfReady();
      case PlayerEventKind.eos:
        if (_looping && _mediaSource != null) {
          unawaited(open(_mediaSource!, autoPlay: true));
          break;
        }
        _clearTransportIntent();
        _state = PlayerState.completed;
        _position = _duration;
      case PlayerEventKind.error:
        _clearTransportIntent();
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
    _loadingMedia = false;
    notifyListeners();
  }

  void _setPipelineCapabilities(PipelineCapabilitiesDto caps) {
    _isSeekable = caps.seek;
    _supportsTracks = caps.tracks;
    _supportsOrientation = caps.orientation;
    notifyListeners();
  }

  Duration _clampSeekPreview(Duration position) {
    var ms = position.inMilliseconds;
    if (ms < 0) {
      ms = 0;
    }
    final duration = _duration;
    if (duration <= Duration.zero) {
      if (ms > 60000) {
        ms = 0;
      }
    }
    final maxMs = _maxPosition.inMilliseconds;
    if (ms > maxMs) {
      ms = maxMs;
    }
    if (duration > Duration.zero) {
      final durMs = duration.inMilliseconds;
      if (ms > durMs) {
        ms = durMs;
      }
    }
    return Duration(milliseconds: ms);
  }

  void _previewSeek(Duration position, {required bool showBuffering}) {
    _position = _clampSeekPreview(position);
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
