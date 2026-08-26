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

/// Cupertino 风格内置视频控件栏（B 站底栏布局）/ Cupertino controls with Bilibili bottom chrome.
class CupertinoVideoControls extends StatefulWidget {
  const CupertinoVideoControls({
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

  @override
  State<CupertinoVideoControls> createState() => _CupertinoVideoControlsState();
}

class _CupertinoVideoControlsState extends State<CupertinoVideoControls> {
  late final ScrubController _scrub;
  late final ScrubPreviewController _preview;

  @override
  void initState() {
    super.initState();
    _scrub = ScrubController(
      model: widget.model,
      onInteract: widget.onInteract,
    );
    _preview = ScrubPreviewController();
  }

  @override
  void dispose() {
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
                icons: BiliControlIcons.cupertino,
                showFullscreenButton: widget.showFullscreenButton,
                landscapeLocked: landscapeLocked,
                onFullscreenToggle: widget.onFullscreenToggle,
              ),
          ],
        );
      },
    );
  }
}
