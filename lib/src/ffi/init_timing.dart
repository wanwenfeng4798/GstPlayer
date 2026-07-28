import 'package:flutter/foundation.dart';

/// Debug-only init phase timing (`[gstp-init-timing] phase=Nms`).
void gstpInitTiming(String phase, Stopwatch sw) {
  if (kDebugMode) {
    debugPrint('[gstp-init-timing] $phase=${sw.elapsedMilliseconds}ms');
  }
}

/// Times [action] and logs [phase] in debug mode.
T gstpTimed<T>(String phase, T Function() action) {
  final sw = Stopwatch()..start();
  final result = action();
  gstpInitTiming(phase, sw);
  return result;
}

/// Times async [action] and logs [phase] in debug mode.
Future<T> gstpTimedAsync<T>(String phase, Future<T> Function() action) async {
  final sw = Stopwatch()..start();
  final result = await action();
  gstpInitTiming(phase, sw);
  return result;
}
