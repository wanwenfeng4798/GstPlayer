import 'package:flutter/foundation.dart';

/// Bilibili-style danmaku / external-subtitle bar on the bottom chrome /
/// B 站风格底栏：弹幕输入与外挂字幕开关.
class BiliOverlayControlsConfig {
  /// Creates overlay bar config / 创建叠层控件配置.
  const BiliOverlayControlsConfig({
    required this.danmakuEnabled,
    required this.subtitlesEnabled,
    this.onDanmakuEnabledChanged,
    this.onSubtitlesEnabledChanged,
    this.onDanmakuSend,
    this.danmakuHint = '发个友善的弹幕见证下',
  });

  final bool danmakuEnabled;
  final bool subtitlesEnabled;
  final ValueChanged<bool>? onDanmakuEnabledChanged;
  final ValueChanged<bool>? onSubtitlesEnabledChanged;
  final ValueChanged<String>? onDanmakuSend;
  final String danmakuHint;

  bool get showDanmakuInput => onDanmakuSend != null;
  bool get showDanmakuToggle => onDanmakuEnabledChanged != null;
  bool get showSubtitlesToggle => onSubtitlesEnabledChanged != null;
}
