import 'package:flutter/foundation.dart';

import '../utils/time_util.dart';
import 'scrub_preview_track.dart';

/// Drag-only scrub preview driven by an external [ScrubPreviewTrack] /
/// 仅拖动时显示；预览帧来自外部传入的缩略图轨（不实时抽帧）.
class ScrubPreviewController extends ChangeNotifier {
  /// Creates a scrub preview controller / 创建 scrub 预览控制器.
  ScrubPreviewController({this._track});

  ScrubPreviewTrack? _track;
  bool _visible = false;
  double _fraction = 0;
  Duration _at = Duration.zero;
  ScrubPreviewFrame? _frame;

  bool get visible => _visible;
  double get fraction => _fraction;
  Duration get at => _at;
  ScrubPreviewFrame? get frame => _frame;
  bool get hasTrack => _track != null;
  String get timeLabel => formatDuration(_at);

  /// Replace the external thumbnail track / 替换外部缩略图轨.
  void setTrack(ScrubPreviewTrack? track) {
    if (identical(_track, track)) return;
    _track = track;
    if (_visible) {
      _frame = _track?.frameAt(_at);
    }
    notifyListeners();
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
    _frame = _track?.frameAt(at);
    notifyListeners();
  }

  /// Hide bubble / 隐藏预览气泡.
  void clear() {
    final changed = _visible || _frame != null;
    _visible = false;
    _frame = null;
    if (changed) notifyListeners();
  }
}
