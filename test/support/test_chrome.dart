import 'package:gstplayer/src/controls/player_chrome_settings.dart';
import 'package:gstplayer/src/controls/video_controls.dart';
import 'package:gstplayer/src/controls/immersive_controls_state.dart';
import 'package:gstplayer/src/controls/playback_controls_model.dart';
import 'package:gstplayer/src/l10n/gst_player_language.dart';
import 'package:gstplayer/src/l10n/gst_player_strings.dart';

/// Default zh strings for widget tests / 测试用中文文案.
final testStringsZh = GstPlayerStrings.of(GstPlayerLanguage.zh);

/// Default en strings for widget tests / 测试用英文文案.
final testStringsEn = GstPlayerStrings.of(GstPlayerLanguage.en);

/// Builds [VideoControls] with zh copy and the given [settings] /
/// 构造带中文案的控件 overlay.
VideoControls testVideoControls({
  required PlaybackControlsModel model,
  required ImmersiveControlsState immersive,
  required PlayerChromeSettings settings,
  Duration autoHide = const Duration(seconds: 3),
}) {
  return VideoControls(
    model: model,
    immersive: immersive,
    strings: testStringsZh,
    settings: settings,
    autoHide: autoHide,
  );
}
