import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/video_controls_theme.dart';
import 'scrub_preview_controller.dart';

/// Floating thumbnail + timecode above the progress thumb / 进度拇指上方的缩略图气泡.
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
            final maxLeft = (constraints.maxWidth - bubbleWidth).clamp(
              0.0,
              double.infinity,
            );
            final left = (controller.fraction * constraints.maxWidth -
                    bubbleWidth / 2)
                .clamp(0.0, maxLeft);
            return Stack(
              children: [
                Positioned(
                  left: left,
                  bottom: barHeight,
                  child: _BubbleCard(
                    theme: theme,
                    png: controller.png,
                    loading: controller.loading,
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
    required this.png,
    required this.loading,
    required this.timeLabel,
    required this.width,
  });

  final VideoControlsTheme theme;
  final Uint8List? png;
  final bool loading;
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
                  child: png != null
                      ? Image.memory(png!, fit: BoxFit.cover)
                      : Center(
                          child: loading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.iconColor,
                                  ),
                                )
                              : Icon(
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
