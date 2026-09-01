import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/immersive_controls_state.dart';
import 'package:gstplayer/src/controls/immersive_gesture_layer.dart';
import 'package:gstplayer/src/gstplayer_controller.dart';
import 'package:gstplayer/src/gst_video_view.dart';

import '../support/fake_playback_controls_model.dart';
import '../support/fake_player_command_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('seekSecondsFromDrag', () {
    test('scales with drag distance and clamps to step', () {
      expect(
        seekSecondsFromDrag(horizontalDrag: 160, width: 320, maxStepSeconds: 5),
        5,
      );
      expect(
        seekSecondsFromDrag(
          horizontalDrag: -160,
          width: 320,
          maxStepSeconds: 5,
        ),
        -5,
      );
    });
  });

  group('GstVideoView aspectRatioMode sync', () {
    late FakePlayerCommandPort port;
    late GstPlayerController controller;

    setUp(() {
      port = FakePlayerCommandPort();
      controller = GstPlayerController(port: port);
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('calls setAspectRatioMode once per mode change', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      try {
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
        expect(port.setAspectRatioModeCallCount, 1);

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
        expect(port.setAspectRatioModeCallCount, 2);
        expect(port.lastAspectRatioMode, AspectRatioMode.fill);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('ImmersiveGestureLayer seek gating', () {
    Future<void> pumpLayer(
      WidgetTester tester, {
      required FakePlaybackControlsModel model,
      required ImmersiveControlsState immersive,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: Stack(
                children: [
                  ImmersiveGestureLayer(
                    immersive: immersive,
                    model: model,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('horizontal drag seeks when seekable', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final model = FakePlaybackControlsModel(
        duration: const Duration(seconds: 100),
        initialPosition: const Duration(seconds: 30),
      );
      final immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(
          seekStep: VideoSeekStep.s5,
        ),
      );
      try {
        await pumpLayer(tester, model: model, immersive: immersive);
        await tester.drag(find.byType(GestureDetector), const Offset(200, 0));
        await tester.pumpAndSettle();

        expect(model.seekCallCount, 1);
        expect(model.lastSeek, isNotNull);
      } finally {
        model.dispose();
        immersive.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('horizontal drag does not seek when not seekable', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final model = FakePlaybackControlsModel(
        duration: const Duration(seconds: 100),
        initialPosition: const Duration(seconds: 30),
        isSeekable: false,
      );
      final immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(
          seekStep: VideoSeekStep.s5,
        ),
      );
      try {
        await pumpLayer(tester, model: model, immersive: immersive);
        await tester.drag(find.byType(GestureDetector), const Offset(200, 0));
        await tester.pumpAndSettle();

        expect(model.seekCallCount, 0);
        expect(model.lastSeek, isNull);
      } finally {
        model.dispose();
        immersive.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
