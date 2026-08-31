import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

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
class DanmakuOverlay extends StatefulWidget {
  /// Creates a danmaku overlay / 创建弹幕层.
  const DanmakuOverlay({
    super.key,
    required this.items,
    required this.position,
    required this.enabled,
    this.isPlaying = false,
    this.opacity = 0.9,
  });

  final List<DanmakuItem> items;
  final Duration position;
  final bool enabled;
  final bool isPlaying;
  final double opacity;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  static const int _softDriftMs = 500;
  static const int _hardSeekMs = 2000;

  late Ticker _ticker;
  Duration _anchorPosition = Duration.zero;
  DateTime? _anchorWallClock;

  Duration get _displayPosition {
    if (!widget.isPlaying || _anchorWallClock == null) {
      return _anchorPosition;
    }
    return _anchorPosition + DateTime.now().difference(_anchorWallClock!);
  }

  void _syncAnchorToTarget(Duration target) {
    final now = DateTime.now();
    if (!widget.isPlaying) {
      _anchorPosition = target;
      _anchorWallClock = now;
      return;
    }
    final extrapolated = _displayPosition;
    final errorMs = target.inMilliseconds - extrapolated.inMilliseconds;
    if (errorMs.abs() <= _softDriftMs) {
      return;
    }
    if (errorMs.abs() >= _hardSeekMs) {
      _anchorPosition = target;
      _anchorWallClock = now;
      return;
    }
    // Blend toward native without a visible snap on each 200ms tick.
    _anchorPosition = Duration(
      milliseconds: extrapolated.inMilliseconds + errorMs ~/ 3,
    );
    _anchorWallClock = now;
  }

  @override
  void initState() {
    super.initState();
    _anchorPosition = widget.position;
    _anchorWallClock = DateTime.now();
    _ticker = createTicker((_) => setState(() {}));
    if (widget.isPlaying) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position ||
        widget.isPlaying != oldWidget.isPlaying) {
      _syncAnchorToTarget(widget.position);
    }
    if (widget.isPlaying && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.isPlaying && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final position = _displayPosition;
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            if (width <= 0 || height <= 0) return const SizedBox.shrink();
            final laneHeight = math.max(24.0, height / 10);
            final laneCount = math.max(1, (height / laneHeight).floor());
            final children = <Widget>[];
            for (var i = 0; i < widget.items.length; i++) {
              final item = widget.items[i];
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
