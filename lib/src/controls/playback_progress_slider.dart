import 'package:material_ui/material_ui.dart';

import 'playback_controls_model.dart';
import 'scrub_controller.dart';

/// 传给 [PlaybackProgressSlider] 皮肤 builder 的快照 / Snapshot passed to [PlaybackProgressSlider] skin builders.
class PlaybackSliderSnapshot {
  const PlaybackSliderSnapshot({
    required this.displayValue,
    required this.enabled,
    required this.canSeek,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  /// 滑块显示值 0.0–1.0 / Slider display value 0.0–1.0.
  final double displayValue;

  /// 是否有时长信息，可绘制已播放进度 / Whether a timeline exists for progress paint.
  final bool enabled;

  /// 是否允许拖拽 seek / Whether scrubbing seeks playback.
  final bool canSeek;

  final VoidCallback? onSeekStart;

  final ValueChanged<double>? onSeekChanged;

  final ValueChanged<double>? onSeekEnd;
}

/// Material/Cupertino 进度条皮肤 builder 类型 / Builder type for Material/Cupertino progress slider skins.
typedef PlaybackProgressSliderBuilder =
    Widget Function(BuildContext context, PlaybackSliderSnapshot snapshot);

/// 共享进度条接线：[Listenable]、[ScrubController] 钉住与落定动画 / Shared progress slider wiring: listenables, scrub pinning, settle animation.
class PlaybackProgressSlider extends StatefulWidget {
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
  State<PlaybackProgressSlider> createState() => _PlaybackProgressSliderState();
}

class _PlaybackProgressSliderState extends State<PlaybackProgressSlider> {
  int _lastPosMs = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.model, widget.scrub]),
      builder: (context, _) {
        final dur = widget.model.duration.inMilliseconds.toDouble();
        final pos = widget.model.position.inMilliseconds.toDouble();
        final hasTimeline = dur > 0;
        final canSeek = widget.model.isSeekable && hasTimeline;
        final value = widget.scrub.sliderValue(dur, pos);

        final posMs = pos.round();
        final jumpMs = (posMs - _lastPosMs).abs();
        _lastPosMs = posMs;
        final skipTween = !widget.scrub.isScrubbing && jumpMs > 5000;

        PlaybackSliderSnapshot snapshotFor(double v) {
          return PlaybackSliderSnapshot(
            displayValue: v,
            enabled: hasTimeline,
            canSeek: canSeek,
            onSeekStart: canSeek ? widget.scrub.onSeekStart : null,
            onSeekChanged: canSeek
                ? (fraction) => widget.scrub.onSeekChanged(fraction, dur)
                : null,
            onSeekEnd: canSeek
                ? (fraction) => widget.scrub.onSeekEnd(fraction, dur)
                : null,
          );
        }

        if (widget.scrub.isScrubbing || skipTween) {
          return widget.builder(context, snapshotFor(value));
        }

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value),
          duration: const Duration(milliseconds: 200),
          curve: Curves.linear,
          builder: (context, animatedValue, _) => widget.builder(
            context,
            snapshotFor(animatedValue),
          ),
        );
      },
    );
  }
}
