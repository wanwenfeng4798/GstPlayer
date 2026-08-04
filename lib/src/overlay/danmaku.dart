import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single danmaku (bullet comment) cue / 单条弹幕.
class DanmakuItem {
  /// Creates a danmaku item / 创建弹幕条目.
  const DanmakuItem({
    required this.at,
    required this.text,
    this.color = Colors.white,
    this.duration = const Duration(seconds: 8),
  });

  /// Appearance time on the media timeline / 出现在时间轴上的时刻.
  final Duration at;

  /// Comment text / 文案.
  final String text;

  /// Text color / 文字颜色.
  final Color color;

  /// How long the item scrolls across / 滚动穿越时长.
  final Duration duration;
}

/// Renders scrolling danmaku synced to [position] / 按播放位置渲染滚动弹幕.
class DanmakuOverlay extends StatelessWidget {
  /// Creates a danmaku overlay / 创建弹幕层.
  const DanmakuOverlay({
    super.key,
    required this.items,
    required this.position,
    required this.enabled,
    this.opacity = 0.9,
  });

  final List<DanmakuItem> items;
  final Duration position;
  final bool enabled;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (!enabled || items.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            if (width <= 0 || height <= 0) return const SizedBox.shrink();
            final laneHeight = math.max(24.0, height / 10);
            final laneCount = math.max(1, (height / laneHeight).floor());
            final children = <Widget>[];
            for (var i = 0; i < items.length; i++) {
              final item = items[i];
              final elapsed = position - item.at;
              if (elapsed.isNegative) continue;
              final totalMs = item.duration.inMilliseconds;
              if (totalMs <= 0 || elapsed.inMilliseconds > totalMs) continue;
              final t = elapsed.inMilliseconds / totalMs;
              final lane = i % laneCount;
              final top = lane * laneHeight + 4;
              final textWidth = _estimateTextWidth(item.text);
              final travel = width + textWidth + 24;
              final left = width - t * travel;
              children.add(
                Positioned(
                  left: left,
                  top: top,
                  child: Text(
                    item.text,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(
                          blurRadius: 2,
                          color: Colors.black87,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Stack(clipBehavior: Clip.hardEdge, children: children);
          },
        ),
      ),
    );
  }

  double _estimateTextWidth(String text) => text.length * 14.0;
}
