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
