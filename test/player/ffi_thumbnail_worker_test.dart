import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/player/ffi_thumbnail_worker.dart';

void main() {
  test('ThumbnailSupersededException toString is stable', () {
    expect(
      const ThumbnailSupersededException().toString(),
      'ThumbnailSupersededException',
    );
  });
}
