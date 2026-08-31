import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'playback_controls_model.dart';

/// 内置进度条拖拽与 seek 处理 / Drag/seek handling for built-in progress sliders.
///
/// 拖拽时滑块钉在手指位置；松手后保持至 [PlaybackControlsModel.position] 追上（或安全超时），
/// 避免异步 seek 期间 thumb 弹回旧位置。
/// While dragging the slider pins to the finger; on release it stays pinned until
/// [PlaybackControlsModel.position] catches up (or safety timeout), preventing thumb bounce during async seek.
class ScrubController extends ChangeNotifier {
  /// 创建 scrub 控制器 / Creates a scrub controller.
  ScrubController({required this.model, required this.onInteract}) {
    model.addListener(_checkSeekSettled);
  }

  /// 拖拽安全超时（毫秒）/ Drag safety timeout in milliseconds.
  static const dragSafetyMs = 300;

  /// seek 落定超时（毫秒）/ Seek settle timeout in milliseconds.
  static const seekSettleMs = 3000;

  final PlaybackControlsModel model;
  final VoidCallback onInteract;

  double? _dragValue;
  bool _dragging = false;
  bool _seeking = false;
  Timer? _seekTimeout;

  double _seekToleranceMs(double durMs) =>
      math.max(2500.0, durMs * 0.05);

  bool _isNearPosition(double fraction, double durMs, double posMs) {
    if (durMs <= 0) return true;
    return (posMs - fraction * durMs).abs() <= _seekToleranceMs(durMs);
  }

  void _checkSeekSettled() {
    final target = _dragValue;
    final dur = model.duration.inMilliseconds.toDouble();
    final pos = model.position.inMilliseconds.toDouble();
    if (target == null || dur <= 0) return;
    if (!_isNearPosition(target, dur, pos)) return;
    if (_seeking || !_dragging) {
      _clearSeek();
    }
  }

  void _clearSeek() {
    _seekTimeout?.cancel();
    _seekTimeout = null;
    _dragging = false;
    _seeking = false;
    if (_dragValue != null) {
      _dragValue = null;
      notifyListeners();
    }
  }

  void _armDragSafetyTimeout() {
    _seekTimeout?.cancel();
    _seekTimeout = Timer(const Duration(milliseconds: dragSafetyMs), () {
      if (_dragging && !_seeking) _clearSeek();
    });
  }

  void _armSeekSettleTimeout() {
    _seekTimeout?.cancel();
    _seekTimeout = Timer(
      const Duration(milliseconds: seekSettleMs),
      _clearSeek,
    );
  }

  /// 滑块当前应显示的 0.0–1.0 分数 / Fraction 0.0–1.0 the slider should display.
  double sliderValue(double durMs, double posMs) {
    final target = _dragValue;
    if (target != null) return target;
    return durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
  }

  /// 用户是否在拖拽或异步 seek 尚未落定 / Whether user is dragging or async seek is settling.
  bool get isScrubbing => _dragValue != null;

  /// 开始拖拽 / Seek drag started.
  void onSeekStart() {
    onInteract();
    _dragging = true;
    _armDragSafetyTimeout();
  }

  /// 拖拽中分数变化 / Fraction changed while dragging.
  void onSeekChanged(double v, double durMs) {
    if (durMs <= 0) return;
    _dragging = true;
    onInteract();
    _dragValue = v;
    notifyListeners();
    _armDragSafetyTimeout();
  }

  /// 松手并发起 seek / Drag ended; initiates seek.
  void onSeekEnd(double v, double durMs) {
    if (durMs <= 0) return;
    _dragging = false;
    _dragValue = v;
    notifyListeners();
    final pos = model.position.inMilliseconds.toDouble();
    if (_isNearPosition(v, durMs, pos)) {
      _clearSeek();
      return;
    }
    _seeking = true;
    model.seek(Duration(milliseconds: (v * durMs).round()));
    _armSeekSettleTimeout();
  }

  /// 重置拖拽/seek 状态（切源时调用）/ Clears drag/seek state (call on media switch).
  void reset() {
    _clearSeek();
  }

  /// 解除 model 监听并释放 / Removes model listener and disposes.
  @override
  void dispose() {
    _seekTimeout?.cancel();
    model.removeListener(_checkSeekSettled);
    super.dispose();
  }
}
