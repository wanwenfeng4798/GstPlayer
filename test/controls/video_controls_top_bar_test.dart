import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/controls_overlay_slots.dart';
import 'package:gstplayer/src/controls/fullscreen_config.dart';
import 'package:gstplayer/src/controls/immersive_controls_state.dart';
import 'package:gstplayer/src/controls/player_chrome_settings.dart';
import 'package:gstplayer/src/domain/player_events.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_playback_controls_model.dart';
import '../support/test_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoControlsTopBar', () {
    late FakePlaybackControlsModel model;
    late ImmersiveControlsState immersive;
    late PlayerChromeSettings settings;

    setUp(() {
      model = FakePlaybackControlsModel();
      settings = PlayerChromeSettings();
      immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(
          desktopImmersive: true,
          aspectRatioLabels: AspectRatioModeLabels(fit: '适应'),
        ),
      );
    });

    tearDown(() {
      model.dispose();
      immersive.dispose();
      settings.dispose();
    });

    Future<void> pumpControls(
      WidgetTester tester, {
      VideoControlsFullscreenConfig fullscreen =
          const VideoControlsFullscreenConfig(
            desktopImmersive: true,
            aspectRatioLabels: AspectRatioModeLabels(fit: '适应'),
          ),
    }) async {
      immersive.dispose();
      immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: fullscreen,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
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
      );
      await tester.pump();
    }

    testWidgets('hides aspect ratio menu when showAspectRatioMenu is false', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpControls(
          tester,
          fullscreen: const VideoControlsFullscreenConfig(
            desktopImmersive: true,
            aspectRatioLabels: AspectRatioModeLabels(fit: '适应'),
            overlaySlots: VideoControlsOverlaySlots(showAspectRatioMenu: false),
          ),
        );

        expect(find.byIcon(Icons.fit_screen), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('shows custom actions from overlay slots', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpControls(
          tester,
          fullscreen: const VideoControlsFullscreenConfig(
            desktopImmersive: true,
            overlaySlots: VideoControlsOverlaySlots(
              showAspectRatioMenu: false,
              actions: [Icon(Icons.settings)],
            ),
          ),
        );

        expect(find.byIcon(Icons.settings), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('shows custom title and aspect ratio menu when immersive', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpControls(
          tester,
          fullscreen: const VideoControlsFullscreenConfig(
            desktopImmersive: true,
            aspectRatioLabels: AspectRatioModeLabels(fit: '适应'),
            overlaySlots: VideoControlsOverlaySlots(title: Text('Episode 1')),
          ),
        );

        expect(find.text('Episode 1'), findsOneWidget);
        expect(find.byIcon(Icons.fit_screen), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
