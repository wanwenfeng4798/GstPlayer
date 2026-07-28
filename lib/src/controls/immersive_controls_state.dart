import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/player_events.dart';
import '../utils/platform_util.dart';
import 'fullscreen_config.dart';

/// 沉浸 HUD 反馈类型 / Kind of transient immersive HUD feedback.
enum ImmersiveHudKind {
  /// 进退预览 / Seek preview.
  seek,

  /// 亮度调节 / Brightness adjustment.
  brightness,

  /// 音量调节 / Volume adjustment.
  volume,

  /// 播放/暂停 / Play or pause toggle.
  playPause,
}

/// 沉浸 HUD 瞬时快照 / Transient immersive HUD snapshot.
class ImmersiveHudSnapshot {
  /// 创建 HUD 快照 / Creates a HUD snapshot.
  const ImmersiveHudSnapshot({
    required this.kind,
    required this.value,
    this.forward = true,
    this.gesture = false,
  });

  /// 反馈类型 / Feedback kind.
  final ImmersiveHudKind kind;

  /// 数值：秒数偏移、亮度或音量 0–1 / Value: seek seconds, brightness, or volume.
  final double value;

  /// 进退方向；仅 [ImmersiveHudKind.seek] 使用 / Seek direction; seek only.
  final bool forward;

  /// 是否是手势滑动触发 / Whether triggered by gesture drag.
  final bool gesture;
}

/// 沉浸控件状态单一数据源 / Single source of truth for immersive control state.
///
/// 由 [GstVideoView] 创建并 [dispose]；[VideoControls] 与子组件读取/写入。
/// Created and disposed by [GstVideoView]; read/written by [VideoControls] and children.
class ImmersiveControlsState extends ChangeNotifier {
  /// 创建沉浸状态 / Creates immersive state.
  ImmersiveControlsState({
    required AspectRatioMode initialAspectRatioMode,
    required VideoControlsFullscreenConfig fullscreen,
  }) : // Public ctor name is [fullscreen]; field is private and mutable via setter.
       // ignore: prefer_initializing_formals
       _fullscreen = fullscreen,
       _aspectRatioMode = initialAspectRatioMode;

  VideoControlsFullscreenConfig _fullscreen;
  bool _landscapeLocked = false;
  AspectRatioMode _aspectRatioMode;
  ImmersiveHudSnapshot? _hud;

  /// 沉浸配置 / Immersive configuration (updatable at runtime).
  VideoControlsFullscreenConfig get fullscreen => _fullscreen;
  set fullscreen(VideoControlsFullscreenConfig value) {
    if (_fullscreen == value) return;
    _fullscreen = value;
    notifyListeners();
  }

  /// 移动端横屏锁定 / Mobile landscape lock (fullscreen).
  bool get landscapeLocked => _landscapeLocked;
  set landscapeLocked(bool value) {
    if (_landscapeLocked == value) return;
    _landscapeLocked = value;
    notifyListeners();
  }

  /// 当前铺满模式 / Current aspect ratio mode.
  AspectRatioMode get aspectRatioMode => _aspectRatioMode;
  set aspectRatioMode(AspectRatioMode value) {
    if (_aspectRatioMode == value) return;
    _aspectRatioMode = value;
    notifyListeners();
  }

  /// 瞬时 HUD；`null` 为隐藏 / Transient HUD; null when hidden.
  ImmersiveHudSnapshot? get hud => _hud;
  set hud(ImmersiveHudSnapshot? value) {
    if (_hud == value) return;
    _hud = value;
    notifyListeners();
  }

  /// 沉浸能力是否激活 / Whether immersive features are active.
  bool get immersiveActive => isMobilePlatform
      ? _landscapeLocked
      : _fullscreen.desktopImmersive;

  Timer? _hudTimer;

  /// 显示 HUD 并在 1 秒后自动隐藏 / Shows HUD and auto-hides after 1 second.
  void showHud(ImmersiveHudSnapshot snap) {
    _hud = snap;
    notifyListeners();
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(seconds: 1), () {
      _hud = null;
      notifyListeners();
    });
  }

  /// 释放定时器与监听 / Disposes timer and listeners.
  @override
  void dispose() {
    _hudTimer?.cancel();
    super.dispose();
  }
}
