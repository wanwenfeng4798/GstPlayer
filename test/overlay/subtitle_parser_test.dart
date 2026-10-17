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
  test('VTT supports short timestamps, named cues, BOM and cue settings', () {
    final cues = SubtitleParser.parse(
      '\uFEFFWEBVTT\n\nintro\n00:01.250 --> 00:03.500 align:start\nHello\n',
    );
    expect(cues, hasLength(1));
    expect(cues.single.start, const Duration(milliseconds: 1250));
    expect(cues.single.end, const Duration(milliseconds: 3500));
  });
  test('VTT ignores NOTE blocks and invalid or reversed times', () {
    final cues = SubtitleParser.parse(
      'WEBVTT\n\nNOTE ignored\n00:01.000 --> 00:02.000\ncomment\n\nbad\n00:60.000 --> 01:05.000\ninvalid\n\n00:03.000 --> 00:02.000\nreversed\n',
    );
    expect(cues, isEmpty);
  });
}
