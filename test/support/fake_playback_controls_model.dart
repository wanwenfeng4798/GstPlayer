import 'package:flutter/foundation.dart';
import 'package:gstplayer/src/controls/playback_controls_model.dart';
import 'package:gstplayer/src/enum/video_rotation.dart';
import 'package:gstplayer/src/domain/player_events.dart';
import 'package:gstplayer/src/model/video_source.dart';

/// Test double for [PlaybackControlsModel].
class FakePlaybackControlsModel extends ChangeNotifier
    implements PlaybackControlsModel {
  FakePlaybackControlsModel({
    PlayerState initialState = PlayerState.idle,
    Duration initialPosition = Duration.zero,
    this.duration = const Duration(seconds: 100),
    this.isSeekable = true,
    this.supportsOrientation = true,
    this.supportsTracks = true,
    this.bufferingPercent = 100,
    this.mediaSource,
    List<MediaTrack> tracks = const [],
    VideoRotation initialRotation = VideoRotation.deg0,
  }) : _state = initialState,
       _position = initialPosition,
       _videoRotation = initialRotation,
       _tracks = List<MediaTrack>.from(tracks);

  List<MediaTrack> _tracks;

  PlayerState _state;
  Duration _position;
  VideoRotation _videoRotation;
  bool _muted = false;
  double _volume = 1.0;
  bool _looping = false;
  double _speed = 1.0;

  @override
  final Duration duration;

  @override
  final bool isSeekable;

  @override
  final bool supportsOrientation;

  @override
  final bool supportsTracks;

  @override
  final int bufferingPercent;

  @override
  final VideoSource? mediaSource;

  @override
  List<MediaTrack> get tracks => List<MediaTrack>.unmodifiable(_tracks);

  Duration? lastSeek;
  int seekCallCount = 0;
  int togglePlayPauseCallCount = 0;
  VideoRotation? lastVideoRotation;
  double? lastVolume;
  AspectRatioMode? lastAspectRatioMode;
  MediaTrack? lastSelectedTrack;
  bool? lastSelectTrackEnable;
  int captureFramePngCallCount = 0;
  Uint8List captureFramePngResult = Uint8List.fromList([1, 2, 3]);

  @override
  bool get isPlaying => _state == PlayerState.playing;

  @override
  final int mediaGeneration = 0;

  @override
  PlayerState get state => _state;

  @override
  Duration get position => _position;

  @override
  bool get muted => _muted;

  @override
  double get volume => _volume;

  @override
  bool get looping => _looping;

  @override
  double get speed => _speed;

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

  @override
  Future<void> selectTrack(MediaTrack track, {bool enable = true}) async {
    lastSelectedTrack = track;
    lastSelectTrackEnable = enable;
    _tracks = [
      for (final item in _tracks)
        if (item.id == track.id && item.trackType == track.trackType)
          MediaTrack(
            id: item.id,
            trackType: item.trackType,
            language: item.language,
            label: item.label,
            selected: enable,
          )
        else
          item,
    ];
    notifyListeners();
  }

  @override
  Future<Uint8List?> captureFramePng() async {
    captureFramePngCallCount++;
    return captureFramePngResult;
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
