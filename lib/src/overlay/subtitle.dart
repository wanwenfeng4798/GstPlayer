import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trimLeft().startsWith('WEBVTT')) {
      return _parseVtt(normalized);
    }
    return _parseSrt(normalized);
  }

  /// Loads and parses an asset subtitle file / 加载并解析 asset 字幕.
  static Future<List<SubtitleCue>> loadAsset(String assetKey) async {
    final raw = await rootBundle.loadString(assetKey);
    return parse(raw);
  }

  static List<SubtitleCue> _parseSrt(String raw) {
    final blocks = raw.split(RegExp(r'\n\s*\n'));
    final cues = <SubtitleCue>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) continue;
      var idx = 0;
      if (RegExp(r'^\d+$').hasMatch(lines[0])) idx = 1;
      if (idx >= lines.length) continue;
      final times = lines[idx];
      final match = RegExp(
        r'(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3})',
      ).firstMatch(times);
      if (match == null) continue;
      final start = _parseTimestamp(match.group(1)!);
      final end = _parseTimestamp(match.group(2)!);
      final text = lines.sublist(idx + 1).join('\n');
      if (text.isEmpty) continue;
      cues.add(SubtitleCue(start: start, end: end, text: text));
    }
    return cues;
  }

  static List<SubtitleCue> _parseVtt(String raw) {
    final body = raw.replaceFirst(RegExp(r'^WEBVTT[^\n]*\n'), '');
    return _parseSrt(body);
  }

  static Duration _parseTimestamp(String value) {
    final cleaned = value.replaceAll(',', '.');
    final parts = cleaned.split(':');
    if (parts.length != 3) return Duration.zero;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final seconds = int.tryParse(secParts[0]) ?? 0;
    var millis = 0;
    if (secParts.length > 1) {
      final frac = secParts[1].padRight(3, '0').substring(0, 3);
      millis = int.tryParse(frac) ?? 0;
    }
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
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
