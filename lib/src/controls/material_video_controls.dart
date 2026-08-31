import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../l10n/gst_player_strings.dart';
import '../theme/video_controls_theme.dart';
import 'bili_bottom_chrome.dart';
import 'center_button.dart';
import 'controls_lock_button.dart';
import 'immersive_controls_state.dart';
import 'playback_controls_model.dart';
import 'player_chrome_settings.dart';
import 'scrub_controller.dart';
import 'scrub_preview_controller.dart';
import 'scrub_preview_track.dart';
import 'bili_overlay_controls.dart';

/// Material 风格内置视频控件栏（B 站底栏布局）/ Material controls with Bilibili bottom chrome.
class MaterialVideoControls extends StatefulWidget {
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
  State<MaterialVideoControls> createState() => _MaterialVideoControlsState();
}

class _MaterialVideoControlsState extends State<MaterialVideoControls> {
  late final ScrubController _scrub;
  late final ScrubPreviewController _preview;
  int _lastMediaGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrub = ScrubController(
      model: widget.model,
      onInteract: widget.onInteract,
    );
    _preview = ScrubPreviewController();
    _lastMediaGeneration = widget.model.mediaGeneration;
    widget.model.addListener(_onMediaGenerationChanged);
  }

  void _onMediaGenerationChanged() {
    final gen = widget.model.mediaGeneration;
    if (gen != _lastMediaGeneration) {
      _lastMediaGeneration = gen;
      _scrub.reset();
      _preview.clear();
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_onMediaGenerationChanged);
    _scrub.dispose();
    _preview.dispose();
    super.dispose();
  }

  Listenable get _listenable {
    final immersive = widget.immersive;
    if (immersive != null) {
      return Listenable.merge([widget.model, immersive, widget.settings]);
    }
    return Listenable.merge([widget.model, widget.settings]);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final theme = widget.theme;
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        final landscapeLocked =
            widget.immersive?.landscapeLocked ?? widget.landscapeLocked;
        final immersive = widget.immersive;
        final controlsLocked = immersive?.controlsLocked ?? false;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (!controlsLocked)
              Align(
                alignment: Alignment.center,
                child: CenterButton(
                  model: model,
                  theme: theme,
                  onInteract: widget.onInteract,
                  hud: immersive?.hud,
                ),
              ),
            if (immersive != null)
              Align(
                alignment: Alignment.centerRight,
                child: SafeArea(
                  left: false,
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ControlsLockButton(
                      immersive: immersive,
                      theme: theme,
                      strings: widget.strings,
                      onInteract: widget.onInteract,
                    ),
                  ),
                ),
              ),
            if (!controlsLocked)
              BiliBottomChrome(
                model: model,
                theme: theme,
                strings: widget.strings,
                settings: widget.settings,
                onInteract: widget.onInteract,
                scrub: _scrub,
                preview: _preview,
                scrubPreview: widget.scrubPreview,
                overlayControls: widget.overlayControls,
                icons: BiliControlIcons.material,
                showFullscreenButton: widget.showFullscreenButton,
                landscapeLocked: landscapeLocked,
                onFullscreenToggle: widget.onFullscreenToggle,
                showCaptureButton: widget.showCaptureButton,
                onScreenshot: widget.onScreenshot,
              ),
          ],
        );
      },
    );
  }
}
