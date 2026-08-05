import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'controls/fullscreen_config.dart';
import 'controls/immersive_controls_state.dart';
import 'controls/scrub_preview_track.dart';
import 'controls/bili_overlay_controls.dart';
import 'controls/video_controls.dart';
import 'enum/video_controls_style.dart';
import 'overlay/danmaku.dart';
import 'overlay/subtitle.dart';
import 'presentation/playback_presentation.dart';
import 'gstplayer_controller.dart';

export 'controls/fullscreen_config.dart';
export 'controls/scrub_preview_track.dart'
    show
        ScrubPreviewFrame,
        ScrubPreviewTrack,
        ScrubPreviewTrackFrames,
        ScrubPreviewTrackSprite,
        ScrubPreviewTrackVtt,
        ScrubPreviewVttParser;
export 'controls/video_controls.dart';
export 'overlay/danmaku.dart';
export 'overlay/subtitle.dart';

/// 通过 Flutter 外部 Texture 渲染 GStreamer 视频，可选内置自适应控件栏 / Renders GStreamer video through a Flutter external texture with an optional adaptive control bar.
///
/// 组合 [PlaybackPresentation]（视频表面 + 宽高比 + 缓冲指示）与 [VideoControls]（自动隐藏控件栏）。
/// Composes [PlaybackPresentation] (surface, aspect ratio, buffering chrome) and [VideoControls] (auto-hiding bar).
class GstVideoView extends StatefulWidget {
  /// 创建视频视图 / Creates a video view.
  ///
  /// # 参数 / Parameters
  /// - `controller` — 已 [GstPlayerController.initialize] 的控制器 / initialized controller
  /// - `aspectRatioMode` —  letterbox / 裁剪 / 拉伸，默认 [AspectRatioMode.fit] / letterbox, crop, or stretch
  /// - `backgroundColor` —  letterbox 区域背景色 / background behind letterbox bars
  /// - `showControls` — 是否叠加内置控件栏 / whether to overlay built-in controls
  /// - `controlsStyle` — 控件视觉风格 / control bar visual style
  /// - `fullscreen` — 沉浸控件配置 / immersive controls configuration
  /// - `poster` — 开播前封面图 / cover image before playback starts
  /// - `keepLastFrame` — 播完后保留最后一帧叠层 / keep last frame after EOS
  /// - `scrubPreview` — 外部进度条缩略图轨（GSY WebVTT/雪碧图），不实时抽帧
  /// - `danmaku` / `danmakuEnabled` — 弹幕列表与开关 / danmaku items and toggle
  /// - `onDanmakuSend` — 底栏发送弹幕 / send danmaku from bottom bar
  /// - `onDanmakuEnabledChanged` / `onSubtitlesEnabledChanged` — 底栏开关
  /// - `subtitles` / `subtitlesEnabled` — 外挂字幕 cues 与开关 / external subtitle cues
  /// - `onScreenshot` — 截图 PNG 交给宿主保存（插件不落盘）/ host saves PNG bytes
  const GstVideoView({
    super.key,
    required this.controller,
    this.aspectRatioMode = AspectRatioMode.fit,
    this.backgroundColor = const Color(0xFF000000),
    this.showControls = true,
    this.controlsStyle = VideoControlsStyle.adaptive,
    this.fullscreen = const VideoControlsFullscreenConfig(),
    this.poster,
    this.keepLastFrame = true,
    this.scrubPreview,
    this.danmaku = const [],
    this.danmakuEnabled = false,
    this.onDanmakuSend,
    this.onDanmakuEnabledChanged,
    this.onSubtitlesEnabledChanged,
    this.subtitles = const [],
    this.subtitlesEnabled = true,
    this.showCaptureButton = true,
    this.onScreenshot,
  });

  /// 绑定的播放器控制器；同时作为 presentation 与 controls 的 model / Bound player controller; model for presentation and controls.
  final GstPlayerController controller;

