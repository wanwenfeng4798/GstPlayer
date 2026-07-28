import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/ffi/gstp_library.dart';

void main() {
  test('gstp_version from host dylib', () {
    final path =
        '${Directory.current.path}/native/build/host/libgstplayer.dylib';
    if (!File(path).existsSync()) {
      // Also accept .so on Linux CI.
      final so =
          '${Directory.current.path}/native/build/host/libgstplayer.so';
      if (!File(so).existsSync()) {
        // Skip when native host lib was not built in this environment.
        return;
      }
      GstpLibrary.openPath(so);
    } else {
      GstpLibrary.openPath(path);
    }
    expect(GstpLibrary.instance.version(), isNotEmpty);
    expect(GstpLibrary.instance.init(), 0);
  });
}
