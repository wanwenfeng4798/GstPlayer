import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/video_controls_theme.dart';
import 'scrub_preview_controller.dart';
import 'scrub_preview_track.dart';

/// Floating thumbnail + timecode above the progress thumb /
/// 进度拇指上方的缩略图气泡（外部图 / WebVTT / 雪碧图）.
class ScrubPreviewBubble extends StatelessWidget {
  /// Creates the scrub preview bubble / 创建 scrub 预览气泡.
  const ScrubPreviewBubble({
    super.key,
    required this.controller,
    required this.theme,
    this.barHeight = 48,
  });

  final ScrubPreviewController controller;
  final VideoControlsTheme theme;

  /// Approximate bottom chrome height used to lift the bubble / 底栏高度，用于抬升气泡.
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.visible) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            const bubbleWidth = 128.0;
            final trackWidth = constraints.maxWidth;
            if (!trackWidth.isFinite || trackWidth <= 0) {
              return const SizedBox.shrink();
            }
            final maxLeft = (trackWidth - bubbleWidth).clamp(
              0.0,
              double.infinity,
            );
            final left = (controller.fraction * trackWidth - bubbleWidth / 2)
                .clamp(0.0, maxLeft);
            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: left,
                  bottom: barHeight,
                  child: _BubbleCard(
                    theme: theme,
                    frame: controller.frame,
                    timeLabel: controller.timeLabel,
                    width: bubbleWidth,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({
    required this.theme,
    required this.frame,
    required this.timeLabel,
    required this.width,
  });

  final VideoControlsTheme theme;
  final ScrubPreviewFrame? frame;
  final String timeLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.backgroundColor.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Colors.black,
                  child: frame != null
                      ? _ScrubPreviewImage(frame: frame!)
                      : Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                            color: theme.iconColor.withValues(alpha: 0.6),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                timeLabel,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [ScrubPreviewFrame.image], optionally cropping sprite/`#xywh` regions.
class _ScrubPreviewImage extends StatelessWidget {
  const _ScrubPreviewImage({required this.frame});

  final ScrubPreviewFrame frame;

  @override
  Widget build(BuildContext context) {
    final crop = frame.crop;
    if (crop == null) {
      return Image(image: frame.image, fit: BoxFit.cover, gaplessPlayback: true);
    }
    // Fractional crop (sprite sheet cells use 0..1 rects).
    if (crop.left >= 0 &&
        crop.top >= 0 &&
        crop.right <= 1.0001 &&
        crop.bottom <= 1.0001) {
      final columns = (1 / crop.width).round().clamp(1, 1000);
      final rows = (1 / crop.height).round().clamp(1, 1000);
      final col = (crop.left * columns).round().clamp(0, columns - 1);
      final row = (crop.top * rows).round().clamp(0, rows - 1);
      return ClipRect(
        child: Align(
          alignment: Alignment(
            columns == 1 ? 0 : -1 + 2 * col / (columns - 1),
            rows == 1 ? 0 : -1 + 2 * row / (rows - 1),
          ),
          widthFactor: 1 / columns,
          heightFactor: 1 / rows,
          child: Image(image: frame.image, fit: BoxFit.fill, gaplessPlayback: true),
        ),
      );
    }
    // Absolute pixel crop from WebVTT `#xywh=`.
    return _AbsoluteCropImage(image: frame.image, crop: crop);
  }
}

class _AbsoluteCropImage extends StatefulWidget {
  const _AbsoluteCropImage({required this.image, required this.crop});

  final ImageProvider image;
  final Rect crop;

  @override
  State<_AbsoluteCropImage> createState() => _AbsoluteCropImageState();
}

class _AbsoluteCropImageState extends State<_AbsoluteCropImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AbsoluteCropImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image || oldWidget.crop != widget.crop) {
      _resolve();
    }
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _unsubscribe();
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _info = info);
    });
    stream.addListener(_listener!);
  }

  void _unsubscribe() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) {
      return const SizedBox.expand();
    }
    return CustomPaint(
      painter: _CropPainter(image: info.image, crop: widget.crop),
      child: const SizedBox.expand(),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({required this.image, required this.crop});

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      crop.left,
      crop.top,
      crop.width,
      crop.height,
    ).intersect(Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
    if (src.isEmpty) return;
    final dst = Offset.zero & size;
    // Cover-fit the cropped source into [dst].
    final sx = dst.width / src.width;
    final sy = dst.height / src.height;
    final scale = sx > sy ? sx : sy;
    final drawn = Size(src.width * scale, src.height * scale);
    final dx = dst.left + (dst.width - drawn.width) / 2;
    final dy = dst.top + (dst.height - drawn.height) / 2;
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(dx, dy, drawn.width, drawn.height),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.crop != crop;
}
