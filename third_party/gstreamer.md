# GStreamer source / patch workflow for gstplayer

## Roles

| Artifact | Role |
|----------|------|
| Official Android/iOS/macOS GStreamer SDK binaries | **Default link target** for builds |
| [Matkurban/gstreamer](https://github.com/Matkurban/gstreamer) | **Patch / customization source** when upstream C must change |
| This repo `native/` | Player business logic (pipeline, bus, texture ABI) |

Do **not** put the Flutter plugin inside the GStreamer source tree.

## Clone the fork

```bash
export GSTP_GSTREAMER_SRC="${GSTP_GSTREAMER_SRC:-$HOME/GstPlayerPackages/gstreamer}"
git clone https://github.com/Matkurban/gstreamer.git "$GSTP_GSTREAMER_SRC"
```

Suggested sibling layout:

```
GstPlayerPackages/
  gstplayer/   # this plugin
  gstreamer/              # Matkurban fork (GSTP_GSTREAMER_SRC)
```

## When to patch

Use the fork only when you need to change GStreamer or plugin C sources, for example:

- HTTP/TLS source behavior on Android
- androidmedia / MediaCodec quirks
- Bug fixes that must ship before an upstream release

Workflow:

1. Branch in `$GSTP_GSTREAMER_SRC`
2. Fix and verify against a minimal gst-launch / C repro
3. `git format-patch` or `git diff` → drop into `android/gstreamer_build/patches/` (or iOS custom build notes)
4. Record the fork commit SHA and rationale in this file / CHANGELOG

## Default builds (no fork compile)

- **macOS:** `macos/scripts/ensure_gstreamer_macos.sh` caches `GStreamer.framework`
- **Android:** `android/scripts/` downloads the official Android SDK and builds `libgstreamer_android.so`
- **Desktop Linux:** system / Homebrew packages via pkg-config
- **Windows:** MSVC GStreamer install (`GSTREAMER_1_0_ROOT_MSVC_X86_64`)

Player code always lives in `native/` and links those binaries.
