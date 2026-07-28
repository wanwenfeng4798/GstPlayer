import 'package:flutter/foundation.dart';
import 'package:gstplayer/src/enum/video_rotation.dart';
import 'package:gstplayer/src/presentation/playback_presentation_model.dart';
import 'package:gstplayer/src/domain/player_events.dart';

/// Test double for [PlaybackPresentationModel].
class FakePlaybackPresentationModel extends ChangeNotifier
    implements PlaybackPresentationModel {
  FakePlaybackPresentationModel({
    int? playerId = 42,
    bool initialized = true,
    double aspectRatio = 16 / 9,
    VideoRotation videoRotation = VideoRotation.deg0,
    PlayerState state = PlayerState.idle,
    int bufferingPercent = 100,
  }) : _playerId = playerId,
       _initialized = initialized,
       _aspectRatio = aspectRatio,
       _videoRotation = videoRotation,
       _state = state,
       _bufferingPercent = bufferingPercent;

  int? _playerId;
  bool _initialized;
  double _aspectRatio;
  VideoRotation _videoRotation;
  PlayerState _state;
  int _bufferingPercent;

  AspectRatioMode? lastAspectRatioMode;
  int setAspectRatioModeCallCount = 0;

  @override
  bool get initialized => _initialized;

  @override
  int? get playerId => _playerId;

  @override
  double get aspectRatio => _aspectRatio;

  @override
  VideoRotation get videoRotation => _videoRotation;

  @override
  PlayerState get state => _state;

  @override
  int get bufferingPercent => _bufferingPercent;

  @override
  Future<void> setAspectRatioMode(AspectRatioMode mode) async {
    setAspectRatioModeCallCount++;
    lastAspectRatioMode = mode;
  }

  void setState(PlayerState value) {
    _state = value;
    notifyListeners();
  }

  void setBufferingPercent(int value) {
    _bufferingPercent = value;
    notifyListeners();
  }

  void setAspectRatio(double value) {
    _aspectRatio = value;
    notifyListeners();
  }

  void setVideoRotation(VideoRotation value) {
    _videoRotation = value;
    notifyListeners();
  }

  void setPlayerId(int? value) {
    _playerId = value;
    notifyListeners();
  }
}