  /// 视频表面宽高比模式初始值 / Initial aspect ratio mode for the video surface.
  final AspectRatioMode aspectRatioMode;

  /// 视频周围/letterbox 区域背景色 / Color painted behind and around the video.
  final Color backgroundColor;

  /// 是否显示内置控件栏 / Whether to overlay built-in controls.
  final bool showControls;

  /// 内置控件栏风格（默认 adaptive）/ Built-in control bar style (default adaptive).
  final VideoControlsStyle controlsStyle;

  /// 全屏沉浸控件配置 / Fullscreen immersive controls configuration.
  final VideoControlsFullscreenConfig fullscreen;

  /// 开播前/无画面时显示的封面 / Poster shown before frames are available.
  final ImageProvider? poster;

  /// EOS 后是否尝试保留尾帧叠层（Android Surface 通常已冻结最后一帧，
  /// 无需/不支持中途截帧；封面请用 [poster] 传入图片，参考 GSYVideoPlayer）/
  /// After EOS, optionally keep a last-frame overlay. On Android the surface
  /// already freezes; mid-play capture is unsupported — pass [poster] instead.
  final bool keepLastFrame;

  /// External scrub thumbnail track (GSY-style WebVTT / sprite / frames).
  ///
  /// When null, dragging the progress bar shows time only (no thumbnail).
  final ScrubPreviewTrack? scrubPreview;

  /// 弹幕数据（由 App 注入）/ Danmaku items supplied by the host app.
  final List<DanmakuItem> danmaku;

  /// 是否显示弹幕 / Whether danmaku overlay is visible.
  final bool danmakuEnabled;

  /// 底栏发送弹幕（非 null 时显示输入框）/ Send danmaku from bottom chrome.
  final ValueChanged<String>? onDanmakuSend;

  /// 底栏弹幕开关 / Danmaku toggle on bottom chrome.
  final ValueChanged<bool>? onDanmakuEnabledChanged;

  /// 底栏外挂字幕开关 / External subtitle toggle on bottom chrome.
  final ValueChanged<bool>? onSubtitlesEnabledChanged;

  /// 外挂字幕 cues / External subtitle cues.
  final List<SubtitleCue> subtitles;

  /// 是否显示外挂字幕 / Whether external subtitles are visible.
  final bool subtitlesEnabled;

  /// 是否显示底栏截帧按钮 / Whether to show the screenshot button on chrome.
  ///
  /// Also requires [onScreenshot]; otherwise the button is hidden.
  final bool showCaptureButton;

  /// Called with PNG bytes after a successful capture. Host owns saving
  /// (gallery / file path). Plugin does not write disk or show a preview dialog.
  /// 截图成功后回调 PNG；由宿主保存（相册/路径），插件不落盘、不弹预览。
  final FutureOr<void> Function(Uint8List pngBytes)? onScreenshot;

  @override
  State<GstVideoView> createState() => _GstVideoViewState();
}

class _GstVideoViewState extends State<GstVideoView> {
  late final ImmersiveControlsState _immersive;
  int _lastMediaGeneration = -1;
  Uint8List? _lastFramePng;
  bool _capturingLastFrame = false;
  PlayerState? _lastState;

  @override
  void initState() {
    super.initState();
    _immersive = ImmersiveControlsState(
      initialAspectRatioMode: widget.aspectRatioMode,
      fullscreen: widget.fullscreen,
    );
    widget.controller.attachImmersive(_immersive);
    widget.controller.addListener(_onControllerChanged);
    _onControllerChanged();
  }

  void _onControllerChanged() {
    final generation = widget.controller.mediaGeneration;
    if (generation != _lastMediaGeneration) {
      _lastMediaGeneration = generation;
      _lastFramePng = null;
      if (generation > 0) {
        _immersive.aspectRatioMode = AspectRatioMode.fit;
      }
    }

    final state = widget.controller.state;
    if (widget.keepLastFrame &&
        state == PlayerState.completed &&
        _lastState != PlayerState.completed &&
        !_capturingLastFrame) {
      unawaited(_captureLastFrame());
    }
    if (state != PlayerState.completed && _lastFramePng != null) {
      // Cleared on replay / new media via generation; also clear when leaving completed.
      if (state == PlayerState.playing || state == PlayerState.ready) {
        _lastFramePng = null;
      }
    }
    _lastState = state;
    if (mounted) setState(() {});
  }

