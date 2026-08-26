import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/material_video_controls.dart';
import 'package:gstplayer/src/controls/player_chrome_settings.dart';
import 'package:gstplayer/src/l10n/gst_player_language.dart';
import 'package:gstplayer/src/l10n/gst_player_strings.dart';
import 'package:gstplayer/src/theme/video_controls_theme.dart';

import '../support/fake_playback_controls_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Material bottom bar does not overflow at Hero-narrow width', (
    tester,
  ) async {
    final model = FakePlaybackControlsModel();
    addTearDown(model.dispose);
    final settings = PlayerChromeSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 200,
            child: MaterialVideoControls(
              model: model,
              theme: VideoControlsTheme.bilibili(),
              strings: GstPlayerStrings.of(GstPlayerLanguage.zh),
              settings: settings,
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
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
