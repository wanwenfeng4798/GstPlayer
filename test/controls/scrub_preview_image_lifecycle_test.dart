import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gstplayer/src/controls/scrub_preview_bubble.dart';
import 'package:gstplayer/src/controls/scrub_preview_controller.dart';
import 'package:gstplayer/src/controls/scrub_preview_track.dart';
import 'package:gstplayer/src/theme/video_controls_theme.dart';

class PreviewCompleter extends ImageStreamCompleter {
  PreviewCompleter(ui.Image image) {
    publish(image);
  }
  void publish(ui.Image image) => setImage(ImageInfo(image: image.clone()));
}

class PreviewImage extends ImageProvider<PreviewImage> {
  PreviewImage(ui.Image image) : completer = PreviewCompleter(image);
  final PreviewCompleter completer;
  @override
  Future<PreviewImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    PreviewImage key,
    ImageDecoderCallback decode,
  ) => completer;
}

void main() {
  testWidgets(
    'absolute preview releases image handles on replacement and disposal',
    (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(4, 4));
      picture.dispose();
      final provider = PreviewImage(image!);
      final preview = ScrubPreviewController();
      preview.setTrack(
        ScrubPreviewTrack.frames([
          ScrubPreviewFrame(
            start: Duration.zero,
            end: const Duration(seconds: 10),
            image: provider,
            crop: const Rect.fromLTWH(0, 0, 4, 4),
          ),
        ]),
      );
      preview.updatePreview(
        fraction: 0.5,
        duration: const Duration(seconds: 10),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 200,
            child: ScrubPreviewBubble(
              controller: preview,
              theme: VideoControlsTheme.material(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final handles = image.debugGetOpenHandleStackTraces()!.length;
      expect(handles, greaterThan(1));
      provider.completer.publish(image);
      await tester.pump();
      expect(image.debugGetOpenHandleStackTraces()!.length, handles);
      await tester.pumpWidget(const SizedBox());
      imageCache.clear();
      imageCache.clearLiveImages();
      await tester.pump();
      expect(image.debugGetOpenHandleStackTraces()!.length, 1);
      preview.dispose();
      image.dispose();
    },
  );
}
