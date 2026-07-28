#!/usr/bin/env bash
# Build libgstplayer for the host (macOS/Linux) without requiring a
# pre-installed CMake: uses clang + pkg-config when available.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/build/host"
mkdir -p "${OUT}"

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

SRCS=(
  "${ROOT}/src/runtime.c"
  "${ROOT}/src/bus.c"
  "${ROOT}/src/frame.c"
  "${ROOT}/src/pipeline.c"
  "${ROOT}/src/thumbnail.c"
  "${ROOT}/src/gstp_player.c"
  "${ROOT}/src/gstp_ffi_keep.c"
)

UNAME="$(uname -s)"
if [[ "${UNAME}" == "Darwin" ]]; then
  SRCS+=("${ROOT}/src/apple_env.c")
fi

CFLAGS=(
  -std=c11
  -fPIC
  -O2
  -DGSTP_BUILDING
  -I"${ROOT}/include"
  -I"${ROOT}/src"
  -Wall
  -Wextra
  -Wno-unused-parameter
)

if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0; then
  # shellcheck disable=SC2207
  CFLAGS+=($(pkg-config --cflags gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0))
  # shellcheck disable=SC2207
  LIBS=($(pkg-config --libs gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0))
else
  echo "pkg-config GStreamer not found" >&2
  exit 1
fi

if [[ "${UNAME}" == "Darwin" ]]; then
  LIBNAME="libgstplayer.dylib"
  LINK_ARGS=(-dynamiclib -install_name "@rpath/libgstplayer.dylib")
else
  LIBNAME="libgstplayer.so"
  LINK_ARGS=(-shared)
fi

echo "[gstplayer] compiling ${LIBNAME} -> ${OUT}/${LIBNAME}"
clang "${CFLAGS[@]}" "${LINK_ARGS[@]}" -o "${OUT}/${LIBNAME}" "${SRCS[@]}" "${LIBS[@]}"
echo "[gstplayer] ok: ${OUT}/${LIBNAME}"
