import 'package:material_ui/material_ui.dart';

import '../theme/video_controls_theme.dart';
import 'playback_controls_model.dart';
import 'playback_progress_slider.dart';
import 'scrub_controller.dart';
import 'scrub_preview_bubble.dart';
import 'scrub_preview_controller.dart';
import 'scrub_preview_track.dart';

/// Progress slider with scrub thumbnail bubble while dragging /
/// 拖动进度条时显示缩略图预览，松手后隐藏。
class ProgressBarWithPreview extends StatefulWidget {
  /// Creates a progress bar with drag-only scrub preview /
  /// 创建仅拖动时显示预览的进度条.
  const ProgressBarWithPreview({
    super.key,
    required this.model,
    required this.scrub,
    required this.preview,
    required this.theme,
    required this.builder,
    this.scrubPreview,
    this.cupertino = false,
    this.previewBarHeight = 56,
  });

  final PlaybackControlsModel model;
  final ScrubController scrub;
  final ScrubPreviewController preview;
  final VideoControlsTheme theme;
  final PlaybackProgressSliderBuilder builder;

  /// External thumbnail track (WebVTT / sprite / frames). Null = time-only bubble.
  final ScrubPreviewTrack? scrubPreview;
  final bool cupertino;
  final double previewBarHeight;

  @override
  State<ProgressBarWithPreview> createState() => _ProgressBarWithPreviewState();
}

class _ProgressBarWithPreviewState extends State<ProgressBarWithPreview> {
  @override
  void initState() {
    super.initState();
    widget.preview.setTrack(widget.scrubPreview);
  }

  @override
  void didUpdateWidget(covariant ProgressBarWithPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrubPreview != widget.scrubPreview) {
      widget.preview.setTrack(widget.scrubPreview);
    }
  }

  void _previewAt(double fraction) {
    widget.preview.updatePreview(
      fraction: fraction,
      duration: widget.model.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slider = PlaybackProgressSlider(
      model: widget.model,
      scrub: widget.scrub,
      builder: (context, snap) {
        void Function(double)? onChanged;
        final baseChanged = snap.onSeekChanged;
        if (baseChanged != null) {
          onChanged = (v) {
            _previewAt(v);
            baseChanged(v);
          };
        }
        void Function(double)? onEnd;
        final baseEnd = snap.onSeekEnd;
        if (baseEnd != null) {
          onEnd = (v) {
            widget.preview.clear();
            baseEnd(v);
          };
        }
        final wrapped = PlaybackSliderSnapshot(
          displayValue: snap.displayValue,
          enabled: snap.enabled,
          canSeek: snap.canSeek,
          onSeekStart: snap.onSeekStart == null
              ? null
              : () {
                  _previewAt(snap.displayValue);
                  snap.onSeekStart!();
                },
          onSeekChanged: onChanged,
          onSeekEnd: onEnd,
        );
        return widget.builder(context, wrapped);
      },
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        slider,
        Positioned.fill(
          child: IgnorePointer(
            child: ScrubPreviewBubble(
              controller: widget.preview,
              theme: widget.theme,
              barHeight: widget.previewBarHeight,
            ),
          ),
        ),
      ],
    );
  }
}
