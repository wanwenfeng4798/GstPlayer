import 'dart:async';

import 'package:flutter/foundation.dart';

import '../gstplayer.dart' show GstPlayer;
import '../model/video_source.dart';
import '../utils/time_util.dart';

/// Debounced scrub-bar thumbnail requests / 进度条拖拽缩略图（防抖）.
class ScrubPreviewController extends ChangeNotifier {
  /// Creates a scrub preview controller / 创建 scrub 预览控制器.
  ScrubPreviewController({this.debounce = const Duration(milliseconds: 100)});

  /// Debounce before issuing [GstPlayer.captureThumbnail].
  final Duration debounce;

  Timer? _timer;
  int _seq = 0;
  bool _visible = false;
  double _fraction = 0;
  Duration _at = Duration.zero;
  Uint8List? _png;
  bool _loading = false;
  VideoSource? _source;

  bool get visible => _visible;
  double get fraction => _fraction;
  Duration get at => _at;
  Uint8List? get png => _png;
  bool get loading => _loading;
  String get timeLabel => formatDuration(_at);

  /// Bind the media used for headless thumbnail capture / 绑定抽帧媒体源.
  void setSource(VideoSource? source) {
    if (_source == source) return;
    _source = source;
    clear();
  }

  /// Show preview at [fraction] of [duration] / 按进度分数显示预览.
  void updatePreview({
    required double fraction,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) {
      clear();
      return;
    }
    final clamped = fraction.clamp(0.0, 1.0);
    final at = Duration(
      milliseconds: (clamped * duration.inMilliseconds).round(),
    );
    _visible = true;
    _fraction = clamped;
    _at = at;
    notifyListeners();

    final source = _source;
    if (source == null) return;

    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_fetch(source, at)));
  }

  /// Hide bubble and cancel pending work / 隐藏并取消待处理请求.
  void clear() {
    _timer?.cancel();
    _timer = null;
    _seq++;
    final changed = _visible || _png != null || _loading;
    _visible = false;
    _png = null;
    _loading = false;
    if (changed) notifyListeners();
  }

  Future<void> _fetch(VideoSource source, Duration at) async {
    final seq = ++_seq;
    _loading = true;
    notifyListeners();
    try {
      final png = await GstPlayer.captureThumbnail(
        source,
        at: at,
        maxWidth: 160,
      );
      if (seq != _seq) return;
      _png = png;
      _loading = false;
      notifyListeners();
    } catch (_) {
      if (seq != _seq) return;
      _png = null;
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
