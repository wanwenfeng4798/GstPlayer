import 'package:flutter/material.dart';

import 'playback_controls_model.dart';
import 'scrub_controller.dart';

/// 传给 [PlaybackProgressSlider] 皮肤 builder 的快照 / Snapshot passed to [PlaybackProgressSlider] skin builders.
class PlaybackSliderSnapshot {
  const PlaybackSliderSnapshot({
    required this.displayValue,
    required this.enabled,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  /// 滑块显示值 0.0–1.0 / Slider display value 0.0–1.0.
  final double displayValue;

  /// 是否可 seek / Whether seeking is enabled.
  final bool enabled;

  final VoidCallback? onSeekStart;

  final ValueChanged<double>? onSeekChanged;

  final ValueChanged<double>? onSeekEnd;
}

/// Material/Cupertino 进度条皮肤 builder 类型 / Builder type for Material/Cupertino progress slider skins.
typedef PlaybackProgressSliderBuilder =
    Widget Function(BuildContext context, PlaybackSliderSnapshot snapshot);

/// 共享进度条接线：[Listenable]、[ScrubController] 钉住与落定动画 / Shared progress slider wiring: listenables, scrub pinning, settle animation.
class PlaybackProgressSlider extends StatelessWidget {
  const PlaybackProgressSlider({
    super.key,
    required this.model,
    required this.scrub,
    required this.builder,
  });

  final PlaybackControlsModel model;
  final ScrubController scrub;
  final PlaybackProgressSliderBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([model, scrub]),
      builder: (context, _) {
        final dur = model.duration.inMilliseconds.toDouble();
        final pos = model.position.inMilliseconds.toDouble();
        final seekable = model.isSeekable;
        final enabled = seekable && dur > 0;
        final value = scrub.sliderValue(dur, pos);

        PlaybackSliderSnapshot snapshotFor(double v) {
          return PlaybackSliderSnapshot(
            displayValue: v,
            enabled: enabled,
            onSeekStart: enabled ? scrub.onSeekStart : null,
            onSeekChanged: enabled
                ? (fraction) => scrub.onSeekChanged(fraction, dur)
                : null,
            onSeekEnd: enabled
                ? (fraction) => scrub.onSeekEnd(fraction, dur)
                : null,
          );
        }

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value),
          duration: scrub.isScrubbing
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.linear,
          builder: (context, animatedValue, _) => builder(
            context,
            snapshotFor(scrub.isScrubbing ? value : animatedValue),
          ),
        );
      },
    );
  }
}
