import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/fullscreen_config.dart';
import 'package:gstplayer/src/controls/immersive_controls_state.dart';
import 'package:gstplayer/src/controls/player_chrome_settings.dart';
import 'package:gstplayer/src/domain/player_events.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_playback_controls_model.dart';
import '../support/test_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ControlsLockButton', () {
    late FakePlaybackControlsModel model;
    late ImmersiveControlsState immersive;
    late PlayerChromeSettings settings;

    setUp(() {
      model = FakePlaybackControlsModel(
        initialState: PlayerState.paused,
        duration: const Duration(seconds: 100),
      );
      settings = PlayerChromeSettings();
      immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(desktopImmersive: true),
      );
    });

    tearDown(() {
      model.dispose();
      immersive.dispose();
      settings.dispose();
    });

    Future<void> pumpControls(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
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
    }

    Finder lockButton() =>
        find.byKey(const ValueKey('video-controls-lock-button'));

    testWidgets('shows lock icon with bottom chrome unlocked', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpControls(tester);

        expect(lockButton(), findsOneWidget);
        expect(find.byIcon(Icons.lock_open), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('locking hides bottom chrome and blocks settings', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpControls(tester);

        await tester.tap(lockButton());
        await tester.pump();

        expect(immersive.controlsLocked, isTrue);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
        expect(find.text('1.0x'), findsNothing);

        await tester.tapAt(const Offset(700, 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('镜像画面'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('unlocking restores bottom chrome', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpControls(tester);

        await tester.tap(lockButton());
        await tester.pump();
        expect(find.byIcon(Icons.settings), findsNothing);

        await tester.tap(lockButton());
        await tester.pump();

        expect(immersive.controlsLocked, isFalse);
        expect(find.byIcon(Icons.lock_open), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('space is ignored while controls are locked', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpControls(tester);
        immersive.controlsLocked = true;
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(model.togglePlayPauseCallCount, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
