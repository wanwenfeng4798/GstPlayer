import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'immersive_controls_state.dart';
import 'playback_controls_model.dart';

/// 左区宽度比例（亮度）/ Left zone width ratio for brightness.
const _leftZoneRatio = 0.4;

/// 右区起始宽度比例（音量）/ Right zone start ratio for volume.
const _rightZoneRatio = 0.6;

/// 水平 seek 触发最小位移（逻辑像素）/ Minimum horizontal drag for seek.
const _seekDragThreshold = 48.0;

/// 由水平拖拽距离计算 seek 秒数（与 HUD 预览一致）/ Seek seconds from horizontal drag.
double seekSecondsFromDrag({
  required double horizontalDrag,
  required double width,
  required int maxStepSeconds,
}) {
  final maxStep = maxStepSeconds.toDouble();
  return (horizontalDrag / width * maxStep * 3).clamp(-maxStep, maxStep);
}

/// 移动端沉浸手势层：分区亮度/音量、水平进退 / Mobile immersive gestures: brightness, volume, seek.
///
/// 全屏与非全屏均挂载；与顶栏 [ImmersiveControlsState.immersiveActive] 无关。
/// Mounted for both fullscreen and inline; independent of [ImmersiveControlsState.immersiveActive].
class ImmersiveGestureLayer extends StatefulWidget {
  /// 创建手势层 / Creates the gesture layer.
  const ImmersiveGestureLayer({
    super.key,
    required this.immersive,
    required this.model,
    required this.onTap,
  });

  /// 沉浸控件状态 / Immersive controls state.
  final ImmersiveControlsState immersive;

  /// 播放控制 model / Playback controls model.
  final PlaybackControlsModel model;

  /// 单击切换控件栏可见性 / Tap toggles control bar visibility.
  final VoidCallback onTap;

  @override
  State<ImmersiveGestureLayer> createState() => _ImmersiveGestureLayerState();
}

enum _GestureZone { left, center, right }

class _ImmersiveGestureLayerState extends State<ImmersiveGestureLayer> {
  Offset? _panStart;
  _GestureZone? _zone;
  double _horizontalDrag = 0;
  bool _axisResolved = false;
  bool _isHorizontal = false;
  double? _brightnessBaseline;
  double? _volumeBaseline;
  double _lastKnownBrightness = 1.0;

  _GestureZone _zoneFor(double x, double width) {
    if (x < width * _leftZoneRatio) return _GestureZone.left;
    if (x > width * _rightZoneRatio) return _GestureZone.right;
    return _GestureZone.center;
  }

  Future<void> _ensureBrightnessBaseline() async {
    try {
      final value = await ScreenBrightness.instance.application;
      _lastKnownBrightness = value.clamp(0.0, 1.0);
      _brightnessBaseline ??= _lastKnownBrightness;
    } catch (_) {
      _brightnessBaseline ??= _lastKnownBrightness;
    }
  }

  Future<void> _setBrightness(double brightness) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        brightness,
      );
    } catch (_) {
      // Platform may reject; HUD still reflects intended value.
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.immersive.controlsLocked) return;
    final width = context.size?.width;
    if (width == null) return;

    _panStart = details.localPosition;
    _zone = _zoneFor(details.localPosition.dx, width);
    _horizontalDrag = 0;
    _axisResolved = false;
    _isHorizontal = false;
    _volumeBaseline = widget.model.volume;
    // Immediate fallback so the first vertical updates are not dropped.
    _brightnessBaseline ??= _lastKnownBrightness;
    unawaited(_ensureBrightnessBaseline());
  }

  void _previewHorizontalSeek(double width) {
    final stepSeconds = widget.immersive.fullscreen.seekStep.seconds;
    final seconds = seekSecondsFromDrag(
      horizontalDrag: _horizontalDrag,
      width: width,
      maxStepSeconds: stepSeconds,
    );
    if (seconds.abs() >= 0.5) {
      widget.immersive.showHud(
        ImmersiveHudSnapshot(
          kind: ImmersiveHudKind.seek,
          value: seconds.abs(),
          forward: seconds > 0,
          gesture: true,
        ),
      );
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final start = _panStart;
    final size = context.size;
    if (start == null || size == null) return;

    final delta = details.localPosition - start;

    if (!_axisResolved && delta.distance > 8) {
      _axisResolved = true;
      _isHorizontal = delta.dx.abs() >= delta.dy.abs();
    }
    if (!_axisResolved) return;

    if (_isHorizontal) {
      if (!widget.model.isSeekable) return;
      _horizontalDrag += details.delta.dx;
      _previewHorizontalSeek(size.width);
      return;
    }

    final zone = _zone ?? _zoneFor(start.dx, size.width);
    final deltaNorm = (-delta.dy / size.height).clamp(-1.0, 1.0);

    switch (zone) {
      case _GestureZone.left:
        final base = _brightnessBaseline ?? _lastKnownBrightness;
        final brightness = (base + deltaNorm * 0.5).clamp(0.0, 1.0);
        _lastKnownBrightness = brightness;
        unawaited(_setBrightness(brightness));
        widget.immersive.showHud(
          ImmersiveHudSnapshot(
            kind: ImmersiveHudKind.brightness,
            value: brightness,
          ),
        );
      case _GestureZone.right:
        final base = _volumeBaseline ?? widget.model.volume;
        final volume = (base + deltaNorm * 0.5).clamp(0.0, 1.0);
        unawaited(widget.model.setVolume(volume));
        widget.immersive.showHud(
          ImmersiveHudSnapshot(kind: ImmersiveHudKind.volume, value: volume),
        );
      case _GestureZone.center:
        break;
    }
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    final size = context.size;
    if (_isHorizontal &&
        widget.model.isSeekable &&
        _horizontalDrag.abs() >= _seekDragThreshold &&
        size != null) {
      final stepSeconds = widget.immersive.fullscreen.seekStep.seconds;
      final seconds = seekSecondsFromDrag(
        horizontalDrag: _horizontalDrag,
        width: size.width,
        maxStepSeconds: stepSeconds,
      );
      if (seconds.abs() >= 0.5) {
        final forward = seconds > 0;
        final position = widget.model.position;
        final duration = widget.model.duration;
        final delta = Duration(seconds: seconds.abs().round());
        final target = forward ? position + delta : position - delta;
        final clamped = Duration(
          milliseconds: math.max(
            0,
            math.min(target.inMilliseconds, duration.inMilliseconds),
          ),
        );
        await widget.model.seek(clamped);
        widget.immersive.showHud(
          ImmersiveHudSnapshot(
            kind: ImmersiveHudKind.seek,
            value: seconds.abs(),
            forward: forward,
            gesture: true,
          ),
        );
      }
    }

    _panStart = null;
    _zone = null;
    _horizontalDrag = 0;
    _axisResolved = false;
    _isHorizontal = false;
    _brightnessBaseline = null;
    _volumeBaseline = null;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: widget.immersive,
        builder: (context, _) {
          final locked = widget.immersive.controlsLocked;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTap,
            onDoubleTap: locked
                ? null
                : () async {
                    final wasPlaying = widget.model.isPlaying;
                    await widget.model.togglePlayPause();
                    widget.immersive.showHud(
                      ImmersiveHudSnapshot(
                        kind: ImmersiveHudKind.playPause,
                        value: wasPlaying ? 0.0 : 1.0,
                      ),
                    );
                  },
            onPanStart: locked ? null : _onPanStart,
            onPanUpdate: locked ? null : _onPanUpdate,
            onPanEnd: locked ? null : _onPanEnd,
          );
        },
      ),
    );
  }
}
