import 'package:flutter/cupertino.dart';

import '../theme/video_controls_theme.dart';
import 'bili_bottom_chrome.dart';
import 'center_button.dart';
import 'immersive_controls_state.dart';
import 'playback_controls_model.dart';
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
    required this.onInteract,
    this.scrubPreview,
    this.overlayControls,
    this.showCaptureButton = true,
    this.showFullscreenButton = false,
    this.landscapeLocked,
    this.onFullscreenToggle,
    this.immersive,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;
  final ScrubPreviewTrack? scrubPreview;
  final BiliOverlayControlsConfig? overlayControls;
  final bool showCaptureButton;
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
      return Listenable.merge([widget.model, immersive]);
    }
    return widget.model;
  }

  Future<void> _captureFrame() async {
    widget.onInteract();
    final png = await widget.model.captureFramePng();
    if (!mounted || png == null) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('截图'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Image.memory(png),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
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
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.center,
              child: CenterButton(
                model: model,
                theme: theme,
                onInteract: widget.onInteract,
                hud: widget.immersive?.hud,
              ),
            ),
            BiliBottomChrome(
              model: model,
              theme: theme,
              onInteract: widget.onInteract,
              scrub: _scrub,
              preview: _preview,
              scrubPreview: widget.scrubPreview,
              overlayControls: widget.overlayControls,
              icons: BiliControlIcons.cupertino,
              onCapture: widget.showCaptureButton ? _captureFrame : null,
              showCaptureButton: widget.showCaptureButton,
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
