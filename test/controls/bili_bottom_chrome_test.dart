import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/controls/bili_bottom_chrome.dart';
import 'package:gstplayer/src/controls/bili_overlay_controls.dart';
import 'package:gstplayer/src/controls/material_video_controls.dart';
import 'package:gstplayer/src/controls/player_chrome_settings.dart';
import 'package:gstplayer/src/domain/player_events.dart';
import 'package:gstplayer/src/l10n/gst_player_language.dart';
import 'package:gstplayer/src/l10n/gst_player_strings.dart';
import 'package:gstplayer/src/theme/video_controls_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_playback_controls_model.dart';
import '../support/test_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlaybackControlsModel model;
  late PlayerChromeSettings settings;

  setUp(() {
    model = FakePlaybackControlsModel(
      initialState: PlayerState.playing,
      initialPosition: const Duration(seconds: 1),
      duration: const Duration(seconds: 5),
    );
    settings = PlayerChromeSettings();
  });

  tearDown(() {
    model.dispose();
    settings.dispose();
  });

  Future<void> pumpChrome(
    WidgetTester tester, {
    GstPlayerStrings? strings,
    BiliOverlayControlsConfig? overlay,
    Size size = const Size(800, 480),
    bool showCaptureButton = true,
    Future<void> Function(Uint8List pngBytes)? onScreenshot,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: MaterialVideoControls(
              model: model,
              theme: VideoControlsTheme.bilibili(),
              strings: strings ?? testStringsZh,
              settings: settings,
              overlayControls: overlay,
              onInteract: () {},
              showFullscreenButton: true,
              landscapeLocked: false,
              onFullscreenToggle: () {},
              showCaptureButton: showCaptureButton,
              onScreenshot: onScreenshot,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows current and remaining time on the transport row', (
    tester,
  ) async {
    await pumpChrome(tester);
    expect(find.text('00:01'), findsOneWidget);
    expect(find.text('00:04'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('settings popup navigates to more playback settings and back', (
    tester,
  ) async {
    await pumpChrome(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('镜像画面'), findsOneWidget);
    expect(find.text('单集循环'), findsOneWidget);
    expect(find.text('自动播放'), findsOneWidget);

    await tester.tap(find.text('更多播放设置'));
    await tester.pumpAndSettle();

    expect(find.text('返回'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('播放方式'), findsOneWidget);
    expect(find.text('播放暂停'), findsOneWidget);
    expect(find.text('播完切下一集'), findsOneWidget);
    expect(find.text('16:9'), findsOneWidget);
    expect(find.text('4:3'), findsOneWidget);
    expect(find.text('隐藏黑边'), findsOneWidget);
    expect(find.text('关灯模式'), findsOneWidget);
    expect(find.text('音轨'), findsOneWidget);

    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('更多播放设置'), findsOneWidget);
  });

  testWidgets('English chrome copy is used when language is en', (
    tester,
  ) async {
    await pumpChrome(tester, strings: testStringsEn);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Mirror video'), findsOneWidget);
    expect(find.text('Send'), findsNothing);
  });

  testWidgets('danmaku input and send are disabled when danmaku is off', (
    tester,
  ) async {
    await pumpChrome(
      tester,
      overlay: BiliOverlayControlsConfig(
        danmakuEnabled: false,
        subtitlesEnabled: true,
        onDanmakuSend: (_) {},
        onDanmakuEnabledChanged: (_) {},
        onSubtitlesEnabledChanged: (_) {},
        danmakuHint: GstPlayerStrings.of(GstPlayerLanguage.zh).danmakuHint,
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    final send = tester.widget<TextButton>(find.widgetWithText(TextButton, '发送'));
    expect(send.onPressed, isNull);
  });

  testWidgets('toggling mirror updates PlayerChromeSettings', (tester) async {
    await pumpChrome(tester);
    expect(settings.mirrored, isFalse);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(settings.mirrored, isTrue);
  });

  testWidgets('audio tracks appear on the more-settings page', (tester) async {
    model.dispose();
    model = FakePlaybackControlsModel(
      tracks: const [
        MediaTrack(
          id: 1,
          trackType: TrackType.audio,
          language: 'en',
          label: 'English',
          selected: true,
        ),
        MediaTrack(
          id: 2,
          trackType: TrackType.audio,
          language: 'ja',
          label: 'Japanese',
          selected: false,
        ),
      ],
    );
    await pumpChrome(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多播放设置'));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
    await tester.ensureVisible(find.text('Japanese'));
    await tester.tap(find.text('Japanese'));
    await tester.pumpAndSettle();
    expect(model.lastSelectedTrack?.label, 'Japanese');
  });

  testWidgets('settings popup sits above and overlaps the gear icon', (
    tester,
  ) async {
    await pumpChrome(tester, size: const Size(800, 480));
    final iconRect = tester.getRect(find.byIcon(Icons.settings));
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    final popupRect = tester.getRect(find.text('设置'));
    expect(popupRect.bottom, lessThanOrEqualTo(iconRect.top + 8));
    expect(popupRect.left, lessThan(iconRect.center.dx));
    expect(popupRect.right, greaterThan(iconRect.center.dx));
  });

  testWidgets('speed popup sits above and overlaps the speed label', (
    tester,
  ) async {
    await pumpChrome(tester, size: const Size(800, 480));
    final labelRect = tester.getRect(find.text('1.0x'));
    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();

    final menuRect = tester.getRect(find.text('1.5x'));
    expect(menuRect.bottom, lessThanOrEqualTo(labelRect.top + 8));
    expect(menuRect.left, lessThan(labelRect.center.dx + 24));
    expect(menuRect.right, greaterThan(labelRect.center.dx - 24));
  });

  testWidgets('time labels use fixed width', (tester) async {
    await pumpChrome(tester);
    final boxes = tester.widgetList<SizedBox>(
      find.descendant(
        of: find.byType(BiliBottomChrome),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 52,
        ),
      ),
    );
    expect(boxes.length, greaterThanOrEqualTo(2));
  });

  testWidgets('settings screenshot calls captureFramePng and onScreenshot', (
    tester,
  ) async {
    Uint8List? saved;
    await pumpChrome(
      tester,
      onScreenshot: (png) async {
        saved = png;
      },
    );
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('截图'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(model.captureFramePngCallCount, 1);
    expect(saved, model.captureFramePngResult);
  });

  testWidgets('screenshot row hidden when showCaptureButton is false', (
    tester,
  ) async {
    await pumpChrome(
      tester,
      showCaptureButton: false,
      onScreenshot: (_) async {},
    );
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('截图'), findsNothing);
  });

  testWidgets('BiliBottomChrome is present in the material controls tree', (
    tester,
  ) async {
    await pumpChrome(tester);
    expect(find.byType(BiliBottomChrome), findsOneWidget);
  });
}
