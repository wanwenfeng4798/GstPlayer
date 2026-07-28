import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/material_video_controls.dart';
import 'package:gstplayer/src/theme/video_controls_theme.dart';

import '../support/fake_playback_controls_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Material bottom bar does not overflow at Hero-narrow width', (
    tester,
  ) async {
    final model = FakePlaybackControlsModel();
    addTearDown(model.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 200,
            child: MaterialVideoControls(
              model: model,
              theme: VideoControlsTheme.material(),
              onInteract: () {},
              showFullscreenButton: true,
              landscapeLocked: false,
              onFullscreenToggle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('/'), findsOneWidget);
    expect(find.byIcon(Icons.loop), findsNothing);
    expect(find.text('1.0x'), findsNothing);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });
}
