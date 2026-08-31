import 'package:flutter/foundation.dart';

import '../enum/video_rotation.dart';
import '../domain/player_events.dart';
import '../model/video_source.dart';

/// 内置视频控件窄接口：只读 transport 状态 + 命令 / Narrow seam for built-in controls: readonly transport state and commands.
///
/// 由 [GstPlayerController] 实现；[VideoControls] 及其子组件依赖此接口。
/// Implemented by [GstPlayerController]; [VideoControls] and child widgets depend on it.
abstract class PlaybackControlsModel implements Listenable {
  /// 当前媒体代数；[open] 时递增，供 scrub 等 UI 重置 / Media generation; increments on [open].
  int get mediaGeneration => 0;

  PlayerState get state;
  int get bufferingPercent;
  bool get isPlaying;
  Duration get position;
  Duration get duration;
  bool get isSeekable;
  bool get muted;
  double get volume;
  bool get looping;
  double get speed;

  /// 当前已打开的媒体源（scrub 预览抽帧用）/ Open media source for scrub thumbnail capture.
  VideoSource? get mediaSource;

  /// 当前媒体轨道列表 / Current media tracks.
  List<MediaTrack> get tracks;

  /// 是否支持多轨选择 / Whether multi-track selection is supported.
  bool get supportsTracks;

  /// 当前 pipeline 是否支持视频旋转 / Whether rotation is supported.
  bool get supportsOrientation;

  /// 当前视频顺时针旋转角度 / Current clockwise video rotation.
  VideoRotation get videoRotation;

  Future<void> togglePlayPause();
  Future<void> toggleMuted();
  Future<void> setLooping(bool looping);
  Future<void> setSpeed(double speed);
  Future<void> seek(Duration position);

  /// 设置音量 0.0–1.0 / Sets volume in 0.0–1.0.
  Future<void> setVolume(double volume);

  /// 设置铺满模式并同步至 pipeline / Sets aspect ratio mode and syncs to pipeline.
  Future<void> setAspectRatioMode(AspectRatioMode mode);

  /// 设置视频顺时针旋转（需 [supportsOrientation]）/ Sets rotation when [supportsOrientation].
  Future<void> setVideoRotation(VideoRotation rotation);

  /// 选中或取消选中轨道 / Selects or deselects a track.
  Future<void> selectTrack(MediaTrack track, {bool enable = true});

  /// 截取当前帧 PNG（控件截图按钮）/ Captures current frame as PNG.
  Future<Uint8List?> captureFramePng();
}
