import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../l10n/gst_player_strings.dart';
import '../theme/video_controls_theme.dart';
import 'bili_bottom_chrome.dart';
import 'bili_chrome_video_controls.dart';
import 'immersive_controls_state.dart';
import 'playback_controls_model.dart';
import 'player_chrome_settings.dart';
import 'scrub_preview_track.dart';
import 'bili_overlay_controls.dart';

/// Material 风格内置视频控件栏（B 站底栏布局）/ Material controls with Bilibili bottom chrome.
class MaterialVideoControls extends StatelessWidget {
  const MaterialVideoControls({
    super.key,
    required this.model,
    required this.theme,
    required this.strings,
    required this.settings,
    required this.onInteract,
    this.scrubPreview,
    this.overlayControls,
    this.showFullscreenButton = true,
    this.landscapeLocked,
    this.onFullscreenToggle,
    this.immersive,
    this.showCaptureButton = true,
    this.onScreenshot,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final GstPlayerStrings strings;
  final PlayerChromeSettings settings;
  final VoidCallback onInteract;
  final ScrubPreviewTrack? scrubPreview;
  final BiliOverlayControlsConfig? overlayControls;
  final bool showFullscreenButton;
  final bool? landscapeLocked;
  final VoidCallback? onFullscreenToggle;
  final ImmersiveControlsState? immersive;
  final bool showCaptureButton;
  final Future<void> Function(Uint8List pngBytes)? onScreenshot;

  @override
  Widget build(BuildContext context) {
    return BiliChromeVideoControls(
      model: model,
      theme: theme,
      strings: strings,
      settings: settings,
      onInteract: onInteract,
      icons: BiliControlIcons.material,
      scrubPreview: scrubPreview,
      overlayControls: overlayControls,
      showFullscreenButton: showFullscreenButton,
      landscapeLocked: landscapeLocked,
      onFullscreenToggle: onFullscreenToggle,
      immersive: immersive,
      showCaptureButton: showCaptureButton,
      onScreenshot: onScreenshot,
    );
  }
}
