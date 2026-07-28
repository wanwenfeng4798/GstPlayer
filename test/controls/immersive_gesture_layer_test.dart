import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/immersive_gesture_layer.dart';
import 'package:gstplayer/src/gstplayer_controller.dart';
import 'package:gstplayer/src/gst_video_view.dart';

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
}
