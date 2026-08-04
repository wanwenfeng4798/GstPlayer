import 'package:flutter/material.dart';

import '../theme/video_controls_theme.dart';
import 'playback_controls_model.dart';
import 'playback_progress_slider.dart';
import 'scrub_controller.dart';
import 'scrub_preview_bubble.dart';
import 'scrub_preview_controller.dart';

/// Progress slider with optional scrub thumbnail bubble / 带缩略图预览的进度条.
class ProgressBarWithPreview extends StatefulWidget {
  /// Creates a progress bar with scrub preview / 创建带预览的进度条.
  const ProgressBarWithPreview({
    super.key,
    required this.model,
    required this.scrub,
    required this.preview,
    required this.theme,
    required this.builder,
    this.cupertino = false,
    this.previewBarHeight = 56,
  });

  final PlaybackControlsModel model;
  final ScrubController scrub;
  final ScrubPreviewController preview;
  final VideoControlsTheme theme;
  final PlaybackProgressSliderBuilder builder;
  final bool cupertino;
  final double previewBarHeight;

  @override
  State<ProgressBarWithPreview> createState() => _ProgressBarWithPreviewState();
}

class _ProgressBarWithPreviewState extends State<ProgressBarWithPreview> {
  @override
  void initState() {
    super.initState();
    widget.preview.setSource(widget.model.mediaSource);
    widget.model.addListener(_onModel);
  }

  @override
  void didUpdateWidget(covariant ProgressBarWithPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_onModel);
      widget.model.addListener(_onModel);
    }
    widget.preview.setSource(widget.model.mediaSource);
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModel);
    super.dispose();
  }

  void _onModel() {
    widget.preview.setSource(widget.model.mediaSource);
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

    final child = MouseRegion(
      onHover: (event) {
        if (widget.scrub.isScrubbing) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize || box.size.width <= 0) return;
        final fraction = (event.localPosition.dx / box.size.width).clamp(
          0.0,
          1.0,
        );
        if (!widget.model.isSeekable ||
            widget.model.duration <= Duration.zero) {
          return;
        }
        _previewAt(fraction);
      },
      onExit: (_) {
        if (!widget.scrub.isScrubbing) widget.preview.clear();
      },
      child: slider,
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        ScrubPreviewBubble(
          controller: widget.preview,
          theme: widget.theme,
          barHeight: widget.previewBarHeight,
        ),
        child,
      ],
    );
  }
}
