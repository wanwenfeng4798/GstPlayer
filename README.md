<p align="center">
  <img src="docs/gstplayer.svg" alt="gstplayer" width="520" />
</p>

# gstplayer

English | [简体中文](README.zh-CN.md)

A cross-platform Flutter **video player** plugin that decodes local and network
video with **GStreamer** (native **C** core + **Dart FFI**) and renders into
Flutter external **`Texture`** widgets via a custom native bridge (GStreamer
`appsink` on Apple/desktop; `glimagesink` + `SurfaceProducer` on Android).

- Repository: <https://github.com/wanwenfeng4798/GstPlayer>

Supported platforms: **Android, iOS, macOS, Windows, Linux**.

> **Android / iOS / macOS:** GStreamer SDK is downloaded automatically on the
> first build. **Android** also needs a local [Rust](#prerequisites) toolchain
> (for HTTPS / reqwest). **Windows / Linux:** install GStreamer once on the
> machine (see below).

> Scope: video playback — open / play / pause / stop / seek / volume /
> mute / speed / looping, plus state / position / duration / resolution /
> buffering / EOS / error reporting, scrub preview, poster / last-frame,
> external subtitles (SRT/VTT overlay), danmaku overlay, and screenshots.
> It does **not** do recording, streaming (as a server), or system
> picture-in-picture.

## Table of contents

- [Features](#features)
- [Platform support](#platform-support)
- [When to use kinetic_player instead](#when-to-use-kinetic_player-instead)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Usage notes](#usage-notes)
- [Network permissions](#network-permissions)
- [Windows & Linux host SDK](#windows--linux-host-sdk)
- [API reference](#api-reference)
- [Architecture](#architecture)
- [NativeCore sync & verify](#nativecore-sync--verify)
- [Troubleshooting](#troubleshooting)
- [Repository](#repository)
- [License](#license)

## Features

- Local files, Flutter assets, and network URLs (`http(s)://`, `rtsp://`, ...).
- Play / pause / stop / seek / looping.
- Volume (popup vertical slider with live **0–100** readout), mute, and playback speed.
- Bilibili-inspired control chrome: pink progress track (`#FB7299`), progress row above the tool row, auto-hiding bar.
- Mobile surface gestures (**inline and fullscreen**): horizontal seek, left brightness / right volume (HUD shows percent).
- Progress-bar scrub thumbnail preview (debounced `captureThumbnail`).
- Poster image and keep-last-frame after EOS.
- External subtitle overlay (SRT/WebVTT via `SubtitleParser`) plus embedded subtitle track selection API/UI.
- Danmaku (bullet comment) overlay driven by app-supplied `DanmakuItem` cues.
- Frame capture (`captureCurrentFrame`) and one-shot covers (`captureThumbnail`).
- Reactive state via [`ChangeNotifier`](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
  plain getters: state, position, duration, video size, aspect ratio, buffering %,
  volume, speed, looping, muted, and errors. Rebuild with `ListenableBuilder` /
  `addListener`.
- A drop-in `GstVideoView` widget with a built-in, auto-hiding, themeable
  control bar (Material / Cupertino / adaptive; default theme accent matches Bilibili pink).
- GPU-friendly video via Flutter `Texture` (Android GL into `SurfaceProducer`; Apple/desktop pixel-buffer textures fed from GStreamer `appsink`).

## Platform support

| Platform | Min version | Architectures | GStreamer |
| --- | --- | --- | --- |
| Android | API 24 (7.0) | `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64` | **Auto** on first build |
| iOS | 13.0 | Physical `arm64` device (**no Simulator**) | **Auto** on first SPM resolve / build |
| macOS | 10.13 | x86_64 / arm64 | **Auto** on first `pod install` / SPM resolve |
| Windows | 10+ | x86_64 | Install once on the machine ([below](#windows--linux-host-sdk)) |
| Linux | — | x86_64 | Install once on the machine ([below](#windows--linux-host-sdk)) |

> Apple Silicon iOS **Simulator** is not supported (no arm64 simulator slice in the
> official iOS SDK).

## When to use kinetic_player instead

If your app targets **Android / iOS / macOS / Web** and you want a **smaller**
binary that leans on each platform’s native player, prefer
[**kinetic_player**](https://pub.dev/packages/kinetic_player)
([GitHub](https://github.com/wanwenfeng4798/kinetic_player)).

Use **gstplayer** when you need a **GStreamer** pipeline (especially
**Windows / Linux**, or codecs / protocols that benefit from GStreamer).

## Prerequisites

Install these **once** on the machine that builds the app. The GStreamer SDK
itself is still auto-downloaded for Android / iOS / macOS on first build.

### All platforms

- [Flutter](https://docs.flutter.dev/get-started/install) matching this plugin
  (`sdk: ^3.12.2`, `flutter: ">=3.44.0"` in `pubspec.yaml`)
- Network access on the **first** Android / iOS / macOS build (GStreamer cache)

### Android

HTTPS (`reqwesthttpsrc`) is built from Rust during the umbrella native build:

```bash
# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable

# Android targets used by this plugin
rustup target add \
  aarch64-linux-android \
  armv7-linux-androideabi \
  i686-linux-android \
  x86_64-linux-android
```

Also required:

- Android SDK + NDK (normal Flutter Android setup; NDK is used by Gradle)
- `pkg-config` on `PATH` (Cargo reads GStreamer `.pc` files from the SDK cache)

  - macOS: `brew install pkgconf`
  - Linux: `sudo apt install pkg-config`
  - Windows: e.g. `choco install pkgconfiglite`

### iOS

- macOS with [Xcode](https://developer.apple.com/xcode/) (Command Line Tools)
- A **physical** iPhone / iPad (Simulator is not supported)
- First build downloads the GStreamer iOS SDK automatically (~500MB)

### macOS

- [Xcode](https://developer.apple.com/xcode/)
- First build downloads the official universal `GStreamer.framework` automatically
- If Flutter uses SPM for plugins: one-time Podfile embed helper (see
  [Installation](#installation))

### Windows / Linux

Host GStreamer + `pkg-config` — see [Windows & Linux host SDK](#windows--linux-host-sdk).

## Installation

### 1. Add the dependency

```yaml
dependencies:
  gstplayer: ^0.0.1
```

```bash
flutter pub get
```

### 2. Run your app

```bash
flutter run
```

That is enough for **Android / iOS / macOS** (after [Prerequisites](#prerequisites)):

- The first build downloads the official GStreamer SDK into
  `~/Library/Caches/gstplayer/...` (needs network once; no sudo).
- Later builds reuse the cache.
- No manual GStreamer **installer** for those platforms; Android still needs
  Rust / `pkg-config` as listed above.

**iOS:** use a physical device (`flutter run -d <device>`). Simulator is not supported.

**macOS (one-time, only if Flutter uses SPM for plugins):** add this to
`macos/Podfile` `post_install` so the slim runtime is copied into the `.app`:

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

Then `cd macos && pod install` once. CocoaPods-only hosts already get the framework
via `vendored_frameworks` and can skip this.

**Windows / Linux:** install the host GStreamer SDK once — see
[Windows & Linux host SDK](#windows--linux-host-sdk).

## Quick start

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gstplayer/gstplayer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kickoff only (under 50ms); gst_init continues in the background.
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

Other sources:

```dart
await controller.open(const VideoSource.file('/path/to/video.mp4'));
await controller.open(const VideoSource.asset('assets/sample.mp4'));
```

## Usage notes

1. Call `GstPlayer.initialize()` once early (`unawaited` before `runApp` is fine).
2. One `GstPlayerController` per surface; always `dispose()` it.
3. Read playback state inside `ListenableBuilder` / `addListener`.
4. First Android / iOS / macOS build needs network for the SDK cache.

## Network permissions

Local files and Flutter assets need no extra setup.

| Platform | For `http(s)://` / `rtsp://` |
| --- | --- |
| **Android** | Ensure `INTERNET` in `AndroidManifest.xml` (Flutter templates usually already have it). Optional: `android:usesCleartextTraffic="true"` for plain `http://`. |
| **iOS** | Nothing. GStreamer does not use ATS / `NSURLSession`. Device only. |
| **macOS** | With App Sandbox, keep `com.apple.security.network.client` in Runner entitlements (Flutter templates usually already have it). |
| **Windows / Linux** | No app permission; host GStreamer must be installed ([below](#windows--linux-host-sdk)). |

> HTTPS note: for maximum compatibility the pipeline sets `ssl-strict = false` on
> the HTTP source (skips server cert verification). Open an issue if you need
> strict TLS made configurable.

## Windows & Linux host SDK

Only these platforms need a **one-time machine install**. Android / iOS / macOS
do **not**.

### Windows

1. Install `gstreamer-1.0-msvc-x86_64-<version>.exe` from
   <https://gstreamer.freedesktop.org/download/> with **“Runtime and development
   headers”**.
2. Put `pkg-config` on `PATH` (e.g. `choco install pkgconfiglite`).
3. GUI install sets `GSTREAMER_1_0_ROOT_MSVC_X86_64`; set it yourself for silent installs.

### Linux

```bash
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav \
  libgtk-3-dev
```

## API reference

### `GstPlayer.initialize()`

Kickoff-only: opens the native library and starts background `gst_init` /
FFI worker spawn. Target under 50ms; does **not** wait for runtime readiness.
Call early (e.g. before `runApp`). Idempotent; concurrent calls share one
`Future`. After return, `isInitialized` may still be `false`.

### `GstPlayer.ensureReady()`

Awaits full runtime readiness (`gst_init` success + worker started). Starts
`initialize()` if needed. Controller `create` and `captureThumbnail` call this
automatically.

### `GstPlayer.captureThumbnail(VideoSource, {Duration? at, int maxWidth})`

One-shot cover extraction via a headless GStreamer pipeline in C
(`gstp_thumbnail_capture`). Returns PNG `Uint8List`. Does not require an open
controller. When `at` is null, native picks ~5% of duration (or 1s). Also used
internally for progress-bar scrub preview.

### `GstPlayerController`

| Method | Description |
| --- | --- |
| `initialize()` | Creates the native player and subscribes to events. |
| `open(VideoSource, {bool autoPlay})` | Loads a source; optionally starts playback. |
| `play()` / `pause()` / `stop()` | Playback transport. |
| `togglePlayPause()` | Play if paused, pause if playing. |
| `seek(Duration)` | Seek to a position. |
| `setVolume(double)` | Volume in `0.0..1.0`. |
| `setMuted(bool)` / `toggleMuted()` | Mute control. |
| `setSpeed(double)` | Playback speed multiplier. |
| `setLooping(bool)` | Loop at end-of-stream. |
| `tracks` / `refreshTracks()` / `selectTrack(MediaTrack, {enable})` | Audio / video / subtitle tracks. |
| `captureCurrentFrame()` | Latest decoded frame as PNG (`gstp_player_capture_frame`). |
| `queryPosition()` / `queryDuration()` | Query the pipeline directly. |
| `dispose()` | Tear down the player and release all resources. |

Reactive state (plain getters on `ChangeNotifier`; read inside `ListenableBuilder`
or after `addListener`):
`state`, `position`, `duration`, `videoSize`, `aspectRatio`, `bufferingPercent`,
`volume`, `speed`, `looping`, `muted`, `isPlaying`, `isCompleted`, `error`,
`playerId`, `initialized`, `mediaSource`, `tracks`, `supportsTracks`.

`PlayerState`: `idle`, `ready`, `buffering`, `playing`, `paused`, `stopped`,
`completed`, `error`.

### `VideoSource`

- `VideoSource.network(String url)`
- `VideoSource.file(String path)` (accepts a plain path or a `file://` URI)
- `VideoSource.asset(String assetKey)`

### `GstVideoView`

Embeds a Flutter `Texture` for the controller's video and, by default, an
auto-hiding Bilibili-style control bar (progress row + tool row).

| Parameter | Default | Description |
| --- | --- | --- |
| `controller` | required | The `GstPlayerController` to render. |
| `aspectRatioMode` | `AspectRatioMode.fit` | Layout scaling (`fit` / `fill` / `stretch`). Also via `controller.setAspectRatioMode`. |
| `backgroundColor` | black | Letterbox / background color. |
| `showControls` | `true` | Overlay the built-in control bar. |
| `controlsStyle` | `adaptive` | `adaptive` / `material` / `cupertino`. |
| `fullscreen` | `VideoControlsFullscreenConfig()` | Immersive / fullscreen chrome options. |
| `poster` | `null` | `ImageProvider` shown before frames / while idle. |
| `keepLastFrame` | `true` | Capture and keep the last frame after EOS. |
| `danmaku` | `[]` | App-supplied `DanmakuItem` list. |
| `danmakuEnabled` | `false` | Toggle danmaku overlay. |
| `subtitles` | `[]` | External `SubtitleCue` list (e.g. from `SubtitleParser`). |
| `subtitlesEnabled` | `true` | Toggle external subtitle overlay. |

Example with poster, subtitles, and danmaku:

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

### Controls, gestures, and theming

**Bottom chrome (Bilibili-inspired):** pink progress track on its own row; tool row
with play, time, volume popup, capture, loop, speed / captions, fullscreen.

**Volume popup:** tap the speaker icon for a vertical pink slider; the live
**0–100** value is shown above the track. Long-press toggles mute.

**Mobile gestures** (Android / iOS, **both inline and fullscreen**):

| Zone | Gesture | Effect |
| --- | --- | --- |
| Left ~40% | Vertical drag | Screen brightness + HUD `%` |
| Right ~40% | Vertical drag | Pipeline volume + HUD `%` |
| Horizontal | Drag | Seek preview / seek |

**Scrub preview:** while dragging or hovering the progress bar, a thumbnail
bubble appears (via `GstPlayer.captureThumbnail` on the open `mediaSource`).
Live sources may show time only.

Register a `VideoControlsTheme` in `ThemeData.extensions`, or use presets
`material()` / `cupertino()` / **`bilibili()`** (pink `#FB7299`):

```dart
MaterialApp(
  theme: ThemeData(
    extensions: [VideoControlsTheme.bilibili()],
  ),
);
```

### Overlays helpers

- `SubtitleParser.parse(String)` / `SubtitleParser.loadAsset(String)` → `List<SubtitleCue>`
- `DanmakuItem({at, text, color, duration})` — supply to `GstVideoView.danmaku`

## Architecture

```
Dart:  GstPlayerController ──FFI──► FfiPlayerCommandPort (gstp_player_*)
       GstVideoView (Texture) ◄──native texture── GStreamer sink
C:     native/ playbin3 ─► appsink (Apple/desktop) or glimagesink (Android)
                     │ bus ─► GstpEventCallback ─► Dart Stream
```

- Decoding: `playbin3` with platform video sink (`appsink` or `glimagesink`).
- Rendering: Flutter `Texture` + native `TextureRegistry`; Android uses
  `SurfaceProducer` + VideoOverlay; Apple/desktop pull BGRA frames via C ABI
  (`gstp_texture_*`).
- Control plane: Dart FFI → narrow `gstp_player_*` API (see `native/include/gstp_player.h`).

### Regenerating FFI bindings

After changing `native/include/gstp_player.h`:

```bash
dart run ffigen --config ffigen.yaml
```

## NativeCore sync & verify

`native/` is the canonical C source tree. iOS/macOS SPM targets compile from
`ios/gstplayer/NativeCore` and `macos/gstplayer/NativeCore`, so keep them synced
before build/publish:

```bash
# after editing native/{include,src}
./tool/native_core.sh sync

# before publish / release checks
./tool/native_core.sh verify
```

## Troubleshooting

- **First build is slow / needs network (Android / iOS / macOS):** normal — the
  official GStreamer SDK is downloaded once into `~/Library/Caches/gstplayer/`.
  Offline CI: pre-seed that cache or set `GSTREAMER_ROOT_ANDROID` /
  `GSTREAMER_ROOT_IOS` / `GSTPLAYER_GSTREAMER_ROOT`.
- **Android `cargo: command not found` / missing Android targets:** install Rust
  and `rustup target add` the four Android triples — see
  [Prerequisites](#prerequisites).
- **Android / macOS `pkg-config` errors while building reqwest:** install
  `pkgconf` / `pkg-config` (e.g. `brew install pkgconf`).
- **iOS Simulator:** not supported. Use a physical device.
- **iOS `'gst/app/gstappsink.h' file not found`:** the example uses Swift Package
  Manager, which does not run the CocoaPods podspec. `Package.swift` /
  the `EnsureGStreamerIOS` build plugin download the SDK into
  `~/Library/Caches/gstplayer/gstreamer/<ver>/ios/iPhone.sdk` on resolve/build.
  First build needs network. If headers are still missing: `sh ios/scripts/ensure_gstreamer_ios.sh`,
  then `flutter clean && flutter pub get` and rebuild.
- **macOS `'gst/app/gstappsink.h' file not found`:** same SPM path as iOS — the
  `EnsureGStreamerMacOS` build plugin runs `ensure_gstreamer_macos.sh` before
  compile (first build downloads ~870MB into
  `~/Library/Caches/gstplayer/gstreamer/<ver>/`). Manual fix:
  `sh macos/scripts/ensure_gstreamer_macos.sh`, then rebuild.
- **macOS `Library not loaded: ...GStreamer.framework`:** SPM hosts must wire
  `install_gstreamer_embed_script!(installer)` in `macos/Podfile` (see
  [Installation](#installation)), then `pod install` and rebuild. Confirm
  `YourApp.app/Contents/Frameworks/GStreamer.framework` exists.
- **Release crash: `Failed to lookup symbol 'gstp_init'` (iOS/macOS):** set Runner
  **Strip Style = Non-Global Symbols** for Release/Profile. CocoaPods usually
  injects this after `pod install`; SPM hosts set it in Xcode. See
  [Flutter C interop — Stripping symbols](https://docs.flutter.dev/platform-integration/ios/c-interop).
- **Link error: `undefined symbol: _gstp_*` (path / SPM):** run
  `./tool/native_core.sh sync`, then `flutter clean` and rebuild.
- **APK too large:** narrow `abiFilters` or ship an App Bundle (each ABI carries a
  large GStreamer runtime).
- **Android minify / R8:** keep `org.freedesktop.gstreamer.**` (plugin AAR already
  ships consumer ProGuard rules).
- **Windows `pkg-config` / missing glib:** install the **development** GStreamer
  MSVC package and point `PKG_CONFIG_PATH` at `...\lib\pkgconfig`.

## Repository

- Repository: <https://github.com/wanwenfeng4798/GstPlayer>
- Issues: <https://github.com/wanwenfeng4798/GstPlayer/issues>

## License

See [LICENSE](LICENSE).
