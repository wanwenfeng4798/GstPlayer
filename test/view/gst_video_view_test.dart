import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/gstplayer.dart';
import '../support/fake_player_command_port.dart';
import '../support/player_event_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GstVideoView', () {
    late FakePlayerCommandPort port;
    late GstPlayerController controller;

    setUp(() {
      port = FakePlayerCommandPort();
      controller = GstPlayerController(port: port);
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('syncs aspectRatioMode to port on mount', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: GstVideoView(
                controller: controller,
                aspectRatioMode: AspectRatioMode.fill,
                showControls: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(port.lastAspectRatioMode, AspectRatioMode.fill);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('re-syncs when aspectRatioMode changes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: GstVideoView(
                controller: controller,
                aspectRatioMode: AspectRatioMode.fit,
                showControls: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(port.lastAspectRatioMode, AspectRatioMode.fit);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: GstVideoView(
                controller: controller,
                aspectRatioMode: AspectRatioMode.stretch,
                showControls: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(port.lastAspectRatioMode, AspectRatioMode.stretch);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('open resets aspectRatioMode to fit', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: GstVideoView(
                controller: controller,
                aspectRatioMode: AspectRatioMode.fill,
                showControls: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(port.lastAspectRatioMode, AspectRatioMode.fill);

      await controller.open(VideoSource.network('https://example.com/b.mp4'));
      await tester.pumpAndSettle();

      expect(controller.mediaGeneration, 1);
      expect(port.lastAspectRatioMode, AspectRatioMode.fit);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('EOS with auto-play next calls onPlayNext', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      await controller.initialize();
      var playNextCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 360,
              child: GstVideoView(
                controller: controller,
                onPlayNext: () => playNextCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).at(2));
      await tester.pumpAndSettle();

      port.emit(PlayerEventFixtures.eos());
      await tester.pump();
      await tester.pump();

      expect(playNextCount, 1);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('English language shows Settings title', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 360,
              child: GstVideoView(
                controller: controller,
                language: GstPlayerLanguage.en,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
