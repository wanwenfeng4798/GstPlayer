import 'dart:typed_data';

import 'package:chat_context_menu/chat_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:gstplayer/gstplayer.dart';

import 'thumbnail_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No plugin kickoff here — open PlayerPage via HomePage to feel route jank
  // when controller.initialize() runs in initState (create awaits ensureReady).
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

/// Landing page with no player init — push [PlayerPage] to test transition jank.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST视频播放器')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PlayerPage()),
                );
              },
              child: const Text('进入播放页（initState 初始化）'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ThumbnailPage(),
                  ),
                );
              },
              child: const Text('抽封面'),
            ),
          ],
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

  final List<String> mediaList = ThumbnailPage.networkSamples;

  static const _assetSource = VideoSource.asset('assets/sample.mp4');

  List<SubtitleCue> _subtitles = const [];
  bool _subtitlesEnabled = true;
  bool _danmakuEnabled = true;
  ImageProvider? _poster;

  static final _sampleDanmaku = <DanmakuItem>[
    const DanmakuItem(at: Duration(seconds: 1), text: '开始播放！'),
    DanmakuItem(
      at: const Duration(seconds: 2),
      text: '音量滑轨 / 手势都在控件里',
      color: Colors.lightBlueAccent.shade100,
    ),
    const DanmakuItem(
      at: Duration(seconds: 4),
      text: '拖进度条看小窗预览',
      color: Color(0xFFFFD54F),
    ),
    DanmakuItem(
      at: const Duration(seconds: 6),
      text: '弹幕演示',
      color: Colors.pinkAccent.shade100,
    ),
    const DanmakuItem(at: Duration(seconds: 10), text: '字幕与弹幕可开关'),
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
          await _preparePosterAndSubtitles();
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

  Future<void> _preparePosterAndSubtitles() async {
    try {
      _subtitles = await SubtitleParser.loadAsset('assets/sample.srt');
    } catch (e) {
      debugPrint('load subtitles failed: $e');
    }
    try {
      final png = await GstPlayer.captureThumbnail(
        _assetSource,
        maxWidth: 480,
      );
      _poster = MemoryImage(png);
    } catch (e) {
      debugPrint('poster capture failed: $e');
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

  Future<void> _showPng(Uint8List png, String title) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Image.memory(png),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _captureCurrentFrame() async {
    try {
      final png = await _controller.captureCurrentFrame();
      await _showPng(png, '当前帧');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('截帧失败: $e')));
    }
  }

  void _openThumbnailPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ThumbnailPage()));
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
                    IconButton(
                      tooltip: _danmakuEnabled ? '关闭弹幕' : '打开弹幕',
                      onPressed: () {
                        setState(() => _danmakuEnabled = !_danmakuEnabled);
                      },
                      icon: Icon(
                        _danmakuEnabled
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                      ),
                    ),
                    IconButton(
                      tooltip: _subtitlesEnabled ? '关闭字幕' : '打开字幕',
                      onPressed: () {
                        setState(
                          () => _subtitlesEnabled = !_subtitlesEnabled,
                        );
                      },
                      icon: Icon(
                        _subtitlesEnabled
                            ? Icons.closed_caption
                            : Icons.closed_caption_disabled,
                      ),
                    ),
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
                          children: List.generate(mediaList.length, (index) {
                            final media = mediaList[index];
                            return TextButton(
                              onPressed: () {
                                _controller.open(
                                  VideoSource.network(media),
                                  autoPlay: true,
                                );
                                hideMenu();
                              },
                              child: Text(media),
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
                    TextButton(
                      onPressed: _openThumbnailPage,
                      style: TextButton.styleFrom(
                        tapTargetSize: .shrinkWrap,
                        visualDensity: .compact,
                      ),
                      child: const Text('抽封面'),
                    ),
                    TextButton(
                      onPressed: _captureCurrentFrame,
                      style: TextButton.styleFrom(
                        tapTargetSize: .shrinkWrap,
                        visualDensity: .compact,
                      ),
                      child: const Text('截帧'),
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
                    poster: _poster,
                    keepLastFrame: true,
                    danmaku: _sampleDanmaku,
                    danmakuEnabled: _danmakuEnabled,
                    subtitles: _subtitles,
                    subtitlesEnabled: _subtitlesEnabled,
                  ),
                ),
        );
      },
    );
  }
}
