import 'package:flutter/painting.dart';

/// One scrub-preview frame (GSY-style WebVTT cue or sprite cell) /
/// 进度条预览的一帧（WebVTT cue 或雪碧图格子）.
class ScrubPreviewFrame {
  /// Creates a preview frame / 创建预览帧.
  const ScrubPreviewFrame({
    required this.start,
    required this.end,
    required this.image,
    this.crop,
  });

  /// Inclusive start of the cue range / cue 起始时间（含）.
  final Duration start;

  /// Exclusive end of the cue range / cue 结束时间（不含）.
  final Duration end;

  /// Full image or sprite sheet / 整图或雪碧图.
  final ImageProvider image;

  /// Absolute pixel crop `xywh` on [image]; null means use the whole image /
  /// 在 [image] 上的绝对像素裁剪；null 表示整图.
  final Rect? crop;

  bool contains(Duration position) =>
      !position.isNegative && position >= start && position < end;
}

/// External scrub thumbnail track (no live frame capture) /
/// 外部传入的进度条缩略图轨（不实时抽帧）.
///
/// Matches GSYVideoPlayer's WebVTT seek-preview model: the host supplies a
/// thumbnail track (VTT cues, sprite sheet, or prebuilt frames). Dragging the
/// progress bar only picks a frame by time.
sealed class ScrubPreviewTrack {
  const ScrubPreviewTrack();

  /// Prebuilt frames with [ImageProvider]s (app-owned URLs/assets/memory).
  const factory ScrubPreviewTrack.frames(List<ScrubPreviewFrame> frames) =
      ScrubPreviewTrackFrames;

  /// Uniform grid sprite sheet (left→right, top→bottom), one cell per [interval].
  const factory ScrubPreviewTrack.sprite({
    required ImageProvider image,
    required int columns,
    required int rows,
    required Duration interval,
  }) = ScrubPreviewTrackSprite;

  /// WebVTT thumbnail track text (GSY `setPreviewVttUrl` content).
  ///
  /// Cue bodies are image URLs, optionally with `#xywh=x,y,w,h` sprite crop.
  /// Relative URLs resolve against [baseUri].
  factory ScrubPreviewTrack.vtt(String raw, {Uri? baseUri}) =
      ScrubPreviewTrackVtt.parse;

  /// Resolve the frame for [position], or null if outside all cues.
  ScrubPreviewFrame? frameAt(Duration position);
}

/// [ScrubPreviewTrack] backed by an explicit frame list.
final class ScrubPreviewTrackFrames extends ScrubPreviewTrack {
  /// Creates a track from [frames] / 由帧列表创建.
  const ScrubPreviewTrackFrames(this.frames);

  final List<ScrubPreviewFrame> frames;

  @override
  ScrubPreviewFrame? frameAt(Duration position) {
    for (final frame in frames) {
      if (frame.contains(position)) return frame;
    }
    if (frames.isEmpty) return null;
    // Clamp to last cue when past the end (scrub near EOS).
    final last = frames.last;
    if (position >= last.start) return last;
    return null;
  }
}

/// Uniform sprite-sheet track.
final class ScrubPreviewTrackSprite extends ScrubPreviewTrack {
  /// Creates a sprite track / 创建雪碧图轨.
  const ScrubPreviewTrackSprite({
    required this.image,
    required this.columns,
    required this.rows,
    required this.interval,
  }) : assert(columns > 0),
       assert(rows > 0),
       assert(interval > Duration.zero);

  final ImageProvider image;
  final int columns;
  final int rows;
  final Duration interval;

  int get cellCount => columns * rows;

  @override
  ScrubPreviewFrame? frameAt(Duration position) {
    if (position.isNegative) return null;
    final index = (position.inMilliseconds / interval.inMilliseconds)
        .floor()
        .clamp(0, cellCount - 1);
    final col = index % columns;
    final row = index ~/ columns;
    final start = interval * index;
    final end = start + interval;
    // Fractional crop in 0..1 of the full sprite (resolved at paint time).
    return ScrubPreviewFrame(
      start: start,
      end: end,
      image: image,
      crop: Rect.fromLTWH(
        col / columns,
        row / rows,
        1 / columns,
        1 / rows,
      ),
    );
  }
}

/// WebVTT thumbnail track (GSY-compatible).
final class ScrubPreviewTrackVtt extends ScrubPreviewTrackFrames {
  ScrubPreviewTrackVtt._(super.frames);

