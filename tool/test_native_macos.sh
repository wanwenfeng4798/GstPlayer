#!/usr/bin/env bash
# Compile and exercise native regressions against the versioned macOS SDK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/macos/scripts/gstreamer_paths.sh"
SDK="${GSTREAMER_FRAMEWORK_SRC}"
OUT="${ROOT}/native/build/host"
PODS_CONFIGURATION_BUILD_DIR="${OUT}" PLATFORM_NAME=macosx \
  bash "${ROOT}/native/scripts/build_pod.sh"
xcrun clang -dynamiclib -Wl,-force_load,"${OUT}/gstplayer/libgstplayer.a" \
  -F"$(dirname "${SDK}")" -framework GStreamer -framework Foundation \
  -Wl,-rpath,"$(dirname "${SDK}")" -o "${OUT}/libgstplayer.dylib"
xcrun clang -std=c11 -I"${ROOT}/native/include" -I"${ROOT}/native/src" \
  -I"${SDK}/Headers" "${ROOT}/native/test/regression.c" \
  -L"${OUT}" -lgstplayer -F"$(dirname "${SDK}")" -framework GStreamer \
  -Wl,-rpath,"${OUT}" -Wl,-rpath,"$(dirname "${SDK}")" \
  -o "${OUT}/native_regression"
GSTP_TEST_VIDEO="${ROOT}/example/assets/sample.mp4" \
GST_PLUGIN_SYSTEM_PATH_1_0="${SDK}/Versions/1.0/lib/gstreamer-1.0" \
  "${OUT}/native_regression"
