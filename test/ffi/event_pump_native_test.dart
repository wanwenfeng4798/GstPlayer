import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/ffi/event_pump.dart';
import 'package:gstplayer/src/ffi/gstp_library.dart';
import 'package:gstplayer/src/domain/player_events.dart';

void main() {
  final path = '${Directory.current.path}/native/build/host/libgstplayer.dylib';
  test(
    'queued native events keep owned strings and detach drains before close',
    () async {
      final library = DynamicLibrary.open(path);
      final bindings = GstpLibrary.openPath(path).bindings;
      expect(bindings.gstp_init(), 0);
      final lookup = library
          .lookupFunction<
            Pointer<Void> Function(Int64),
            Pointer<Void> Function(int)
          >('gstp_player_lookup');
      final emit = library
          .lookupFunction<
            Void Function(Pointer<Void>, Int32, Pointer<Char>),
            void Function(Pointer<Void>, int, Pointer<Char>)
          >('gstp_player_emit');
      final id = bindings.gstp_player_create();
      final pump = GstpEventPump(id)..start();
      final received = <PlayerEvent>[];
      final subscription = pump.stream.listen(received.add);
      for (var i = 0; i < 100; i++) {
        final message = '事件 $i'.toNativeUtf8();
        try {
          emit(lookup(id), PlayerEventKind.error.index, message.cast());
        } finally {
          malloc.free(message);
        }
      }
      await pump.dispose().timeout(const Duration(seconds: 5));
      expect(received.map((event) => event.message).toList(), [
        for (var i = 0; i < 100; i++) '事件 $i',
      ]);
      await subscription.cancel();
      bindings.gstp_player_dispose(id);
    },
    skip: !File(path).existsSync() ? 'Build host native library first' : false,
  );
}
