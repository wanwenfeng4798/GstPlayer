import 'package:flutter/foundation.dart';

import '../domain/player_events.dart';
import '../enum/video_rotation.dart';

/// 视频呈现窄接口：表面路由、布局宽高比、加载指示 / Narrow seam for video presentation: surface routing, layout aspect, loading chrome.
///
/// 由 [GstPlayerController] 实现；[PlaybackPresentation] 与 [VideoControls] 分别依赖此接口与 [PlaybackControlsModel]。
/// Implemented by [GstPlayerController]; [PlaybackPresentation] and [VideoControls] depend on this and [PlaybackControlsModel] respectively.
abstract class PlaybackPresentationModel implements Listenable {
  /// 播放器是否已初始化 / Whether the player is initialized.
  bool get initialized;

  /// 原生 player ID；null 时不渲染表面 / Native player id; no surface when null.
  int? get playerId;

  /// 当前显示宽高比 / Current display aspect ratio.
  double get aspectRatio;

  /// 当前视频顺时针旋转 / Current clockwise video rotation.
  VideoRotation get videoRotation;

  /// 播放状态 / Playback state.
  PlayerState get state;

  /// 缓冲进度 0–100 / Buffering percent 0–100.
  int get bufferingPercent;

  /// 同步宽高比模式至 native pipeline / Syncs aspect ratio mode to the native pipeline.
  Future<void> setAspectRatioMode(AspectRatioMode mode);
}
