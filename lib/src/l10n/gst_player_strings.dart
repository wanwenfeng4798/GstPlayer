import '../controls/fullscreen_config.dart';
import 'gst_player_language.dart';

/// Built-in player chrome copy for [GstPlayerLanguage.zh] / [GstPlayerLanguage.en].
class GstPlayerStrings {
  /// Strings for [language] / 返回对应语言文案.
  factory GstPlayerStrings.of(GstPlayerLanguage language) {
    return switch (language) {
      GstPlayerLanguage.zh => const GstPlayerStrings._zh(),
      GstPlayerLanguage.en => const GstPlayerStrings._en(),
    };
  }

  const GstPlayerStrings._({
    required this.danmakuHint,
    required this.send,
    required this.closeDanmaku,
    required this.openDanmaku,
    required this.closeSubtitles,
    required this.openSubtitles,
    required this.settings,
    required this.mirror,
    required this.loopSingle,
    required this.autoPlay,
    required this.morePlaybackSettings,
    required this.back,
    required this.playbackMethod,
    required this.pauseAtEnd,
    required this.playNext,
    required this.videoAspect,
    required this.ratio16_9,
    required this.ratio4_3,
    required this.otherSettings,
    required this.hideBlackBars,
    required this.lightsOff,
    required this.audioTrack,
    required this.noAudioTracks,
    required this.onLabel,
    required this.offLabel,
    required this.untitledAudioTrack,
    required this.lockControls,
    required this.unlockControls,
    required this.aspectRatioLabels,
    required this.orientationLabels,
  });

  const GstPlayerStrings._zh()
    : this._(
        danmakuHint: '发个弹幕呗～',
        send: '发送',
        closeDanmaku: '关闭弹幕',
        openDanmaku: '打开弹幕',
        closeSubtitles: '关闭字幕',
        openSubtitles: '打开字幕',
        settings: '设置',
        mirror: '镜像画面',
        loopSingle: '单集循环',
        autoPlay: '自动播放',
        morePlaybackSettings: '更多播放设置',
        back: '返回',
        playbackMethod: '播放方式',
        pauseAtEnd: '播放暂停',
        playNext: '播完切下一集',
        videoAspect: '视频比例',
        ratio16_9: '16:9',
        ratio4_3: '4:3',
        otherSettings: '其他设置',
        hideBlackBars: '隐藏黑边',
        lightsOff: '关灯模式',
        audioTrack: '音轨',
        noAudioTracks: '暂无音轨',
        onLabel: '开',
        offLabel: '关',
        untitledAudioTrack: '音轨',
        lockControls: '锁屏',
        unlockControls: '解锁',
        aspectRatioLabels: const AspectRatioModeLabels(),
        orientationLabels: const VideoRotationLabels(),
      );

  const GstPlayerStrings._en()
    : this._(
        danmakuHint: 'Send a danmaku~',
        send: 'Send',
        closeDanmaku: 'Turn off danmaku',
        openDanmaku: 'Turn on danmaku',
        closeSubtitles: 'Turn off subtitles',
        openSubtitles: 'Turn on subtitles',
        settings: 'Settings',
        mirror: 'Mirror video',
        loopSingle: 'Loop episode',
        autoPlay: 'Auto play',
        morePlaybackSettings: 'More playback settings',
        back: 'Back',
        playbackMethod: 'Playback mode',
        pauseAtEnd: 'Pause when finished',
        playNext: 'Play next episode',
        videoAspect: 'Aspect ratio',
        ratio16_9: '16:9',
        ratio4_3: '4:3',
        otherSettings: 'Other',
        hideBlackBars: 'Hide black bars',
        lightsOff: 'Lights off',
        audioTrack: 'Audio track',
        noAudioTracks: 'No audio tracks',
        onLabel: 'On',
        offLabel: 'Off',
        untitledAudioTrack: 'Track',
        lockControls: 'Lock controls',
        unlockControls: 'Unlock controls',
        aspectRatioLabels: const AspectRatioModeLabels(
          fit: 'Fit',
          fill: 'Fill',
          stretch: 'Stretch',
        ),
        orientationLabels: const VideoRotationLabels(rotateAngle: 'Rotation'),
      );

  final String danmakuHint;
  final String send;
  final String closeDanmaku;
  final String openDanmaku;
  final String closeSubtitles;
  final String openSubtitles;
  final String settings;
  final String mirror;
  final String loopSingle;
  final String autoPlay;
  final String morePlaybackSettings;
  final String back;
  final String playbackMethod;
  final String pauseAtEnd;
  final String playNext;
  final String videoAspect;
  final String ratio16_9;
  final String ratio4_3;
  final String otherSettings;
  final String hideBlackBars;
  final String lightsOff;
  final String audioTrack;
  final String noAudioTracks;
  final String onLabel;
  final String offLabel;
  final String untitledAudioTrack;
  final String lockControls;
  final String unlockControls;
  final AspectRatioModeLabels aspectRatioLabels;
  final VideoRotationLabels orientationLabels;

  /// Label for an untitled audio track / 未命名音轨文案.
  String audioTrackFallback(int id) => '$untitledAudioTrack $id';
}
