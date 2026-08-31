## 0.0.4

### Playback & native

- Network MOV / QuickTime duration via qtdemux SEGMENT sticky probe (replaces
  unreliable GstDiscoverer / factory duration queries).
- Custom HTTP request headers and device User-Agent on all platforms.
- Windows / Linux: `linux_env` GStreamer registry cache, FFI symbol retain
  (`gstp_ffi_keep`), aligned with macOS plugin behavior.
- Removed discoverer path, deep position MAX query, and init-timing debug logs.
- playbin3 `playsink` duration/position queries; position clamping for startup
  anomalies on network MOV.

### UI

- Screenshot restored in the settings popup on all platforms (`onScreenshot`).
- Danmaku Ticker interpolation; fixed-width time labels; progress bar jitter
  fixes (no transport-row FittedBox scale; skip tween on large position jumps).

### Docs

- README / CHANGELOG for 0.0.4; `VideoSource.network` HTTP header examples.

## 0.0.3

### UI (Flutter 3.44 / `material_ui`)

- Dart widgets import `package:material_ui/material_ui.dart` instead of
  `package:flutter/material.dart`.
- Removed `chat_context_menu`; speed and top-bar menus use a first-party Overlay.
- Example no longer depends on `cupertino_icons`.

### Bottom chrome & settings

- Side lock/unlock on the same row as the center play/pause (far right).
  Locking hides the bottom chrome (and top/center controls) and blocks
  gestures and keyboard shortcuts; tap only shows/hides the unlock button.
- Two-row Bilibili chrome: transport (play, position, progress, remaining time,
  speed, settings, volume, fullscreen) plus danmaku / send / CC.
- Two-level settings popup: mirror, single-episode loop, autoplay, play-next,
  16:9 / 4:3, hide black bars, lights-off, audio tracks.
- Chrome copy via `GstVideoView.language` (`GstPlayerLanguage.zh` / `.en`).
- Screenshot is no longer on the chrome (`showCaptureButton` kept for API
  compatibility; hosts can still use `onScreenshot` / `captureCurrentFrame`).

### `GstVideoView`

- New: `language`, `onPlayNext`, `onLightsOffChanged`.
- EOS with looping off and play-next enabled calls `onPlayNext`.
- Mirror, forced aspect, hide-black-bars, and lights-off overlay follow chrome
  settings.

### Darwin / Swift Package Manager

- Example iOS and macOS are SPM-only (no CocoaPods `Podfile`).
- Plugin `pubspec.yaml` sets `enable-swift-package-manager: true` so `pub get`
  does not recreate a Podfile when the global Flutter config has SPM disabled.
- SPM macOS hosts embed `GStreamer.framework` with an Xcode Run Script
  (`macos/scripts/embed_gstreamer_framework.sh`). CocoaPods hosts can still use
  `macos/gstreamer_podfile_helper.rb`.

## 0.0.2

### Playback stability (Android)

- Android video sink is **display-only**:
  `glupload → glcolorconvert → glvideoflip → queue → glimagesink`.
- Removed the main-pipeline capture tee
  (`tee → gldownload → videoconvert → capsfilter → appsink`). That branch
  competed with MediaCodec / External-OES under rapid play/pause and caused
  `_amc_gl_wait`, frozen video, and flush failures.
- `gst_element_set_state` for play/pause/stop no longer blocks up to 5s on
  `get_state`; UI converges via bus `STATE_CHANGED`.
- `BUFFERING` forced PAUSED/PLAYING applies only to URI/network streams
  (`is_uri`); local/asset transient buffering no longer interrupts decode.
- `appsink` sample callback returns `GST_FLOW_OK` on drop instead of
  `GST_FLOW_ERROR`, so a bad capture frame cannot tear down the pipeline.
- Dart transport: play/pause intent coalesce with **200ms debounce**, so rapid
  toggles send only the latest intent to native (tests updated accordingly).

### Screenshot / thumbnail

- Android `captureFramePng()` uses headless `GstPlayer.captureThumbnail`
  (no live appsink on the display sink).
- Native `gstp_thumbnail_capture` follows GStreamer official
  `snapshot.c` flow:
  `uridecodebin → videoconvert → videoscale → appsink`, then `PAUSED` →
  seek (`KEY_UNIT | FLUSH`) → `pull-preroll`.
