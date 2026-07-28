import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'init_timing.dart';
import 'gstp_bindings.dart';

/// Loads the native player library and exposes [GstpBindings].
class GstpLibrary {
  GstpLibrary._(this.bindings);

  final GstpBindings bindings;

  static GstpLibrary? _instance;

  /// Process-wide singleton.
  static GstpLibrary get instance => _instance ??= GstpLibrary._(_open());

  static bool get isInitialized => _instance != null;

  static GstpBindings _open() {
    return gstpTimed('dylib_open', () {
      final DynamicLibrary dylib;
      if (Platform.isMacOS || Platform.isIOS) {
        dylib = DynamicLibrary.process();
      } else if (Platform.isAndroid) {
        dylib = DynamicLibrary.open('libgstplayer.so');
      } else if (Platform.isWindows) {
        dylib = DynamicLibrary.open('gstplayer_plugin.dll');
      } else if (Platform.isLinux) {
        dylib = DynamicLibrary.open('libgstplayer_plugin.so');
      } else {
        throw UnsupportedError('Unsupported platform for GstpLibrary');
      }
      return GstpBindings(dylib);
    });
  }

  /// For host unit tests that load a built dylib by path.
  static GstpLibrary openPath(String path) {
    final lib = GstpLibrary._(GstpBindings(DynamicLibrary.open(path)));
    _instance = lib;
    return lib;
  }

  String version() {
    final ptr = bindings.gstp_version();
    return ptr.cast<Utf8>().toDartString();
  }

  int init() => bindings.gstp_init();

  void shutdown() => bindings.gstp_shutdown();
}
