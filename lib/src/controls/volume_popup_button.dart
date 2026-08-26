import 'package:material_ui/material_ui.dart';

import '../theme/video_controls_theme.dart';
import 'playback_controls_model.dart';

/// Bilibili-style volume: speaker icon opens a vertical pink slider popup.
class VolumePopupButton extends StatefulWidget {
  /// Creates a volume popup button / 创建音量弹出按钮.
  const VolumePopupButton({
    super.key,
    required this.model,
    required this.theme,
    required this.onInteract,
    required this.volumeOnIcon,
    required this.volumeOffIcon,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;
  final IconData volumeOnIcon;
  final IconData volumeOffIcon;

  @override
  State<VolumePopupButton> createState() => _VolumePopupButtonState();
}

class _VolumePopupButtonState extends State<VolumePopupButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _open = false;

  @override
  void dispose() {
    _removeOverlay(notify: false);
    super.dispose();
  }

  void _removeOverlay({bool notify = true}) {
    _entry?.remove();
    _entry = null;
    if (_open) {
      _open = false;
      if (notify && mounted) setState(() {});
    }
  }

  void _toggle() {
    widget.onInteract();
    if (_open) {
      _removeOverlay();
      return;
    }
    _entry = OverlayEntry(
      builder: (context) {
        // No full-screen barrier: a modal barrier was swallowing play/pause
        // taps and could leave the UI feeling "dead" after volume use.
        return UnconstrainedBox(
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -8),
            child: TapRegion(
              onTapOutside: (_) => _removeOverlay(),
              child: _VolumePopupPanel(
                model: widget.model,
                theme: widget.theme,
                onInteract: widget.onInteract,
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: ListenableBuilder(
        listenable: widget.model,
        builder: (context, _) {
          final muted = widget.model.muted || widget.model.volume == 0;
          return IconButton(
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            color: widget.theme.iconColor,
            icon: Icon(
              muted ? widget.volumeOffIcon : widget.volumeOnIcon,
              size: widget.theme.secondaryIconSize,
            ),
            onPressed: _toggle,
            onLongPress: () {
              widget.onInteract();
              widget.model.toggleMuted();
            },
          );
        },
      ),
    );
  }
}

class _VolumePopupPanel extends StatelessWidget {
  const _VolumePopupPanel({
    required this.model,
    required this.theme,
    required this.onInteract,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE6000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          width: 52,
          height: 148,
          child: ListenableBuilder(
            listenable: model,
            builder: (context, _) {
              final value = model.muted ? 0.0 : model.volume.clamp(0.0, 1.0);
              final percent = (value * 100).round();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      '$percent',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.activeTrackColor,
                          inactiveTrackColor: theme.inactiveTrackColor,
                          thumbColor: theme.thumbColor,
                          trackHeight: 3,
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Slider(
                          value: value,
                          onChanged: (v) {
                            onInteract();
                            model.setVolume(v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
