import 'package:chat_context_menu/chat_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gstplayer/gstplayer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GST视频播放器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.pink,
        useMaterial3: true,
        extensions: [VideoControlsTheme.bilibili()],
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.pink,
        brightness: Brightness.dark,
        useMaterial3: true,
        extensions: [VideoControlsTheme.bilibili()],
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST视频播放器')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PlayerPage()),
            );
          },
          child: const Text('进入播放页'),
        ),
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final GstPlayerController _controller = GstPlayerController();

  bool _ready = false;
  String? _initError;

  static const _networkSamples = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  ];

  static const _assetSource = VideoSource.asset('assets/sample.mp4');

  List<SubtitleCue> _subtitles = const [];
  bool _subtitlesEnabled = true;
  bool _danmakuEnabled = true;
  ScrubPreviewTrack? _scrubPreview;

  List<DanmakuItem> _danmaku = [
    const DanmakuItem(at: Duration(seconds: 1), text: '开始播放！'),
    DanmakuItem(
      at: const Duration(seconds: 2),
      text: '拖动进度条看小窗预览（WebVTT 雪碧图）',
      color: Colors.lightBlueAccent.shade100,
    ),
    const DanmakuItem(
      at: Duration(seconds: 4),
      text: '底栏可发弹幕、开关字幕',
      color: Color(0xFFFFD54F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final sw = Stopwatch()..start();
    _controller
        .initialize()
        .then((_) async {
          debugPrint(
            '[gstp-init-timing] example_controller_init='
            '${sw.elapsedMilliseconds}ms '
            'playerId=${_controller.playerId}',
          );
          await _prepareSubtitlesAndPreview();
          if (mounted) setState(() => _ready = true);
        })
        .catchError((Object e, StackTrace st) {
          debugPrint('gstplayer initialize failed: $e\n$st');
          if (mounted) {
            setState(() {
              _initError = e.toString();
              _ready = true;
            });
          }
        });
  }

  Future<void> _prepareSubtitlesAndPreview() async {
    try {
      _subtitles = await SubtitleParser.loadAsset('assets/sample.srt');
    } catch (e) {
      debugPrint('load subtitles failed: $e');
    }
    try {
      final vtt = await rootBundle.loadString('assets/sample_preview.vtt');
      _scrubPreview = ScrubPreviewTrack.vtt(vtt);
    } catch (e) {
      debugPrint('load scrub preview vtt failed: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAsset() async {
    await _controller.open(_assetSource, autoPlay: true);
  }

  void _sendDanmaku(String text) {
    final at = _controller.position;
    setState(() {
      _danmaku = [
        ..._danmaku,
        DanmakuItem(
          at: at,
          text: text,
          color: Colors.white,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isFullscreen = _controller.isFullscreen;
        return Scaffold(
          appBar: isFullscreen
              ? null
              : AppBar(
                  title: const Text('播放'),
                  toolbarHeight: 48,
                  actions: [
                    ChatContextMenuWrapper(
                      backgroundColor: Colors.white,
                      widgetBuilder: (context, shoeMenu, hideMenu) {
                        return TextButton(
                          onPressed: shoeMenu,
                          style: TextButton.styleFrom(
                            tapTargetSize: .shrinkWrap,
                            visualDensity: .compact,
                          ),
                          child: const Text('网络'),
                        );
                      },
                      menuBuilder: ((context, hideMenu) {
                        return Column(
                          mainAxisSize: .min,
                          crossAxisAlignment: .start,
                          children: List.generate(_networkSamples.length, (
                            index,
                          ) {
                            final media = _networkSamples[index];
                            return TextButton(
                              onPressed: () {
                                _controller.open(
                                  VideoSource.network(media),
                                  autoPlay: true,
                                );
                                hideMenu();
                              },
                              child: Text(media.split('/').last),
                            );
                          }),
                        );
                      }),
                    ),
                    TextButton(
                      onPressed: _openAsset,
                      style: TextButton.styleFrom(
                        tapTargetSize: .shrinkWrap,
                        visualDensity: .compact,
                      ),
                      child: const Text('本地'),
                    ),
                  ],
                ),
          body: !_ready
              ? const Center(child: CircularProgressIndicator())
              : _initError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      '初始化失败: $_initError',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : ColoredBox(
                  color: Colors.black,
                  child: GstVideoView(
                    controller: _controller,
                    showControls: true,
                    controlsStyle: .cupertino,
                    scrubPreview: _scrubPreview,
                    keepLastFrame: true,
                    danmaku: _danmaku,
                    danmakuEnabled: _danmakuEnabled,
                    onDanmakuSend: _sendDanmaku,
                    onDanmakuEnabledChanged: (enabled) {
                      setState(() => _danmakuEnabled = enabled);
                    },
                    onSubtitlesEnabledChanged: (enabled) {
                      setState(() => _subtitlesEnabled = enabled);
                    },
                    subtitles: _subtitles,
                    subtitlesEnabled: _subtitlesEnabled,
                    showCaptureButton: true,
                  ),
                ),
        );
      },
    );
  }
}
