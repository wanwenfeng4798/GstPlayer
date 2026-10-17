import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gstplayer/src/controls/material_video_controls.dart';
import 'package:gstplayer/src/controls/player_chrome_settings.dart';
import 'package:gstplayer/src/overlay/danmaku.dart';
import 'package:gstplayer/src/surface/texture_surface.dart';
import 'package:gstplayer/src/surface/video_surface_handle.dart';
import 'package:gstplayer/src/theme/video_controls_theme.dart';

import '../support/fake_playback_controls_model.dart';
import '../support/test_chrome.dart';

class ObservedControlsModel extends FakePlaybackControlsModel {
  bool get listening => hasListeners;
}

void main() {
  testWidgets('replacing chrome model removes all old listeners', (
    tester,
  ) async {
    final old = ObservedControlsModel();
    final fresh = ObservedControlsModel();
    final settings = PlayerChromeSettings();
    Widget build(FakePlaybackControlsModel model) => MaterialApp(
      home: Scaffold(
        body: MaterialVideoControls(
          model: model,
          theme: VideoControlsTheme.material(),
          strings: testStringsEn,
          settings: settings,
          onInteract: () {},
        ),
      ),
    );
    await tester.pumpWidget(build(old));
    await tester.pump();
    expect(old.listening, isTrue);
    await tester.pumpWidget(build(fresh));
    await tester.pump();
    expect(old.listening, isFalse);
    expect(fresh.listening, isTrue);
    await tester.pumpWidget(const SizedBox());
    old.dispose();
    fresh.dispose();
    settings.dispose();
  });
  testWidgets('stale texture creation cannot replace the current player', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    const channel = MethodChannel('gstplayer/texture');
    final first = Completer<int>();
    final second = Completer<int>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'createTexture'
              ? ((call.arguments as Map)['playerId'] == 1
                    ? first.future
                    : second.future)
              : null,
        );
    Widget build(int player) => MaterialApp(
      home: TextureVideoSurface(
        handle: VideoSurfaceHandle(
          playerId: player,
          kind: VideoSurfaceKind.texture,
        ),
      ),
    );
    try {
      await tester.pumpWidget(build(1));
      await tester.pumpWidget(build(2));
      second.complete(22);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Texture>(find.byType(Texture)).textureId, 22);
      first.complete(11);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Texture>(find.byType(Texture)).textureId, 22);
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
  testWidgets('disabled and empty danmaku stop scheduling animation', (
    tester,
  ) async {
    const items = [DanmakuItem(at: Duration.zero, text: 'hello')];
    Widget build(bool enabled, List<DanmakuItem> entries) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 200,
        child: DanmakuOverlay(
          items: entries,
          position: Duration.zero,
          enabled: enabled,
          isPlaying: true,
        ),
      ),
    );
    await tester.pumpWidget(build(true, items));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(build(false, items));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(build(true, const []));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'danmaku index supports unsorted cues, seeking and list replacement',
    (tester) async {
      final items = [
        const DanmakuItem(at: Duration(seconds: 30), text: 'future'),
        const DanmakuItem(at: Duration(seconds: 1), text: 'visible'),
      ];
      Widget build(Duration at) => MaterialApp(
        home: SizedBox(
          width: 400,
          height: 200,
          child: DanmakuOverlay(items: items, position: at, enabled: true),
        ),
      );
      await tester.pumpWidget(build(const Duration(seconds: 2)));
      expect(find.text('visible'), findsOneWidget);
      expect(find.text('future'), findsNothing);
      items[1] = const DanmakuItem(
        at: Duration(seconds: 1),
        text: 'replacement',
      );
      await tester.pumpWidget(build(const Duration(seconds: 2)));
      expect(find.text('replacement'), findsOneWidget);
      await tester.pumpWidget(build(const Duration(seconds: 31)));
      expect(find.text('future'), findsOneWidget);
      expect(find.text('replacement'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
