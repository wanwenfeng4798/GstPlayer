import '../enum/video_source_type.dart';

/// 描述 [GstPlayerController] 应加载的媒体 / Describes the media a [GstPlayerController] should load.
///
/// [VideoSource] 仅包含 [uri]（地址/路径/资源键）与 [type]。使用命名构造函数：
/// A [VideoSource] carries [uri] (address, path, or asset key) and [type]. Use named constructors:
///
/// ```dart
/// controller.open(VideoSource.network('https://.../video.mp4'));
/// controller.open(VideoSource.network(
///   'https://.../video.mp4',
///   httpHeaders: {'Referer': 'https://example.com'},
/// ));
/// controller.open(VideoSource.file('/path/to/video.mp4'));
/// controller.open(const VideoSource.asset('assets/sample.mp4'));
/// ```
///
/// 经 [MediaSourceResolver] 转为 Rust [MediaSourceDto] 后交给 GStreamer pipeline。
/// Resolved to a Rust [MediaSourceDto] via [MediaSourceResolver] before entering the GStreamer pipeline.
class VideoSource {
  /// 远程 URL 媒体（`http(s)://`、`rtsp://` 等）/ Media served from a remote URL.
  const VideoSource.network(this.uri, {this.httpHeaders = const {}})
      : type = VideoSourceType.network;

  /// 本地文件路径或 `file://` URI / Local filesystem path or `file://` URI.
  const VideoSource.file(this.uri)
      : type = VideoSourceType.file,
        httpHeaders = const {};

  /// Flutter 资源键（如 `assets/sample.mp4`）/ Flutter asset key declared in `pubspec.yaml`.
  const VideoSource.asset(this.uri)
      : type = VideoSourceType.asset,
        httpHeaders = const {};

  /// 地址、本地路径或资源键，含义取决于 [type] / Address, path, or asset key depending on [type].
  final String uri;

  /// [uri] 的解析方式 / How [uri] is interpreted when loading.
  final VideoSourceType type;

  /// 网络播放时的自定义 HTTP 请求头（仅 [VideoSourceType.network] 有效）。
  final Map<String, String> httpHeaders;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoSource &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          type == other.type &&
          _mapEquals(httpHeaders, other.httpHeaders);

  @override
  int get hashCode => Object.hash(uri, type, _mapHash(httpHeaders));

  @override
  String toString() {
    if (httpHeaders.isEmpty) {
      return 'VideoSource(${type.name}, $uri)';
    }
    return 'VideoSource(${type.name}, $uri, headers: $httpHeaders)';
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<String, String> map) {
    var hash = 0;
    for (final entry in map.entries) {
      hash = Object.hash(hash, entry.key, entry.value);
    }
    return hash;
  }
}
