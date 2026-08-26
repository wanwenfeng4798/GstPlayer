import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/progress_bar_with_preview.dart';
import 'package:gstplayer/src/controls/scrub_controller.dart';
import 'package:gstplayer/src/controls/scrub_preview_controller.dart';
import 'package:gstplayer/src/theme/video_controls_theme.dart';

import '../support/fake_playback_controls_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressBarWithPreview', () {
    late FakePlaybackControlsModel model;
    late ScrubController scrub;
    late ScrubPreviewController preview;

    setUp(() {
      model = FakePlaybackControlsModel(
        duration: const Duration(seconds: 60),
        initialPosition: const Duration(seconds: 10),
      );
      scrub = ScrubController(model: model, onInteract: () {});
      preview = ScrubPreviewController();
    });

    tearDown(() {
      scrub.dispose();
      preview.dispose();
      model.dispose();
    });

    testWidgets('dragging shows preview bubble without layout exceptions', (
      tester,
    ) async {
      final theme = VideoControlsTheme.material();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 48,
              child: ProgressBarWithPreview(
                model: model,
                scrub: scrub,
                preview: preview,
                theme: theme,
                previewBarHeight: 48,
                builder: (context, snap) => Slider(
                  value: snap.displayValue,
                  onChangeStart: snap.enabled
                      ? (_) => snap.onSeekStart?.call()
                      : null,
                  onChanged: snap.onSeekChanged,
                  onChangeEnd: snap.onSeekEnd,
                ),
              ),
            ),
          ),
        ),
      );

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(slider),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(preview.visible, isTrue);
      expect(tester.takeException(), isNull);

      await gesture.up();
      await tester.pump();
      expect(preview.visible, isFalse);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(tester.takeException(), isNull);
    });
  });
}
