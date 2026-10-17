/// Shared SRT/WebVTT cue parser used by subtitles and thumbnail tracks.
class TimedTextCue {
  const TimedTextCue(this.start, this.end, this.text);
  final Duration start;
  final Duration end;
  final String text;
}

final _timing = RegExp(
  r'^((?:\d+:)?\d{2}:\d{2}(?:[,.]\d{1,3})?)\s*-->\s*'
  r'((?:\d+:)?\d{2}:\d{2}(?:[,.]\d{1,3})?)(?:\s|$)',
);

Duration? parseTimedTextTimestamp(String value) {
  final parts = value.replaceAll(',', '.').split(':');
  if (parts.length != 2 && parts.length != 3) return null;
  final hours = parts.length == 3 ? int.tryParse(parts[0]) : 0;
  final minutes = int.tryParse(parts[parts.length - 2]);
  final seconds = double.tryParse(parts.last);
  if (hours == null ||
      hours < 0 ||
      minutes == null ||
      minutes < 0 ||
      minutes >= 60 ||
      seconds == null ||
      !seconds.isFinite ||
      seconds < 0 ||
      seconds >= 60) {
    return null;
  }
  return Duration(
    hours: hours,
    minutes: minutes,
    milliseconds: (seconds * 1000).round(),
  );
}

List<TimedTextCue> parseTimedText(String raw) {
  final normalized = raw
      .replaceFirst(RegExp(r'^\uFEFF'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trimLeft();
  final cues = <TimedTextCue>[];
  for (final block in normalized.split(RegExp(r'\n[ \t]*\n'))) {
    final lines = block.split('\n');
    if (lines.isEmpty ||
        RegExp(r'^(WEBVTT|NOTE|STYLE|REGION)(?:\s|$)')
            .hasMatch(lines.first.trim())) {
      continue;
    }
    // A cue can have a numeric SRT index or an arbitrary WebVTT identifier.
    final index = lines.indexWhere((line) => _timing.hasMatch(line.trim()));
    if (index < 0 || index + 1 >= lines.length) continue;
    final match = _timing.firstMatch(lines[index].trim())!;
    final start = parseTimedTextTimestamp(match[1]!);
    final end = parseTimedTextTimestamp(match[2]!);
    final text = lines.skip(index + 1).join('\n').trim();
    if (start == null || end == null || end <= start || text.isEmpty) continue;
    cues.add(TimedTextCue(start, end, text));
  }
  return cues;
}