- Android thumbnail extras (still GStreamer decodebin APIs):
  - `autoplug-continue`: skip audio/text so `amcaudiodec` is never created
    (avoids `Downstream returned not-linked` / `code should not be reached`
    SIGABRT).
  - `force-sw-decoders=true`: prefer libav so appsink gets system-memory
    frames (AMC video is GL-only: “Codec only supports GL output but
    downstream does not”).
- iOS / desktop still prefer `captureCurrentFrame()` (appsink), with
  thumbnail fallback on failure.
- Screenshot keeps using GStreamer only (no Flutter `PixelCopy` path).

### Controls & scrub preview

- Bilibili-style bottom chrome: play, danmaku input, danmaku/subtitle toggles,
  screenshot, fullscreen; overlay mode uses a compact row (overflow fixed).
- Scrub preview is **external** (GSY-style WebVTT + sprite / frame list),
  shown only while dragging — no live `captureThumbnail` on the scrub path.
- `ScrubPreviewTrack` supports `assets/` WebVTT and sprite paths.
- Example ships `assets/sample_preview.vtt` + `assets/preview/sprite.jpg`.
- Removed example dedicated thumbnail/cover extraction page
  (`thumbnail_page.dart`) and in-playback cover-grab UX from the sample app.
- Thumbnail work runs on `FfiThumbnailWorker` (dedicated isolate) so scrub /
  capture does not block play/pause/seek on the transport worker.

### API / example

- `GstVideoView` / controls expose overlay callbacks and keep
  `showCaptureButton: true`.
- Example demonstrates external scrub preview, bottom-bar danmaku, and
  screenshot dialog via `captureFramePng()`.

### Tests

- Playback session: rapid toggle coalesce / late pause-event races.
- Scrub preview controller and progress-bar-with-preview widgets.
- FFI thumbnail worker smoke tests.

## 0.0.1

### Features

- Cross-platform Flutter video player driven by a native C GStreamer core and
  Dart FFI (`GstPlayer` / `GstPlayerController` / `GstVideoView`).
- Playback: open (network / file / asset), play / pause / stop / seek, volume,
  mute, speed, looping; reactive state, position, duration, resolution,
  buffering, EOS, and error reporting.
- Platform rendering:
  - Android: `glupload` → `glcolorconvert` → `glvideoflip` → `tee` →
    `glimagesink` via `SurfaceProducer` / VideoOverlay; capture tee via
    `gldownload` → `appsink`.
  - iOS / macOS: `appsink` (BGRA) → `FlutterTexture` / IOSurface.
  - Windows / Linux: `appsink` (BGRA) → pixel-buffer textures.
- HTTPS / HTTP sources use patched `reqwesthttpsrc` (current_thread Tokio on
  Android) instead of `souphttpsrc`.
- `GstPlayer.initialize()` is kickoff-only; `ensureReady()` (and controller
  create / thumbnail capture) await full runtime readiness so the UI isolate is
  not blocked on `gst_init`.
- `GstPlayer.captureThumbnail` and `GstPlayerController.captureCurrentFrame`
  for one-shot / current-frame PNG capture.
- Built-in Material / Cupertino controls, immersive gestures, aspect ratio and
  rotation helpers.

### Scripts

- **Android umbrella**: default GStreamer SDK **1.28.5**; default
  `gst-plugins-rs` **0.15.3** when rebuilding `libgstreqwest.a`.
- **`build_reqwest_plugin_android.sh`**: after installing the cargo-built
  `libgstreqwest.a`, strip `libgstrsworkspace.la` from `libgstreqwest.la`.
  The Android SDK ships `libgstrsworkspace.a` without a matching `.la`;
  ndk-build’s libtool path otherwise passes a bare `gstrsworkspace` to
  `clang++` and the umbrella link fails. Cargo’s staticlib already embeds the
  Rust workspace crates, so the extra `.la` dependency is unnecessary.
- Android / macOS GStreamer helper scripts share cache roots under
  `*/Caches/gstplayer/gstreamer/...` (override with
  `GSTREAMER_ROOT_ANDROID` / `GSTPLAYER_GSTREAMER_ROOT` as before).

### Bug fixes

- Example Android: align `MainActivity` package with
  `com.example.gstplayer_example` and apply the Kotlin Android Gradle plugin so
  the launcher Activity is present in the APK.
- Android ndk-build of `libgstreamer_android.so` no longer fails with
  `clang++: no such file or directory: 'gstrsworkspace'` when linking the
  patched reqwest plugin.
