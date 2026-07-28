import 'package:flutter/foundation.dart';
import 'package:gstplayer/src/enum/video_rotation.dart';
import 'package:gstplayer/src/presentation/playback_presentation_model.dart';
import 'package:gstplayer/src/domain/player_events.dart';

/// Test double for [PlaybackPresentationModel].
class FakePlaybackPresentationModel extends ChangeNotifier
    implements PlaybackPresentationModel {
  FakePlaybackPresentationModel({
    this.playerId = 42,
    this.initialized = true,
    this.aspectRatio = 16 / 9,
    this.videoRotation = VideoRotation.deg0,
    this.state = PlayerState.idle,
    this.bufferingPercent = 100,
  });

  @override
  int? playerId;

  @override
  final bool initialized;

  @override
  double aspectRatio;

  @override
  VideoRotation videoRotation;

  @override
  PlayerState state;

  @override
  int bufferingPercent;

  AspectRatioMode? lastAspectRatioMode;
  int setAspectRatioModeCallCount = 0;

  @override
  Future<void> setAspectRatioMode(AspectRatioMode mode) async {
    setAspectRatioModeCallCount++;
    lastAspectRatioMode = mode;
  }

  void setState(PlayerState value) {
    state = value;
    notifyListeners();
  }

  void setBufferingPercent(int value) {
    bufferingPercent = value;
    notifyListeners();
  }

  void setAspectRatio(double value) {
    aspectRatio = value;
    notifyListeners();
  }

  void setVideoRotation(VideoRotation value) {
    videoRotation = value;
    notifyListeners();
  }

  void setPlayerId(int? value) {
    playerId = value;
    notifyListeners();
  }
}
