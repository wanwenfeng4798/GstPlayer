import 'package:flutter/foundation.dart';

/// Forced display aspect for the video surface / 强制显示宽高比.
enum ForcedDisplayAspect {
  /// 16:9.
  ratio16_9,

  /// 4:3.
  ratio4_3,
}

/// Bottom-chrome settings that are not native transport state /
/// 底栏设置（非 native 传输状态）.
class PlayerChromeSettings extends ChangeNotifier {
  /// Creates chrome settings / 创建设置状态.
  PlayerChromeSettings({
    bool mirrored = false,
    bool playNextOnEnd = false,
    ForcedDisplayAspect displayAspect = ForcedDisplayAspect.ratio16_9,
    bool hideBlackBars = false,
    bool lightsOff = false,
  }) {
    _mirrored = mirrored;
    _playNextOnEnd = playNextOnEnd;
    _displayAspect = displayAspect;
    _hideBlackBars = hideBlackBars;
    _lightsOff = lightsOff;
  }

  bool _mirrored = false;
  bool _playNextOnEnd = false;
  ForcedDisplayAspect _displayAspect = ForcedDisplayAspect.ratio16_9;
  bool _hideBlackBars = false;
  bool _lightsOff = false;

  /// Horizontal mirror / 水平镜像画面.
  bool get mirrored => _mirrored;
  set mirrored(bool value) {
    if (_mirrored == value) return;
    _mirrored = value;
    notifyListeners();
  }

  /// Auto-advance to next item on EOS / 播完自动切下一集.
  bool get playNextOnEnd => _playNextOnEnd;
  set playNextOnEnd(bool value) {
    if (_playNextOnEnd == value) return;
    _playNextOnEnd = value;
    notifyListeners();
  }

  /// Forced layout aspect / 强制布局宽高比.
  ForcedDisplayAspect get displayAspect => _displayAspect;
  set displayAspect(ForcedDisplayAspect value) {
    if (_displayAspect == value) return;
    _displayAspect = value;
    notifyListeners();
  }

  /// Crop letterbox bars ([AspectRatioMode.fill]) / 隐藏黑边.
  bool get hideBlackBars => _hideBlackBars;
  set hideBlackBars(bool value) {
    if (_hideBlackBars == value) return;
    _hideBlackBars = value;
    notifyListeners();
  }

  /// Lights-off / theater mode / 关灯模式.
  bool get lightsOff => _lightsOff;
  set lightsOff(bool value) {
    if (_lightsOff == value) return;
    _lightsOff = value;
    notifyListeners();
  }

  /// Numeric aspect used by presentation layout / 呈现层使用的数值比例.
  double get forcedAspectRatio => switch (_displayAspect) {
    ForcedDisplayAspect.ratio16_9 => 16 / 9,
    ForcedDisplayAspect.ratio4_3 => 4 / 3,
  };
}
