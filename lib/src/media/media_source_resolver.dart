import '../enum/video_source_type.dart';
import '../model/video_source.dart';
import '../domain/player_events.dart';

/// 将 Dart [VideoSource] 解析为 native [MediaSourceDto] / Resolves a Dart [VideoSource] into a native [MediaSourceDto].
///
/// 位于 Dart/native FFI 接缝，在 [PlaybackSession.open] 加载前执行。
/// Runs at the Dart/native seam before [PlaybackSession.open] loads the source.
class MediaSourceResolver {
  const MediaSourceResolver();

  /// 根据 [VideoSource.type] 选择 DTO 变体 / Picks the DTO variant from [VideoSource.type].
  ///
  /// # 返回值 / Returns
  /// - [VideoSourceType.asset] → [MediaSourceDto.flutterAsset]
  /// - [VideoSourceType.network] / [VideoSourceType.file] → [MediaSourceDto.uri]（file 无 scheme 时补 `file://`）
  MediaSourceDto resolve(VideoSource source) {
    switch (source.type) {
      case VideoSourceType.asset:
        return MediaSourceDto.flutterAsset(source.uri.trim());
      case VideoSourceType.network:
        return MediaSourceDto.uri(
          _resolveGstUri(source),
          httpHeaders: source.httpHeaders,
        );
      case VideoSourceType.file:
        return MediaSourceDto.uri(_resolveGstUri(source));
    }
  }

  static String _resolveGstUri(VideoSource source) {
    switch (source.type) {
      case VideoSourceType.network:
        return source.uri.trim();
      case VideoSourceType.file:
        final trimmed = source.uri.trim();
        final parsed = Uri.tryParse(trimmed);
        // Windows paths like `C:\...` / `C:/...` parse as scheme "C". Only keep
        // the string when it is a real URI scheme GStreamer understands.
        if (parsed != null &&
            parsed.hasScheme &&
            _isRealUriScheme(parsed.scheme)) {
          return trimmed;
        }
        return _fileUriFromPath(trimmed);
      case VideoSourceType.asset:
        return source.uri.trim();
    }
  }

  static String _fileUriFromPath(String path) {
    if (RegExp(r'^[A-Za-z]:[/\\]').hasMatch(path)) {
      final normalized = path.replaceAll('\\', '/');
      final withoutLeadingSlash = normalized.startsWith('/')
          ? normalized.substring(1)
          : normalized;
      return 'file:///$withoutLeadingSlash';
    }
    return Uri.file(path).toString();
  }

  static bool _isRealUriScheme(String scheme) {
    switch (scheme.toLowerCase()) {
      case 'file':
      case 'http':
      case 'https':
      case 'rtsp':
      case 'rtspt':
      case 'rtmp':
        return true;
      default:
        return false;
    }
  }
}
