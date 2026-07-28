import 'package:flutter/foundation.dart';
import 'package:gstplayer/src/controls/playback_controls_model.dart';
import 'package:gstplayer/src/enum/video_rotation.dart';
import 'package:gstplayer/src/domain/player_events.dart';

/// Test double for [PlaybackControlsModel].
class FakePlaybackControlsModel extends ChangeNotifier
    implements PlaybackControlsModel {
  FakePlaybackControlsModel({
    PlayerState initialState = PlayerState.idle,
    Duration initialPosition = Duration.zero,
    Duration initialDuration = const Duration(seconds: 100),
    bool initialSeekable = true,
    bool supportsOrientation = true,
    VideoRotation initialRotation = VideoRotation.deg0,
  }) : _state = initialState,
       _position = initialPosition,
       _duration = initialDuration,
       _isSeekable = initialSeekable,
       _supportsOrientation = supportsOrientation,
       _videoRotation = initialRotation;

  PlayerState _state;
  Duration _position;
  Duration _duration;
  bool _isSeekable;
  bool _supportsOrientation;
  VideoRotation _videoRotation;
  bool _muted = false;
  double _volume = 1.0;
  bool _looping = false;
  double _speed = 1.0;
  int _bufferingPercent = 100;

  Duration? lastSeek;
  int seekCallCount = 0;
  int togglePlayPauseCallCount = 0;
  VideoRotation? lastVideoRotation;
  double? lastVolume;
  AspectRatioMode? lastAspectRatioMode;

  @override
  bool get isPlaying => _state == PlayerState.playing;

  @override
  PlayerState get state => _state;

  @override
  int get bufferingPercent => _bufferingPercent;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get isSeekable => _isSeekable;

  @override
  bool get muted => _muted;

  @override
  double get volume => _volume;

  @override
  bool get looping => _looping;

  @override
  double get speed => _speed;

  @override
  bool get supportsOrientation => _supportsOrientation;

  @override
  VideoRotation get videoRotation => _videoRotation;

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCallCount++;
    _state = _state == PlayerState.playing
        ? PlayerState.paused
        : PlayerState.playing;
    notifyListeners();
  }

  @override
  Future<void> toggleMuted() async {
    _muted = !_muted;
    notifyListeners();
  }

  @override
  Future<void> setLooping(bool looping) async {
    _looping = looping;
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    seekCallCount++;
    lastSeek = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
    _volume = volume;
    notifyListeners();
  }

  @override
  Future<void> setAspectRatioMode(AspectRatioMode mode) async {
    lastAspectRatioMode = mode;
  }

  @override
  Future<void> setVideoRotation(VideoRotation rotation) async {
    lastVideoRotation = rotation;
    _videoRotation = rotation;
    notifyListeners();
  }

  void setPosition(Duration position) {
    _position = position;
    notifyListeners();
  }

  void setState(PlayerState state) {
    _state = state;
    notifyListeners();
  }
}
