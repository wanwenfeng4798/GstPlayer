import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/video_controls_theme.dart';
import 'playback_controls_model.dart';

/// Compact volume track next to the mute button / 静音按钮旁的紧凑音量滑轨。
class VolumeSlider extends StatelessWidget {
  /// Creates a volume slider / 创建音量滑轨.
  const VolumeSlider({
    super.key,
    required this.model,
    required this.theme,
    required this.onInteract,
    this.cupertino = false,
    this.width = 72,
  });

  final PlaybackControlsModel model;
  final VideoControlsTheme theme;
  final VoidCallback onInteract;
  final bool cupertino;
  final double width;

  @override
  Widget build(BuildContext context) {
    final value = model.muted ? 0.0 : model.volume.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      child: cupertino
          ? CupertinoSlider(
              value: value,
              activeColor: theme.activeTrackColor,
              thumbColor: theme.thumbColor,
              onChanged: (v) {
                onInteract();
                model.setVolume(v);
              },
            )
          : SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.activeTrackColor,
                inactiveTrackColor: theme.inactiveTrackColor,
                thumbColor: theme.thumbColor,
                trackHeight: 3,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
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
    );
  }
}
