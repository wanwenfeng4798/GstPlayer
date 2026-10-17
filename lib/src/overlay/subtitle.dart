import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../media/timed_text.dart';

/// Timed subtitle cue / 定时字幕条目.
class SubtitleCue {
  /// Creates a subtitle cue / 创建字幕条目.
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;

  bool contains(Duration position) =>
      !position.isNegative && position >= start && position < end;
}

/// Minimal WebVTT / SRT parser for Flutter overlay / 简易 SRT/VTT 解析.
class SubtitleParser {
  /// Parses SRT or WebVTT text into cues / 解析 SRT 或 WebVTT.
  static List<SubtitleCue> parse(String raw) {
    return parseTimedText(raw)
        .map(
          (cue) => SubtitleCue(start: cue.start, end: cue.end, text: cue.text),
        )
        .toList();
  }

  /// Loads and parses an asset subtitle file / 加载并解析 asset 字幕.
  static Future<List<SubtitleCue>> loadAsset(String assetKey) async {
    final raw = await rootBundle.loadString(assetKey);
    return parse(raw);
  }
}

/// Bottom-centered subtitle overlay / 底部居中字幕叠层.
class SubtitleOverlay extends StatelessWidget {
  /// Creates a subtitle overlay / 创建字幕层.
  const SubtitleOverlay({
    super.key,
    required this.cues,
    required this.position,
    required this.enabled,
  });

  final List<SubtitleCue> cues;
  final Duration position;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || cues.isEmpty) return const SizedBox.shrink();
    SubtitleCue? active;
    for (final cue in cues) {
      if (cue.contains(position)) {
        active = cue;
        break;
      }
    }
    if (active == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 72),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                active.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
