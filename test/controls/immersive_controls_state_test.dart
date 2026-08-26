import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/fullscreen_config.dart';
import 'package:gstplayer/src/controls/immersive_controls_state.dart';
import 'package:gstplayer/src/domain/player_events.dart';

void main() {
  group('ImmersiveControlsState', () {
    late ImmersiveControlsState state;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      state.dispose();
    });

    test('gesturesEnabled is true on mobile without fullscreen', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      state = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(),
      );
      expect(state.landscapeLocked, isFalse);
      expect(state.gesturesEnabled, isTrue);
      expect(state.immersiveActive, isFalse);

      state.landscapeLocked = true;
      expect(state.gesturesEnabled, isTrue);
      expect(state.immersiveActive, isTrue);
    });

    test('immersiveActive follows desktopImmersive on desktop hosts', () {
      state = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(desktopImmersive: true),
      );
      expect(state.immersiveActive, isTrue);

      state.dispose();
      state = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(
          desktopImmersive: false,
        ),
      );
      expect(state.immersiveActive, isFalse);
    });

    test('fullscreen config updates immersiveActive on desktop', () {
      state = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(desktopImmersive: true),
      );
      state.fullscreen = const VideoControlsFullscreenConfig(
        desktopImmersive: false,
      );
      expect(state.immersiveActive, isFalse);
    });

    test('landscapeLocked toggles aspectRatioMode independently', () {
      state = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(),
      );

      state.landscapeLocked = true;
      state.aspectRatioMode = AspectRatioMode.fill;

      expect(state.landscapeLocked, isTrue);
      expect(state.aspectRatioMode, AspectRatioMode.fill);
    });

    test('controlsLocked is independent of landscapeLocked', () {
      state = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(),
      );
      expect(state.controlsLocked, isFalse);

      state.controlsLocked = true;
      expect(state.controlsLocked, isTrue);
      expect(state.landscapeLocked, isFalse);

      state.landscapeLocked = true;
      expect(state.controlsLocked, isTrue);
      expect(state.landscapeLocked, isTrue);

      state.controlsLocked = false;
      expect(state.controlsLocked, isFalse);
      expect(state.landscapeLocked, isTrue);
    });

    test('hud starts null', () {
      state = ImmersiveControlsState(
        initialAspectRatioMode: AspectRatioMode.fit,
        fullscreen: const VideoControlsFullscreenConfig(),
      );
      expect(state.hud, isNull);
    });
  });

  group('AspectRatioModeLabels', () {
    test('label returns custom strings', () {
      const labels = AspectRatioModeLabels(
        fit: 'Fit',
        fill: 'Fill',
        stretch: 'Stretch',
      );
      expect(labels.label(AspectRatioMode.fit), 'Fit');
      expect(labels.label(AspectRatioMode.fill), 'Fill');
      expect(labels.label(AspectRatioMode.stretch), 'Stretch');
    });
  });
}
