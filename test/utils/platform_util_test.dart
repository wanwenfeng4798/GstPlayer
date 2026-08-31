import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/utils/platform_util.dart';

void main() {
  test('useCupertinoAdaptiveControls on macOS desktop target', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(useCupertinoAdaptiveControls, isTrue);
    expect(isDesktopPlatform, isTrue);
    expect(isMobilePlatform, isFalse);
  });

  test('useCupertinoAdaptiveControls on Linux desktop target', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(useCupertinoAdaptiveControls, isTrue);
    expect(isDesktopPlatform, isTrue);
  });

  test('useCupertinoAdaptiveControls on Windows desktop target', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(useCupertinoAdaptiveControls, isTrue);
    expect(isDesktopPlatform, isTrue);
  });

  test('useCupertinoAdaptiveControls false on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(useCupertinoAdaptiveControls, isFalse);
    expect(isMobilePlatform, isTrue);
  });
}
