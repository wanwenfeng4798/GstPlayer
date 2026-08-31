import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/model/video_source.dart';

void main() {
  group('VideoSource', () {
    test('network equality includes httpHeaders', () {
      const a = VideoSource.network(
        'https://example.com/a.mp4',
        httpHeaders: {'Referer': 'https://example.com/'},
      );
      const b = VideoSource.network(
        'https://example.com/a.mp4',
        httpHeaders: {'Referer': 'https://example.com/'},
      );
      const c = VideoSource.network('https://example.com/a.mp4');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes headers when present', () {
      const source = VideoSource.network(
        'https://example.com/a.mp4',
        httpHeaders: {'Referer': 'https://example.com/'},
      );
      expect(
        source.toString(),
        contains('Referer'),
      );
    });
  });
}
