#!/usr/bin/env bash
# Build static libgstplayer.a for CocoaPods (macOS/iOS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${PODS_CONFIGURATION_BUILD_DIR:-${ROOT}/build/pod}/gstplayer"
mkdir -p "${OUT_DIR}"

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

SRCS=(
  "${ROOT}/src/runtime.c"
  "${ROOT}/src/bus.c"
  "${ROOT}/src/frame.c"
  "${ROOT}/src/pipeline.c"
  "${ROOT}/src/thumbnail.c"
  "${ROOT}/src/http_source.c"
  "${ROOT}/src/http_user_agent.c"
  "${ROOT}/src/gstp_player.c"
  "${ROOT}/src/gstp_ffi_keep.c"
)

if [[ "$(uname -s)" == "Darwin" ]]; then
  SRCS+=("${ROOT}/src/apple_env.c")
fi

if [[ "${PLATFORM_NAME:-macosx}" == "iphoneos" || "${PLATFORM_NAME:-}" == "iphonesimulator" || "${GSTP_IOS:-}" == "1" ]]; then
  SRCS+=("${ROOT}/src/ios_plugins.c")
  SRCS+=("${ROOT}/src/ios_tls.c")
fi

OBJDIR="${OUT_DIR}/obj"
mkdir -p "${OBJDIR}"

CFLAGS=(
  -std=c11
  -fPIC
  -O2
  -DGSTP_BUILDING
  -I"${ROOT}/include"
  -I"${ROOT}/src"
  -Wall
  -Wno-unused-parameter
)

# Prefer GStreamer.framework headers from cache / env.
GST_VER="${GST_VER:-1.28.8}"
GST_CACHE="${HOME}/Library/Caches/gstplayer/gstreamer/${GST_VER}"
if [[ -n "${GSTREAMER_FRAMEWORK_ROOT:-}" ]]; then
  GST_CACHE="${GSTREAMER_FRAMEWORK_ROOT}"
fi

if [[ "${PLATFORM_NAME:-macosx}" == "iphoneos" || "${PLATFORM_NAME:-}" == "iphonesimulator" || "${GSTP_IOS:-}" == "1" ]]; then
  # iOS: headers from GStreamer.framework; linking done in podspec.
  if [[ -d "${GST_CACHE}/GStreamer.framework/Headers" ]]; then
    CFLAGS+=(-I"${GST_CACHE}/GStreamer.framework/Headers")
  fi
  CFLAGS+=(-DTARGET_OS_IPHONE=1)
elif command -v pkg-config >/dev/null 2>&1 && pkg-config --exists gstreamer-1.0; then
  # shellcheck disable=SC2207
  CFLAGS+=($(pkg-config --cflags gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0))
elif [[ -d "${GST_CACHE}/GStreamer.framework/Headers" ]]; then
  CFLAGS+=(-I"${GST_CACHE}/GStreamer.framework/Headers")
else
  echo "GStreamer headers not found" >&2
  exit 1
fi

# Build each requested architecture against the actual Xcode target SDK.
SDK_NAME="${PLATFORM_NAME:-macosx}"
SDK_PATH="${SDKROOT:-$(xcrun --sdk "${SDK_NAME}" --show-sdk-path)}"
DEPLOYMENT_FLAGS=()
case "${SDK_NAME}" in
  iphoneos) DEPLOYMENT_FLAGS+=("-miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET:-13.0}") ;;
  iphonesimulator) DEPLOYMENT_FLAGS+=("-mios-simulator-version-min=${IPHONEOS_DEPLOYMENT_TARGET:-13.0}") ;;
  macosx) DEPLOYMENT_FLAGS+=("-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET:-10.13}") ;;
  *) echo "Unsupported Apple SDK: ${SDK_NAME}" >&2; exit 1 ;;
esac

ARCHS_LIST="${ARCHS:-$(uname -m)}"
LIBS=()
for arch in ${ARCHS_LIST}; do
  ARCH_OBJDIR="${OBJDIR}/${arch}"
  mkdir -p "${ARCH_OBJDIR}"
  OBJS=()
  for src in "${SRCS[@]}"; do
    base="$(basename "${src}" .c)"
    obj="${ARCH_OBJDIR}/${base}.o"
    # OTHER_CFLAGS is supplied by Xcode as whitespace-separated compiler flags.
    # shellcheck disable=SC2086
    xcrun --sdk "${SDK_NAME}" clang -c "${CFLAGS[@]}" \
      -arch "${arch}" -isysroot "${SDK_PATH}" "${DEPLOYMENT_FLAGS[@]}" \
      ${OTHER_CFLAGS:-} -o "${obj}" "${src}"
    OBJS+=("${obj}")
  done
  ARCH_LIB="${OUT_DIR}/libgstplayer-${arch}.a"
  xcrun libtool -static -o "${ARCH_LIB}" "${OBJS[@]}"
  LIBS+=("${ARCH_LIB}")
done

LIB="${OUT_DIR}/libgstplayer.a"
if [[ "${#LIBS[@]}" -eq 1 ]]; then
  cp "${LIBS[0]}" "${LIB}"
else
  xcrun lipo -create "${LIBS[@]}" -output "${LIB}"
fi
echo "[gstplayer] built ${LIB} (${ARCHS_LIST}, ${SDK_NAME})"
