import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/fullscreen_config.dart';
import 'package:gstplayer/src/controls/immersive_controls_state.dart';
import 'package:gstplayer/src/controls/immersive_gesture_layer.dart';
import 'package:gstplayer/src/controls/player_chrome_settings.dart';
import 'package:gstplayer/src/domain/player_events.dart';
import 'package:gstplayer/src/theme/video_controls_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_playback_controls_model.dart';
import '../support/test_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gesture layer mounts on mobile without fullscreen', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final model = FakePlaybackControlsModel(
        initialState: PlayerState.playing,
        initialPosition: const Duration(seconds: 10),
      );
      addTearDown(model.dispose);
      final immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(),
      );
      addTearDown(immersive.dispose);
      final settings = PlayerChromeSettings();
      addTearDown(settings.dispose);
      expect(immersive.landscapeLocked, isFalse);
      expect(immersive.gesturesEnabled, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [VideoControlsTheme.bilibili()]),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: Stack(
                children: [
                  testVideoControls(
                    model: model,
                    immersive: immersive,
                    settings: settings,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ImmersiveGestureLayer), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('right-side vertical drag changes volume when not fullscreen', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    late ImmersiveControlsState immersive;
    try {
      final model = FakePlaybackControlsModel(
        initialState: PlayerState.playing,
        initialPosition: const Duration(seconds: 10),
      );
      addTearDown(model.dispose);
      await model.setVolume(0.5);
      immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(),
      );
      addTearDown(immersive.dispose);
      final settings = PlayerChromeSettings();
      addTearDown(settings.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [VideoControlsTheme.bilibili()]),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 240,
              child: Stack(
                children: [
                  testVideoControls(
                    model: model,
                    immersive: immersive,
                    settings: settings,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Hide chrome so IgnorePointer does not block the gesture layer.
      await tester.tapAt(const Offset(180, 80));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.timedDragFrom(
        const Offset(300, 160),
        const Offset(0, -100),
        const Duration(milliseconds: 400),
      );
      await tester.pump();

      expect(model.lastVolume, isNotNull);
      expect(model.volume, greaterThan(0.5));

      // Flush auto-hide / HUD timers before binding invariant checks.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
