import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:gstplayer/gstplayer.dart';

import 'screenshot_saver.dart';
import 'custom_url_dialog.dart';

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

  // Public progressive downloads (mp4 / mkv / webm / mov / avi). Avoid Google
  // gtv-videos-bucket — often unreachable in some networks.
  static const _networkSamples = [
    'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4',
    'https://test-videos.co.uk/vids/bigbuckbunny/mkv/360/Big_Buck_Bunny_360_10s_1MB.mkv',
    'https://test-videos.co.uk/vids/bigbuckbunny/webm/vp9/360/Big_Buck_Bunny_360_10s_1MB.webm',
    'https://filesamples.com/samples/video/mov/sample_640x360.mov',
    'https://filesamples.com/samples/video/avi/sample_640x360.avi',
    'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
  ];

  static const _assetSource = VideoSource.asset('assets/sample.mp4');

  List<SubtitleCue> _subtitles = const [];
  bool _subtitlesEnabled = true;
  bool _danmakuEnabled = true;
  bool _lightsOff = false;
  int _networkIndex = 0;
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
    _controller
        .initialize()
        .then((_) async {
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

  Future<void> _openCustomUrl() async {
    final result = await showCustomUrlDialog(context);
    if (result == null || !mounted) return;
    await _controller.open(
      VideoSource.network(result.url, httpHeaders: result.headers),
      autoPlay: true,
    );
  }

  void _playNext() {
    _networkIndex = (_networkIndex + 1) % _networkSamples.length;
    _controller.open(
      VideoSource.network(_networkSamples[_networkIndex]),
      autoPlay: true,
    );
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
        final hideChrome = isFullscreen || _lightsOff;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: hideChrome
              ? null
              : AppBar(
                  title: const Text('播放'),
                  toolbarHeight: 48,
                  actions: [
                    PopupMenuButton<String>(
                      tooltip: '网络',
                      onSelected: (media) {
                        _controller.open(
                          VideoSource.network(media),
                          autoPlay: true,
                        );
                      },
                      itemBuilder: (context) => [
                        for (final media in _networkSamples)
                          PopupMenuItem(
                            value: media,
                            child: Text(media.split('/').last),
                          ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('网络'),
                      ),
                    ),
                    TextButton(
                      onPressed: _openCustomUrl,
                      style: TextButton.styleFrom(
                        tapTargetSize: .shrinkWrap,
                        visualDensity: .compact,
                      ),
                      child: const Text('自定义'),
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
                    language: GstPlayerLanguage.zh,
                    onPlayNext: _playNext,
                    onLightsOffChanged: (enabled) {
                      setState(() => _lightsOff = enabled);
                    },
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
                    onScreenshot: (png) => saveScreenshotPng(context, png),
                  ),
                ),
        );
      },
    );
  }
}