  /// Parses WebVTT thumbnail cues / 解析 WebVTT 缩略图 cue.
  factory ScrubPreviewTrackVtt.parse(String raw, {Uri? baseUri}) {
    final frames = ScrubPreviewVttParser.parse(raw, baseUri: baseUri);
    return ScrubPreviewTrackVtt._(frames);
  }
}

/// Parses GSY-style WebVTT seek-preview tracks /
/// 解析 GSY 风格 WebVTT 进度预览轨.
///
/// Example cue body: `thumbs.jpg#xywh=0,0,160,90`
abstract final class ScrubPreviewVttParser {
  /// Parses [raw] VTT into frames / 解析 VTT 为帧列表.
  static List<ScrubPreviewFrame> parse(String raw, {Uri? baseUri}) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final body = normalized.trimLeft().startsWith('WEBVTT')
        ? normalized.replaceFirst(RegExp(r'^WEBVTT[^\n]*\n'), '')
        : normalized;

    final blocks = body.split(RegExp(r'\n\s*\n'));
    final frames = <ScrubPreviewFrame>[];
    final timeRe = RegExp(
      r'(\d{1,2}:\d{2}:\d{2}(?:[,.]\d{1,3})?)\s*-->\s*'
      r'(\d{1,2}:\d{2}:\d{2}(?:[,.]\d{1,3})?)',
    );
    final xywhRe = RegExp(r'#xywh=([\d.]+),([\d.]+),([\d.]+),([\d.]+)$');

    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) continue;
      var idx = 0;
      if (RegExp(r'^\d+$').hasMatch(lines[0])) idx = 1;
      if (idx >= lines.length) continue;
      final match = timeRe.firstMatch(lines[idx]);
      if (match == null) continue;
      final start = _parseTimestamp(match.group(1)!);
      final end = _parseTimestamp(match.group(2)!);
      if (idx + 1 >= lines.length) continue;
      final payload = lines[idx + 1];
      final xywh = xywhRe.firstMatch(payload);
      final urlPart = xywh != null
          ? payload.substring(0, xywh.start)
          : payload;
      final resolved = _resolveImageUri(urlPart.trim(), baseUri);
      if (resolved == null) continue;
      final image = resolved.image;
      Rect? crop;
      if (xywh != null) {
        crop = Rect.fromLTWH(
          double.parse(xywh.group(1)!),
          double.parse(xywh.group(2)!),
          double.parse(xywh.group(3)!),
          double.parse(xywh.group(4)!),
        );
      }
      frames.add(
        ScrubPreviewFrame(
          start: start,
          end: end,
          image: image,
          crop: crop,
        ),
      );
    }
    return frames;
  }

  static _ResolvedPreviewImage? _resolveImageUri(String value, Uri? baseUri) {
    if (value.isEmpty) return null;
    if (value.startsWith('assets/')) {
      return _ResolvedPreviewImage.asset(value);
    }
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      if (parsed.scheme == 'asset') {
        final path = parsed.path.startsWith('/')
            ? parsed.path.substring(1)
            : parsed.path;
        return _ResolvedPreviewImage.asset(path);
      }
      return _ResolvedPreviewImage.network(parsed.toString());
    }
    if (baseUri == null) {
      if (value.startsWith('/')) {
        return _ResolvedPreviewImage.network(Uri.parse('file://$value').toString());
      }
      return _ResolvedPreviewImage.network(value);
    }
    return _ResolvedPreviewImage.network(baseUri.resolveUri(parsed).toString());
  }

  static Duration _parseTimestamp(String value) {
    final cleaned = value.replaceAll(',', '.');
    final parts = cleaned.split(':');
    if (parts.length != 3) return Duration.zero;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final seconds = int.tryParse(secParts[0]) ?? 0;
    var millis = 0;
    if (secParts.length > 1) {
      final frac = secParts[1].padRight(3, '0').substring(0, 3);
      millis = int.tryParse(frac) ?? 0;
    }
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }
}

class _ResolvedPreviewImage {
  const _ResolvedPreviewImage._(this.image);

  factory _ResolvedPreviewImage.asset(String path) =>
      _ResolvedPreviewImage._(AssetImage(path));

  factory _ResolvedPreviewImage.network(String url) =>
      _ResolvedPreviewImage._(NetworkImage(url));

  final ImageProvider image;
}
