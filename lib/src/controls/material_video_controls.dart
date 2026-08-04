import 'package:flutter/material.dart';

import '../theme/video_controls_theme.dart';
import 'bili_bottom_chrome.dart';
import 'center_button.dart';
import 'immersive_controls_state.dart';
import 'playback_controls_model.dart';
import 'scrub_controller.dart';
import 'scrub_preview_controller.dart';

/// Material 风格内置视频控件栏（B 站底栏布局）/ Material controls with Bilibili bottom chrome.
class MaterialVideoControls extends StatefulWidget {
  const MaterialVideoControls({
    super.key,
    required this.model,
    required this.theme,
    required this.onInteract,
    this.showFullscreenButton = false,
    this.landscapeLocked,
    this.onFullscreenToggle,
    this.immersive,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;
  final bool showFullscreenButton;
  final bool? landscapeLocked;
  final VoidCallback? onFullscreenToggle;
  final ImmersiveControlsState? immersive;

  @override
  State<MaterialVideoControls> createState() => _MaterialVideoControlsState();
}

class _MaterialVideoControlsState extends State<MaterialVideoControls> {
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('截图'),
        content: Image.memory(png),
        actions: [
          TextButton(
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
              icons: BiliControlIcons.material,
              onCapture: _captureFrame,
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
