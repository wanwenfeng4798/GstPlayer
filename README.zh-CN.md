<p align="center">
  <img src="docs/gstplayer.svg" alt="gstplayer" width="520" />
</p>

# gstplayer

[English](README.md) | 简体中文

一个**全能、界面美观**的 Flutter **视频播放器**：内置精致控件，依托 **GStreamer**
覆盖**大多数本地与网络格式**；底层为 **原生 C 核心 + Dart FFI**，经 Flutter 外部
**`Texture`** 与自定义原生桥接渲染（Android：`glimagesink` + `SurfaceProducer`；
Apple/桌面：`appsink` BGRA 帧）。

- 仓库地址：<https://github.com/wanwenfeng4798/GstPlayer>

支持平台：**Android、iOS、macOS、Windows、Linux**。

> **Android / iOS / macOS：** 首次构建会自动下载 GStreamer SDK。**Android** 还需本机
> [Rust](#前置条件) 工具链（用于 HTTPS / reqwest）。
> **Windows / Linux：** 需在本机安装一次 GStreamer（见下文）。

> 功能范围：视频播放 —— 打开 / 播放 / 暂停 / 停止 / 跳转 / 音量 / 静音 / 倍速 /
> 循环，以及状态 / 进度 / 时长 / 分辨率 / 缓冲 / 播放结束（EOS）/ 错误上报，
> 进度条缩略图预览、封面与播完留末帧、外挂字幕（SRT/VTT 叠层）、弹幕叠层、截图。
> **不包含**录制、作为服务端推流、系统画中画。

## 目录

- [功能特性](#功能特性)
- [平台支持](#平台支持)
- [何时改用 kinetic_player](#何时改用-kinetic_player)
- [前置条件](#前置条件)
- [安装](#安装)
- [快速上手](#快速上手)
- [使用要点](#使用要点)
- [网络权限](#网络权限)
- [Windows / Linux 本机 SDK](#windows--linux-本机-sdk)
- [API 说明](#api-说明)
- [架构](#架构)
- [NativeCore 同步与校验](#nativecore-同步与校验)
- [常见问题](#常见问题)
- [仓库](#仓库)
- [许可证](#许可证)

## 功能特性

- 支持本地文件、Flutter 资源（asset）以及网络地址（`http(s)://`、`rtsp://` 等）。
- 播放 / 暂停 / 停止 / 跳转 / 循环。
- 音量（竖向弹出滑条，滑动时显示 **0–100** 数值）、静音、倍速。
- B 站风格底栏：粉色进度条（`#FB7299`）、进度行在工具行上方、自动隐藏。
- 移动端画面手势（**非全屏与全屏均可用**）：水平快进/快退，左侧亮度 / 右侧音量（HUD 显示百分比）。
- 进度条拖拽缩略图预览（防抖 `captureThumbnail`）。
- 封面图与播完保留最后一帧。
- 外挂字幕叠层（SRT/WebVTT，`SubtitleParser`）以及内嵌字幕轨选择 API/UI。
- 弹幕叠层（由 App 注入 `DanmakuItem` 时间轴数据）。
- 当前帧截图（`onScreenshot` 交给宿主保存）与一次性抽封面。
- 基于 [`ChangeNotifier`](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
  普通 getter 的响应式状态：播放状态、进度、时长、视频尺寸、宽高比、缓冲百分比、
  音量、倍速、循环、静音、错误等。用 `ListenableBuilder` / `addListener` 订阅重建。
- 开箱即用的 `GstVideoView` 组件，内置可自动隐藏、可主题化的控制条
  （Material / Cupertino / 自适应；默认强调色贴近 B 站粉）。
- 通过 Flutter `Texture` 渲染（Android GL 写入 `SurfaceProducer`；Apple/桌面由 `appsink` 供帧）。

## 平台支持

| 平台 | 最低版本 | 架构 | GStreamer |
| --- | --- | --- | --- |
| Android | API 24（7.0） | `arm64-v8a`、`armeabi-v7a`、`x86`、`x86_64` | **首次构建自动下载** |
| iOS | 13.0 | 真机 `arm64`（**不支持模拟器**） | **首次 SPM resolve / 构建自动下载** |
| macOS | 10.13 | x86_64 / arm64 | **首次 `pod install` / SPM resolve 自动下载** |
| Windows | 10+ | x86_64 | 本机安装一次（[见下](#windows--linux-本机-sdk)） |
| Linux | — | x86_64 | 本机安装一次（[见下](#windows--linux-本机-sdk)） |

> 不支持 Apple Silicon 的 iOS **模拟器**（官方 iOS SDK 无 arm64 模拟器切片）。

## 何时改用 kinetic_player

若应用主要面向 **Android / iOS / macOS / Web**，且希望体积更小、更多使用平台原生播放能力，
更推荐 [**kinetic_player**](https://pub.dev/packages/kinetic_player)
（[GitHub](https://github.com/wanwenfeng4798/kinetic_player)）。

需要 **GStreamer** 管线时再选 **gstplayer**（尤其是 **Windows / Linux**，或依赖
GStreamer 编解码 / 协议的场景）。

## 前置条件

在**编译应用的机器**上准备下列环境（装一次即可）。Android / iOS / macOS 的
GStreamer SDK 仍会在首次构建时自动下载，但 **Android 需要本机 Rust**。

### 通用

- [Flutter](https://docs.flutter.dev/get-started/install)（需满足本插件
  `pubspec.yaml`：`sdk: ^3.12.2`，`flutter: ">=3.44.0"`）
- Android / iOS / macOS **首次**构建需要联网（下载 GStreamer 缓存）

### Android

HTTPS（`reqwesthttpsrc`）会在构建伞形原生库时用 Rust 编译：

```bash
# Rust 工具链
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable

# 本插件用到的 Android target
rustup target add \
  aarch64-linux-android \
  armv7-linux-androideabi \
  i686-linux-android \
  x86_64-linux-android
```

另外还需要：

- Android SDK + NDK（按 Flutter 常规 Android 环境即可；Gradle 会调用 NDK）
- `PATH` 上有 `pkg-config`（Cargo 读取 SDK 缓存里的 GStreamer `.pc`）

  - macOS：`brew install pkgconf`
  - Linux：`sudo apt install pkg-config`
  - Windows：例如 `choco install pkgconfiglite`

### iOS

- 带 [Xcode](https://developer.apple.com/xcode/) 的 macOS（含 Command Line Tools）
- **真机** iPhone / iPad（不支持模拟器）
- 首次构建会自动下载 GStreamer iOS SDK（约 500MB）

### macOS

- [Xcode](https://developer.apple.com/xcode/)
- 首次构建会自动下载官方 universal `GStreamer.framework`
- 若 Flutter 用 SPM 集成插件：需一次性配置 Podfile embed（见 [安装](#安装)）

### Windows / Linux

本机 GStreamer + `pkg-config`，见 [Windows / Linux 本机 SDK](#windows--linux-本机-sdk)。

## 安装

### 1. 添加依赖

```yaml
dependencies:
  gstplayer: ^0.0.2
```

```bash
flutter pub get
```

### 2. 直接运行

```bash
flutter run
```

对 **Android / iOS / macOS** 而言（在满足 [前置条件](#前置条件) 后）：

- 首次构建会把官方 GStreamer SDK 下载到 `~/Library/Caches/gstplayer/...`
  （只需联网一次，无需 sudo）。
- 之后复用缓存。
- 这几个平台**无需**手动跑 GStreamer 安装器；Android 仍需上方的 Rust /
  `pkg-config`。

**iOS：** 请使用真机（`flutter run -d <device>`）。不支持模拟器。

**macOS（仅当 Flutter 用 SPM 集成插件时，一次性）：** 在 `macos/Podfile` 的
`post_install` 中加入下面片段，以便把 slim runtime 拷进 `.app`：

```ruby
require 'json'
plugins = JSON.parse(File.read(File.expand_path('../.flutter-plugins-dependencies', __dir__)))
gstp = plugins.dig('plugins', 'macos')&.find { |p| p['name'] == 'gstplayer' }
raise 'gstplayer not found; run flutter pub get first' unless gstp
require File.expand_path('macos/gstreamer_podfile_helper.rb', gstp['path'])

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_macos_build_settings(target)
  end
  install_gstreamer_embed_script!(installer)
end
```

然后执行一次 `cd macos && pod install`。纯 CocoaPods 宿主已通过
`vendored_frameworks` 嵌入，可跳过。

**Windows / Linux：** 需在本机安装一次 GStreamer，见
[Windows / Linux 本机 SDK](#windows--linux-本机-sdk)。

## 快速上手

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gstplayer/gstplayer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 仅 kickoff（目标 <50ms）；gst_init 在后台继续。
  unawaited(GstPlayer.initialize());
  runApp(const MyApp());
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final controller = GstPlayerController();

  @override
  void initState() {
    super.initState();
    controller.initialize().then((_) {
      controller.open(
        VideoSource.network('https://example.com/video.mp4'),
        autoPlay: true,
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GstVideoView(controller: controller),
    );
  }
}
```

其他数据源：

```dart
await controller.open(const VideoSource.file('/path/to/video.mp4'));
await controller.open(const VideoSource.asset('assets/sample.mp4'));
```

## 使用要点

1. 尽早调用一次 `GstPlayer.initialize()`（`runApp` 前 `unawaited` 即可）。
2. 每个画面一个 `GstPlayerController`，销毁时务必 `dispose()`。
3. 在 `ListenableBuilder` / `addListener` 内读取播放状态。
4. Android / iOS / macOS 首次构建需要网络以下载 SDK 缓存。

## 网络权限

本地文件与 Flutter asset **无需**额外配置。

| 平台 | 播放 `http(s)://` / `rtsp://` |
| --- | --- |
| **Android** | `AndroidManifest.xml` 需有 `INTERNET`（Flutter 模板一般已带）。明文 `http://` 可再加 `android:usesCleartextTraffic="true"`。 |
| **iOS** | 无需配置。不走 ATS / `NSURLSession`。仅真机。 |
| **macOS** | 开启 App Sandbox 时，Runner entitlements 保留 `com.apple.security.network.client`（Flutter 模板一般已带）。 |
| **Windows / Linux** | 无应用权限要求；需安装本机 GStreamer（[见下](#windows--linux-本机-sdk)）。 |

> HTTPS 提示：为兼容更多主机，管线对 HTTP 源设置了 `ssl-strict = false`（跳过服务端证书校验）。
> 若需要严格 TLS 可配置化，欢迎提 Issue。

## Windows / Linux 本机 SDK

**只有**这两个平台需要在开发机安装一次 GStreamer。Android / iOS / macOS **不需要**。

### Windows

1. 从 <https://gstreamer.freedesktop.org/download/> 安装
   `gstreamer-1.0-msvc-x86_64-<版本>.exe`，选择 **“Runtime and development headers”**。
2. 确保 `pkg-config` 在 `PATH` 上（例如 `choco install pkgconfiglite`）。
3. GUI 安装会设置 `GSTREAMER_1_0_ROOT_MSVC_X86_64`；静默安装时请自行设置。

### Linux

```bash
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav \
  libgtk-3-dev
```

## API 说明

### `GstPlayer.initialize()`

仅 kickoff：打开原生库并启动后台 `gst_init` / FFI worker。目标 <50ms，**不**等待
运行时就绪。尽早调用（例如 `runApp` 之前）。幂等；并发共享同一 `Future`。返回后
`isInitialized` 仍可能为 `false`。

### `GstPlayer.ensureReady()`

等待完整运行时就绪（`gst_init` 成功 + worker 已启动）。必要时会先启动
`initialize()`。控制器 `create` 与 `captureThumbnail` 会自动调用。

### `GstPlayer.captureThumbnail(VideoSource, {Duration? at, int maxWidth})`

无头 GStreamer 管线一次性抽封面（`gstp_thumbnail_capture`），返回 PNG
`Uint8List`。无需已打开的 controller。`at` 为 null 时由 native 约取时长 5%（或
1 秒）。进度条 scrub 预览也复用此 API。

### `GstPlayerController`

| 方法 | 说明 |
| --- | --- |
| `initialize()` | 创建原生播放器并订阅事件。 |
| `open(VideoSource, {bool autoPlay})` | 加载数据源；可选自动播放。 |
| `play()` / `pause()` / `stop()` | 播放传输控制。 |
| `togglePlayPause()` | 暂停时播放，播放时暂停。 |
| `seek(Duration)` | 跳转到指定位置。 |
| `setVolume(double)` | 音量，范围 `0.0..1.0`。 |
| `setMuted(bool)` / `toggleMuted()` | 静音控制。 |
| `setSpeed(double)` | 倍速。 |
| `setLooping(bool)` | 结束时循环。 |
| `tracks` / `refreshTracks()` / `selectTrack(MediaTrack, {enable})` | 音轨 / 视频轨 / 字幕轨。 |
| `captureCurrentFrame()` | 当前解码帧 PNG（`gstp_player_capture_frame`）。 |
| `queryPosition()` / `queryDuration()` | 直接向管线查询。 |
| `dispose()` | 拆除播放器并释放全部资源。 |

响应式状态（`ChangeNotifier` 普通 getter，请在 `ListenableBuilder` 中读取或
`addListener`）：
`state`、`position`、`duration`、`videoSize`、`aspectRatio`、`bufferingPercent`、
`volume`、`speed`、`looping`、`muted`、`isPlaying`、`isCompleted`、`error`、
`playerId`、`initialized`、`mediaSource`、`tracks`、`supportsTracks`。

`PlayerState`：`idle`、`ready`、`buffering`、`playing`、`paused`、`stopped`、
`completed`、`error`。

### `VideoSource`

- `VideoSource.network(String url)`
- `VideoSource.file(String path)`（接受普通路径或 `file://` URI）
- `VideoSource.asset(String assetKey)`

### `GstVideoView`

为控制器嵌入 `Texture` 视频画面，并默认叠加可自动隐藏的 B 站风格控制条
（进度行 + 工具行）。

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `controller` | 必填 | 要渲染的 `GstPlayerController`。 |
| `aspectRatioMode` | `AspectRatioMode.fit` | 布局缩放（`fit` / `fill` / `stretch`）；亦可通过 `controller.setAspectRatioMode` 设置。 |
| `backgroundColor` | 黑色 | 黑边 / 背景颜色。 |
| `showControls` | `true` | 是否叠加内置控制条。 |
| `controlsStyle` | `adaptive` | `adaptive` / `material` / `cupertino`。 |
| `fullscreen` | `VideoControlsFullscreenConfig()` | 沉浸 / 全屏顶栏等配置。 |
| `poster` | `null` | 开播前 / 空闲时封面 `ImageProvider`。 |
| `keepLastFrame` | `true` | EOS 后截取并保留最后一帧。 |
| `danmaku` | `[]` | App 注入的 `DanmakuItem` 列表。 |
| `danmakuEnabled` | `false` | 是否显示弹幕。 |
| `subtitles` | `[]` | 外挂 `SubtitleCue`（可用 `SubtitleParser` 解析）。 |
| `subtitlesEnabled` | `true` | 是否显示外挂字幕。 |
| `showCaptureButton` | `true` | 是否显示底栏截图按钮（还需提供 `onScreenshot`）。 |
| `onScreenshot` | `null` | 截图成功后回调 PNG；由宿主保存（相册/路径）。插件不落盘、不弹预览。 |

封面 / 字幕 / 弹幕示例：

```dart
GstVideoView(
  controller: controller,
  poster: MemoryImage(posterPng),
  keepLastFrame: true,
  subtitles: await SubtitleParser.loadAsset('assets/sample.srt'),
  subtitlesEnabled: true,
  danmaku: [
    DanmakuItem(at: Duration(seconds: 1), text: 'Hello'),
  ],
  danmakuEnabled: true,
)
```

### 控制条、手势与主题

**底栏（B 站风格）：** 粉色进度条单独一行；工具行含播放、时间、音量弹出、截图（`onScreenshot`）、循环、倍速/字幕、全屏。插件只交出 PNG 字节，由宿主负责保存（如相册）。

**音量弹出：** 点击喇叭图标弹出竖向粉色滑条，上方实时显示 **0–100** 数值；长按切换静音。

**移动端手势**（Android / iOS，**非全屏与全屏均有效**）：

| 区域 | 手势 | 效果 |
| --- | --- | --- |
| 左侧约 40% | 竖滑 | 屏幕亮度 + HUD 百分比 |
| 右侧约 40% | 竖滑 | 播放器音量 + HUD 百分比 |
| 水平 | 拖拽 | 进退预览 / seek |

**进度条预览：** 拖拽或悬停进度条时出现缩略图气泡（对当前 `mediaSource` 调用
`GstPlayer.captureThumbnail`）。直播源可能仅显示时间。

在 `ThemeData.extensions` 中注册 `VideoControlsTheme`，或使用预设
`material()` / `cupertino()` / **`bilibili()`**（粉 `#FB7299`）：

```dart
MaterialApp(
  theme: ThemeData(
    extensions: [VideoControlsTheme.bilibili()],
  ),
);
```

### 叠层辅助 API

- `SubtitleParser.parse(String)` / `SubtitleParser.loadAsset(String)` → `List<SubtitleCue>`
- `DanmakuItem({at, text, color, duration})` — 传给 `GstVideoView.danmaku`

## 架构

```
Dart:  GstPlayerController ──FFI──► FfiPlayerCommandPort (gstp_player_*)
       GstVideoView (Texture) ◄──native texture── GStreamer sink
C:     native/ playbin3 ─► appsink（Apple/桌面）或 glimagesink（Android）
                     │ 总线 ─► GstpEventCallback ─► Dart Stream
```

- 解码：`playbin3` + 平台 sink（`appsink` 或 `glimagesink`）。
- 渲染：Flutter `Texture`；Android 为 `SurfaceProducer` + VideoOverlay；Apple/桌面经 C ABI（`gstp_texture_*`）拉取 BGRA 帧。
- 控制面：Dart FFI → 窄 `gstp_player_*` API（见 `native/include/gstp_player.h`）。

### 重新生成 FFI 绑定

修改 `native/include/gstp_player.h` 后：

```bash
dart run ffigen --config ffigen.yaml
```

## NativeCore 同步与校验

`native/` 是 C 源码主目录。iOS/macOS 的 SPM target 实际编译
`ios/gstplayer/NativeCore` 与 `macos/gstplayer/NativeCore`，因此在构建/发布前请执行：

```bash
# 修改 native/{include,src} 后
./tool/native_core.sh sync

# 发布前 / 发版检查
./tool/native_core.sh verify
```

## 常见问题

- **首次构建很慢 / 需要联网（Android / iOS / macOS）：** 正常。官方 GStreamer SDK
  会下载到 `~/Library/Caches/gstplayer/`，之后复用。离线 CI 可预置该缓存，或设置
  `GSTREAMER_ROOT_ANDROID` / `GSTREAMER_ROOT_IOS` / `GSTPLAYER_GSTREAMER_ROOT`。
- **Android 报 `cargo: command not found` / 缺少 Android target：** 安装 Rust，并
  `rustup target add` 四个 Android triple —— 见 [前置条件](#前置条件)。
- **Android / macOS 构建 reqwest 时 `pkg-config` 报错：** 安装 `pkgconf` /
  `pkg-config`（例如 `brew install pkgconf`）。
- **iOS 模拟器：** 不支持，请用真机。
- **iOS 报 `Plug-in ended with non-zero exit code: 1`：** 通常是 SPM 构建插件
  `EnsureGStreamerIOS` 失败（首次下载 SDK，或找不到 `ios/scripts`）。在 Xcode
  Report 导航查看真实 stderr。可手动执行 `sh ios/scripts/ensure_gstreamer_ios.sh`
  （需联网，约 480MB）后重编。
- **iOS 报 `'gst/app/gstappsink.h' file not found`：** 示例工程走 Swift Package Manager，
  不会执行 CocoaPods podspec。`Package.swift` / `EnsureGStreamerIOS` 构建插件会在
  resolve/编译前把 SDK 下载到 `~/Library/Caches/gstplayer/gstreamer/<ver>/ios/iPhone.sdk`。
  首次构建需要联网。若头文件仍缺失：执行 `sh ios/scripts/ensure_gstreamer_ios.sh`，再
  `flutter clean && flutter pub get` 后重编。
- **macOS 报 `'gst/app/gstappsink.h' file not found`：** 与 iOS 相同，走 SPM 时由
  `EnsureGStreamerMacOS` 构建插件在编译前执行 `ensure_gstreamer_macos.sh`（首次约
  870MB，缓存于 `~/Library/Caches/gstplayer/gstreamer/<ver>/`）。可手动执行
  `sh macos/scripts/ensure_gstreamer_macos.sh` 后重编。
- **macOS `Library not loaded: ...GStreamer.framework`：** SPM 宿主需在 `macos/Podfile`
  中接入 `install_gstreamer_embed_script!(installer)`（见 [安装](#安装)），再
  `pod install` 并重新构建。确认 `.app/Contents/Frameworks/GStreamer.framework` 存在。
- **Release 报 `Failed to lookup symbol 'gstp_init'`（iOS/macOS）：** Runner 的
  **Strip Style** 设为 **Non-Global Symbols**。CocoaPods 一般在 `pod install` 后注入；
  SPM 请在 Xcode 中设置。参见
  [Flutter C interop — Stripping symbols](https://docs.flutter.dev/platform-integration/ios/c-interop)。
- **链接报 `undefined symbol: _gstp_*`：** 执行 `./tool/native_core.sh sync`，再
  `flutter clean` 后重建。
- **APK 体积过大：** 收窄 `abiFilters` 或使用 App Bundle（每个 ABI 都带较大的 GStreamer 运行时）。
- **Android 开启 minify / R8：** 保留 `org.freedesktop.gstreamer.**`（插件 AAR 已带
  consumer ProGuard 规则）。
- **Windows `pkg-config` / 找不到 glib：** 安装带 **development** 的 GStreamer MSVC 包，
  并将 `PKG_CONFIG_PATH` 指向 `...\lib\pkgconfig`。

## 仓库

- 仓库：<https://github.com/wanwenfeng4798/GstPlayer>
- 问题反馈：<https://github.com/wanwenfeng4798/GstPlayer/issues>

## 许可证

见 [LICENSE](LICENSE)。
