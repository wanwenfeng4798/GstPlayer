import 'package:flutter/foundation.dart';

/// 是否为 iOS / Android 移动端平台 / Whether the current platform is mobile (iOS or Android).
bool get isMobilePlatform => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.android => true,
  _ => false,
};

/// 桌面端（macOS / Windows / Linux）/ Desktop targets sharing the appsink texture path.
bool get isDesktopPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

/// adaptive 控件风格是否使用 Cupertino（与 iOS/macOS 一致，桌面三端对齐）/
/// Whether adaptive controls use Cupertino styling (aligned across Apple + desktop).
bool get useCupertinoAdaptiveControls => switch (defaultTargetPlatform) {
  TargetPlatform.iOS ||
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};