  Future<void> _captureLastFrame() async {
    _capturingLastFrame = true;
    try {
      // Desktop/iOS may map appsink frames; Android uses External-OES and does
      // not support mid-pipeline grab — poster / frozen surface is the cover.
      final png = await widget.controller.captureCurrentFrame();
      if (!mounted) return;
      setState(() => _lastFramePng = png);
    } catch (_) {
      // Texture/surface may already hold the frame; overlay is best-effort.
    } finally {
      _capturingLastFrame = false;
    }
  }

  @override
  void didUpdateWidget(covariant GstVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      oldWidget.controller.detachImmersive();
      widget.controller.attachImmersive(_immersive);
      widget.controller.addListener(_onControllerChanged);
      _onControllerChanged();
    }
    if (oldWidget.aspectRatioMode != widget.aspectRatioMode) {
      _immersive.aspectRatioMode = widget.aspectRatioMode;
    }
    if (oldWidget.fullscreen != widget.fullscreen) {
      _immersive.fullscreen = widget.fullscreen;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.detachImmersive();
    _immersive.dispose();
    super.dispose();
  }

  bool get _showPoster {
    if (widget.poster == null) return false;
    final state = widget.controller.state;
    if (state == PlayerState.completed && _lastFramePng != null) return false;
    if (state == PlayerState.playing || state == PlayerState.paused) {
      return false;
    }
    if (state == PlayerState.completed) return false;
    // Idle / not yet opened, or first buffering before frames.
    return widget.controller.mediaSource == null ||
        state == PlayerState.idle ||
        (state == PlayerState.buffering &&
            widget.controller.position == Duration.zero);
  }

  BiliOverlayControlsConfig? get _overlayControls {
    if (widget.onDanmakuSend == null &&
        widget.onDanmakuEnabledChanged == null &&
        widget.onSubtitlesEnabledChanged == null) {
      return null;
    }
    return BiliOverlayControlsConfig(
      danmakuEnabled: widget.danmakuEnabled,
      subtitlesEnabled: widget.subtitlesEnabled,
      onDanmakuSend: widget.onDanmakuSend,
      onDanmakuEnabledChanged: widget.onDanmakuEnabledChanged,
      onSubtitlesEnabledChanged: widget.onSubtitlesEnabledChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: widget.backgroundColor,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            ListenableBuilder(
              listenable: _immersive,
              builder: (context, _) {
                return PlaybackPresentation(
                  model: widget.controller,
                  aspectRatioMode: _immersive.aspectRatioMode,
                  controlsStyle: widget.controlsStyle,
                );
              },
            ),
            if (_showPoster && widget.poster != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Image(image: widget.poster!, fit: BoxFit.contain),
                ),
              ),
            if (_lastFramePng != null &&
                widget.controller.state == PlayerState.completed)
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.memory(_lastFramePng!, fit: BoxFit.contain),
                ),
              ),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                return DanmakuOverlay(
                  items: widget.danmaku,
                  position: widget.controller.position,
                  enabled: widget.danmakuEnabled,
                );
              },
            ),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                return SubtitleOverlay(
                  cues: widget.subtitles,
                  position: widget.controller.position,
                  enabled: widget.subtitlesEnabled,
                );
              },
            ),
            if (widget.showControls)
              VideoControls(
                model: widget.controller,
                immersive: _immersive,
                style: widget.controlsStyle,
                scrubPreview: widget.scrubPreview,
                overlayControls: _overlayControls,
                showCaptureButton: widget.showCaptureButton,
                onScreenshot: widget.onScreenshot,
              ),
          ],
        ),
      ),
    );
  }
}
