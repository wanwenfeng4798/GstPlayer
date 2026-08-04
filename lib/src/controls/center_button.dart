import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/player_events.dart';
import '../theme/video_controls_theme.dart';
import 'immersive_controls_state.dart';
import 'playback_controls_model.dart';

/// 两种控件风格共用的中央播放/暂停/缓冲 affordance / Central play/pause/buffering affordance shared by both control styles.
///
/// 缓冲中隐藏大按钮（由进度条与 presentation 层指示）；否则显示磨砂圆形播放/暂停。
/// Hidden during buffering (progress/presentation indicate loading); otherwise shows a frosted play/pause.
class CenterButton extends StatelessWidget {
  const CenterButton({
    super.key,
    required this.model,
    required this.theme,
    required this.onInteract,
    this.hud,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;

  /// 沉浸 HUD；与正中 playPause HUD 重叠时隐藏按钮 / Hides button while center playPause HUD is shown.
  final ImmersiveHudSnapshot? hud;

  /// Only the play/pause HUD replaces the center control; volume/brightness/seek
  /// HUDs must not leave a hit-blocking empty box over the button.
  static bool _hideForHud(ImmersiveHudSnapshot snap) =>
      snap.kind == ImmersiveHudKind.playPause;

  /// Placeholder that does not absorb taps (gestures/chrome below stay usable).
  Widget _passThroughPlaceholder() {
    return IgnorePointer(
      child: SizedBox(
        width: theme.centerButtonSize,
        height: theme.centerButtonSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final snap = hud;
        if (snap != null && _hideForHud(snap)) {
          return _passThroughPlaceholder();
        }
        final PlayerState state = model.state;
        final buffering = model.bufferingPercent;
        if (buffering < 100 || state == PlayerState.buffering) {
          return _passThroughPlaceholder();
        }
        // Use isPlaying (respects in-flight want) so the icon matches the
        // bottom chrome and rapid toggles do not show a stale PlayerState.
        final playing = model.isPlaying;
        final icon = playing
            ? CupertinoIcons.pause_solid
            : CupertinoIcons.play_arrow_solid;
        return SizedBox(
          width: theme.centerButtonSize,
          height: theme.centerButtonSize,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.backgroundColor,
                ),
                child: IconButton(
                  onPressed: () {
                    onInteract();
                    // Fire-and-forget: do not await so rapid taps are not serialized
                    // behind each native round-trip.
                    model.togglePlayPause();
                  },
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    icon,
                    size: theme.primaryIconSize,
                    color: theme.iconColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
