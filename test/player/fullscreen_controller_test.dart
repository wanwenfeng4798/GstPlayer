import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/fullscreen_config.dart';
import 'package:gstplayer/src/controls/immersive_controls_state.dart';
import 'package:gstplayer/src/gstplayer_controller.dart';

void main() {
  group('GstPlayerController fullscreen', () {
    late GstPlayerController controller;
    late ImmersiveControlsState immersive;

    setUp(() {
      controller = GstPlayerController();
      immersive = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(),
      );
    });

    tearDown(() {
      controller.dispose();
      immersive.dispose();
    });

    test('isFullscreen is false before attachImmersive', () {
      expect(controller.isFullscreen.value, isFalse);
    });

    test('enter and exit fullscreen toggle landscapeLocked on mobile', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        controller.attachImmersive(immersive);

        expect(controller.isFullscreen.value, isFalse);

        controller.enterFullscreen();
        expect(controller.isFullscreen.value, isTrue);
        expect(immersive.landscapeLocked.value, isTrue);

        controller.exitFullscreen();
        expect(controller.isFullscreen.value, isFalse);
        expect(immersive.landscapeLocked.value, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('enterFullscreen is no-op on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        controller.attachImmersive(immersive);
        controller.enterFullscreen();

        expect(controller.isFullscreen.value, isFalse);
        expect(immersive.landscapeLocked.value, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('detachImmersive resets isFullscreen to false', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        controller.attachImmersive(immersive);
        controller.enterFullscreen();
        controller.detachImmersive();

        expect(controller.isFullscreen.value, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
