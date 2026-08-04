import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/gstplayer.dart';

void main() {
  test('SubtitleParser parses SRT cues', () {
    const raw = '''
1
00:00:01,000 --> 00:00:03,500
Hello

2
00:00:04,000 --> 00:00:05,000
World
''';
    final cues = SubtitleParser.parse(raw);
    expect(cues, hasLength(2));
    expect(cues[0].text, 'Hello');
    expect(cues[0].contains(const Duration(seconds: 2)), isTrue);
    expect(cues[0].contains(const Duration(seconds: 4)), isFalse);
    expect(cues[1].text, 'World');
  });

  test('SubtitleParser parses WEBVTT', () {
    const raw = '''
WEBVTT

00:00:00.000 --> 00:00:01.000
One
''';
    final cues = SubtitleParser.parse(raw);
    expect(cues, hasLength(1));
    expect(cues.first.text, 'One');
  });
}
