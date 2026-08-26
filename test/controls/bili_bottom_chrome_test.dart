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
    Size size = const Size(800, 240),
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

  testWidgets('BiliBottomChrome is present in the material controls tree', (
    tester,
  ) async {
    await pumpChrome(tester);
    expect(find.byType(BiliBottomChrome), findsOneWidget);
  });
}
