import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../l10n/gst_player_strings.dart';
import '../theme/video_controls_theme.dart';
import 'immersive_controls_state.dart';

/// 中央播放键同一水平线最右侧的锁屏/解锁按钮 / Side lock on the same row as the center play button.
class ControlsLockButton extends StatelessWidget {
  /// 创建锁屏按钮 / Creates the controls lock button.
  const ControlsLockButton({
    super.key,
    required this.immersive,
    required this.theme,
    required this.strings,
    required this.onInteract,
  });

  /// 沉浸控件状态 / Immersive controls state.
  final ImmersiveControlsState immersive;

  /// 控件主题 / Controls theme.
  final VideoControlsTheme theme;

  /// 锁屏/解锁 tooltip 文案 / Lock/unlock tooltip copy.
  final GstPlayerStrings strings;

  /// 交互时保持控件栏可见 / Keeps chrome visible on interact.
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: immersive,
      builder: (context, _) {
        final locked = immersive.controlsLocked;
        final size = theme.centerButtonSize * 0.75;
        return SizedBox(
          key: const ValueKey('video-controls-lock-button'),
          width: size,
          height: size,
          child: Material(
            color: Colors.transparent,
            child: Tooltip(
              message: locked ? strings.unlockControls : strings.lockControls,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: InkWell(
                    onTap: () {
                      onInteract();
                      immersive.controlsLocked = !locked;
                    },
                    child: ColoredBox(
                      color: theme.backgroundColor,
                      child: Center(
                        child: Icon(
                          locked ? Icons.lock_open : Icons.lock_outline,
                          size: theme.secondaryIconSize,
                          color: theme.iconColor,
                        ),
                      ),
                    ),
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
