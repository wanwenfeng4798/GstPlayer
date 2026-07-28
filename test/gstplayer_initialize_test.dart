import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/ffi/gstp_library.dart';
import 'package:gstplayer/src/player/ffi_native_worker.dart';
import 'package:gstplayer/gstplayer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize is kickoff-only; ensureReady warms runtime', () async {
    final dylib = _hostDylibPath();
    if (dylib == null) {
      // Skip when native host lib was not built in this environment.
      return;
    }
    GstpLibrary.openPath(dylib);

    await GstPlayer.initialize();
    // Kickoff must not require full gst_init; isInitialized may still be false.
    expect(GstpLibrary.isInitialized, isTrue);

    await GstPlayer.ensureReady();
    expect(GstPlayer.isInitialized, isTrue);
    expect(FfiNativeWorker.isStarted, isTrue);
  });
}

String? _hostDylibPath() {
  final dylib =
      '${Directory.current.path}/native/build/host/libgstplayer.dylib';
  if (File(dylib).existsSync()) {
    return dylib;
  }
  final so =
      '${Directory.current.path}/native/build/host/libgstplayer.so';
  if (File(so).existsSync()) {
    return so;
  }
  return null;
}
