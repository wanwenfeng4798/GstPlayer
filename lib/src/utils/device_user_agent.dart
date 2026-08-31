import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ffi/gstp_library.dart';

const MethodChannel _textureChannel = MethodChannel('gstplayer/texture');

/// Resolves a device-appropriate HTTP User-Agent and applies it to native.
Future<void> configureDefaultHttpUserAgent() async {
  final ua = await resolveDeviceUserAgent();
  final ptr = ua.toNativeUtf8();
  try {
    GstpLibrary.instance.bindings.gstp_set_default_user_agent(ptr.cast());
  } finally {
    malloc.free(ptr);
  }
}

/// Platform User-Agent: system WebView / browser when available, else [fromPlatform].
Future<String> resolveDeviceUserAgent() async {
  try {
    final native = await _textureChannel.invokeMethod<String>(
      'getDefaultUserAgent',
    );
    if (native != null && native.trim().isNotEmpty) {
      return native.trim();
    }
  } on MissingPluginException {
    // Host tests without the platform plugin.
  } on PlatformException catch (e) {
    debugPrint('gstplayer: getDefaultUserAgent failed: $e');
  }
  return fromPlatform();
}

/// Last-resort UA when the platform channel cannot reach a real browser/WebView.
String fromPlatform() {
  final version = Platform.operatingSystemVersion;
  switch (Platform.operatingSystem) {
    case 'android':
      return 'Mozilla/5.0 (Linux; Android $version) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    case 'ios':
      final iosVer = version.replaceAll('.', '_').replaceAll(' ', '_');
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS $iosVer like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
          'Mobile/15E148 Safari/604.1';
    case 'macos':
      final macVer = version.replaceAll('.', '_');
      return 'Mozilla/5.0 (Macintosh; Intel Mac OS X $macVer) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';
    case 'windows':
      return 'Mozilla/5.0 (Windows NT $version; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    case 'linux':
      return 'Mozilla/5.0 (X11; Linux $version) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    default:
      return 'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Safari/537.36';
  }
}
