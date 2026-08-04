import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/scrub_preview_controller.dart';
import 'package:gstplayer/src/controls/scrub_preview_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScrubPreviewVttParser', () {
    test('parses asset path without baseUri', () {
      const raw = '''
WEBVTT

00:00:00.000 --> 00:00:05.000
assets/preview/sprite.jpg#xywh=0,0,160,90
''';
      final frames = ScrubPreviewVttParser.parse(raw);
      expect(frames, hasLength(1));
      expect(frames[0].image, isA<AssetImage>());
      expect((frames[0].image as AssetImage).assetName,
          'assets/preview/sprite.jpg');
    });

    test('parses cue with sprite xywh crop', () {
      const raw = '''
WEBVTT

00:00:00.000 --> 00:00:05.000
thumbs.jpg#xywh=0,0,160,90

00:00:05.000 --> 00:00:10.000
thumbs.jpg#xywh=160,0,160,90
''';
      final frames = ScrubPreviewVttParser.parse(
        raw,
        baseUri: Uri.parse('https://cdn.example.com/preview/'),
      );
      expect(frames, hasLength(2));
      expect(frames[0].start, Duration.zero);
      expect(frames[0].end, const Duration(seconds: 5));
      expect(frames[0].crop, const Rect.fromLTWH(0, 0, 160, 90));
      final image = frames[0].image;
      expect(image, isA<NetworkImage>());
      expect(
        (image as NetworkImage).url,
        'https://cdn.example.com/preview/thumbs.jpg',
      );
      expect(frames[1].crop, const Rect.fromLTWH(160, 0, 160, 90));
    });

    test('ScrubPreviewTrack.vtt resolves frameAt by time', () {
      final track = ScrubPreviewTrack.vtt('''
WEBVTT

00:00:00.000 --> 00:00:05.000
https://cdn.example.com/a.jpg

00:00:05.000 --> 00:00:10.000
https://cdn.example.com/b.jpg
''');
      expect(
        (track.frameAt(const Duration(seconds: 2))!.image as NetworkImage).url,
        'https://cdn.example.com/a.jpg',
      );
      expect(
        (track.frameAt(const Duration(seconds: 7))!.image as NetworkImage).url,
        'https://cdn.example.com/b.jpg',
      );
    });
  });

  group('ScrubPreviewTrack.sprite', () {
    test('picks cell by interval with fractional crop', () {
      final track = ScrubPreviewTrack.sprite(
        image: const AssetImage('assets/sprite.png'),
        columns: 5,
        rows: 2,
        interval: const Duration(seconds: 10),
      );
      final frame = track.frameAt(const Duration(seconds: 25))!;
      expect(frame.crop, isNotNull);
      // index 2 → col 2, row 0
      expect(frame.crop!.left, closeTo(2 / 5, 0.001));
      expect(frame.crop!.top, closeTo(0, 0.001));
      expect(frame.crop!.width, closeTo(1 / 5, 0.001));
    });
  });

  group('ScrubPreviewController', () {
    test('updatePreview without track shows time-only bubble', () {
      final preview = ScrubPreviewController();
      preview.updatePreview(
        fraction: 0.5,
        duration: const Duration(seconds: 100),
      );

      expect(preview.visible, isTrue);
      expect(preview.at, const Duration(seconds: 50));
      expect(preview.frame, isNull);
      preview.dispose();
    });

    test('updatePreview with track selects frame', () {
      final track = ScrubPreviewTrack.frames([
        ScrubPreviewFrame(
          start: Duration.zero,
          end: const Duration(seconds: 50),
          image: const AssetImage('a.png'),
        ),
        ScrubPreviewFrame(
          start: const Duration(seconds: 50),
          end: const Duration(seconds: 100),
          image: const AssetImage('b.png'),
        ),
      ]);
      final preview = ScrubPreviewController(track: track);
      preview.updatePreview(
        fraction: 0.75,
        duration: const Duration(seconds: 100),
      );

      expect(preview.frame?.image, isA<AssetImage>());
      expect((preview.frame!.image as AssetImage).assetName, 'b.png');
      preview.dispose();
    });

    test('clear hides bubble', () {
      final preview = ScrubPreviewController();
      preview.updatePreview(
        fraction: 0.25,
        duration: const Duration(seconds: 40),
      );
      preview.clear();
      expect(preview.visible, isFalse);
      expect(preview.frame, isNull);
      preview.dispose();
    });

    test('zero duration clears preview', () {
      final preview = ScrubPreviewController();
      preview.updatePreview(fraction: 0.5, duration: Duration.zero);
      expect(preview.visible, isFalse);
      preview.dispose();
    });
  });
}
