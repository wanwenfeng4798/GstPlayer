#!/usr/bin/env bash
# Downloads and extracts the official universal GStreamer macOS SDK into the user
# cache. No sudo / installer — uses pkgutil --expand-full.
#
# Optional arg: SPM prebuild output directory (SwiftPM build plugin).
#
# Cache layout:
#   GStreamer.framework        — full SDK (runtime + devel) for build/link
#   GStreamerRuntime.framework — runtime-only snapshot for embed into .app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPM_PREBUILD_OUT="${1:-}"

# Capture user overrides before path resolution — gstreamer_paths.sh always
# exports GSTREAMER_FRAMEWORK_SRC (even when the framework is not installed yet).
USER_SET_GSTREAMER_ROOT="${GSTPLAYER_GSTREAMER_ROOT:-}"
USER_SET_FRAMEWORK_SRC=""
if [[ -n "${GSTREAMER_FRAMEWORK_SRC:-}" ]]; then
  if [[ -z "${HOME:-}" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      HOME="$(python3 -c 'import os, pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')"
    else
      HOME="$(eval echo "~$(id -un)")"
    fi
  fi
  _default_framework="${HOME}/Library/Caches/gstplayer/gstreamer/${GST_VER:-1.28.5}/GStreamer.framework"
  if [[ "${GSTREAMER_FRAMEWORK_SRC}" != "${_default_framework}" ]]; then
    USER_SET_FRAMEWORK_SRC="${GSTREAMER_FRAMEWORK_SRC}"
  fi
fi

# shellcheck source=gstreamer_paths.sh
source "${SCRIPT_DIR}/gstreamer_paths.sh"
# shellcheck source=../../tool/gstreamer_pkg_expand.sh
source "${ROOT}/tool/gstreamer_pkg_expand.sh"

BASE="https://gstreamer.freedesktop.org/data/pkg/osx/${GST_VER}"
RUNTIME_PKG="gstreamer-1.0-${GST_VER}-universal.pkg"
DEVEL_PKG="gstreamer-1.0-devel-${GST_VER}-universal.pkg"
PKG_DIR="${GSTPLAYER_GSTREAMER_CACHE}/pkgs"

USER_FRAMEWORK="${HOME}/Library/Frameworks/GStreamer.framework"
SYSTEM_FRAMEWORK="/Library/Frameworks/GStreamer.framework"

SDK_CACHE="${GSTPLAYER_GSTREAMER_CACHE}/GStreamer.framework"
RUNTIME_CACHE="${GSTPLAYER_GSTREAMER_CACHE}/GStreamerRuntime.framework"
STAMP="${GSTPLAYER_GSTREAMER_CACHE}/.install_stamp"

is_runtime_valid() {
  local root="$1"
  [[ -f "${root}/Versions/1.0/lib/libgstreamer-1.0.0.dylib" ]] \
    && [[ -d "${root}/Versions/1.0/lib/gstreamer-1.0" ]]
}

is_sdk_valid() {
  local root="$1"
  [[ -f "${root}/Versions/1.0/lib/libgstreamer-1.0.0.dylib" ]] \
    && [[ -f "${root}/Headers/gst/gst.h" ]]
}

clean_framework_root() {
  local root="$1"
  find "${root}" -maxdepth 1 -name '.*' -type f -delete 2>/dev/null || true
}

write_stamp() {
  mkdir -p "${GSTPLAYER_GSTREAMER_CACHE}"
  {
    echo "version=${GST_VER}"
    echo "sdk=${SDK_CACHE}"
    echo "runtime=${RUNTIME_CACHE}"
    echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "${STAMP}"
}

snapshot_framework() {
  local src="$1"
  local dest="$2"
  rm -rf "${dest}"
  ditto "${src}" "${dest}"
  clean_framework_root "${dest}"
}

extract_pkg_to_framework() {
  local pkg="$1"
  local framework_dest="$2"
  local work expand
  work="$(mktemp -d)"
  expand="${work}/expand"
  gst_pkg_expand_full "${pkg}" "${expand}"
  gst_pkg_merge_into_framework "${expand}" "${framework_dest}"
  rm -rf "${work}"
}

write_spm_prebuild_outputs() {
  [[ -n "${SPM_PREBUILD_OUT}" ]] || return 0
  # shellcheck source=gstreamer_paths.sh
  source "${SCRIPT_DIR}/gstreamer_paths.sh"
  local header="${GSTREAMER_FRAMEWORK_SRC}/Headers/gst/gst.h"
  local appsink="${GSTREAMER_FRAMEWORK_SRC}/Headers/gst/app/gstappsink.h"
  if [[ ! -f "${header}" || ! -f "${appsink}" ]]; then
    echo "error: GStreamer macOS headers missing after ensure:" >&2
    echo "  ${header}" >&2
    echo "  ${appsink}" >&2
    exit 1
  fi
  mkdir -p "${SPM_PREBUILD_OUT}"
  # Avoid emitting .h files into plugin output directory.
  # Xcode prints: "C header file generation not enabled" for those outputs.
  rm -f "${SPM_PREBUILD_OUT}/gst.h" "${SPM_PREBUILD_OUT}/gstappsink.h"
  echo "ok $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${SPM_PREBUILD_OUT}/ensured"
}

# Cache hit: stay quiet (SPM / pod install may call this often).
if is_sdk_valid "${SDK_CACHE}" && is_runtime_valid "${RUNTIME_CACHE}"; then
  if [[ "${GSTPLAYER_VERBOSE:-}" == "1" ]]; then
    echo "[gstplayer] GStreamer ${GST_VER} cache OK (SDK + runtime)"
  fi
  write_spm_prebuild_outputs
  exit 0
fi

# Incomplete dual-cache from older layouts: drop and rebuild.
if [[ -d "${SDK_CACHE}" || -d "${RUNTIME_CACHE}" ]]; then
  echo "[gstplayer] Incomplete GStreamer cache; rebuilding ${GSTPLAYER_GSTREAMER_CACHE}..."
  rm -rf "${SDK_CACHE}" "${RUNTIME_CACHE}" "${STAMP}"
fi

if is_sdk_valid "${USER_FRAMEWORK}"; then
  echo "[gstplayer] Snapshotting GStreamer from ~/Library/Frameworks (~1–2 min)..."
  snapshot_framework "${USER_FRAMEWORK}" "${SDK_CACHE}"
  if is_runtime_valid "${USER_FRAMEWORK}"; then
    snapshot_framework "${USER_FRAMEWORK}" "${RUNTIME_CACHE}"
  fi
  if is_sdk_valid "${SDK_CACHE}" && is_runtime_valid "${RUNTIME_CACHE}"; then
    write_stamp
    echo "[gstplayer] GStreamer ${GST_VER} ready at ${SDK_CACHE} (from ~/Library/Frameworks)"
    write_spm_prebuild_outputs
    exit 0
  fi
fi

if is_sdk_valid "${SYSTEM_FRAMEWORK}"; then
  echo "[gstplayer] Snapshotting GStreamer from /Library/Frameworks (~1–2 min)..."
  snapshot_framework "${SYSTEM_FRAMEWORK}" "${SDK_CACHE}"
  snapshot_framework "${SYSTEM_FRAMEWORK}" "${RUNTIME_CACHE}"
  if is_sdk_valid "${SDK_CACHE}" && is_runtime_valid "${RUNTIME_CACHE}"; then
    write_stamp
    echo "[gstplayer] GStreamer ${GST_VER} ready at ${SDK_CACHE} (from /Library/Frameworks)"
    write_spm_prebuild_outputs
    exit 0
  fi
fi

if [[ -n "${USER_SET_GSTREAMER_ROOT}" || -n "${USER_SET_FRAMEWORK_SRC}" ]]; then
  echo "error: custom GStreamer path is incomplete" >&2
  echo "  GSTPLAYER_GSTREAMER_ROOT=${USER_SET_GSTREAMER_ROOT:-<unset>}" >&2
  echo "  GSTREAMER_FRAMEWORK_SRC=${USER_SET_FRAMEWORK_SRC:-<unset>}" >&2
  echo "  Expected a full SDK with Headers/gst/gst.h and Versions/1.0/lib/libgstreamer-1.0.0.dylib" >&2
  echo "  Unset those vars to auto-download into ~/Library/Caches/gstplayer/gstreamer/${GST_VER}/" >&2
  exit 1
fi

echo "[gstplayer] =============================================="
echo "[gstplayer] First-time GStreamer macOS ${GST_VER} setup"
echo "[gstplayer] Download: runtime ~150MB + devel ~720MB ≈ 870MB"
echo "[gstplayer]           (often 2–5 min on a typical network)"
echo "[gstplayer] Extract:  typically 2–4 min after download"
echo "[gstplayer] Cache:    ${GSTPLAYER_GSTREAMER_CACHE}"
echo "[gstplayer] Later builds reuse this cache (no re-download)."
echo "[gstplayer] =============================================="

mkdir -p "${PKG_DIR}"
RUNTIME_FILE="${PKG_DIR}/${RUNTIME_PKG}"
DEVEL_FILE="${PKG_DIR}/${DEVEL_PKG}"

gst_pkg_download "${BASE}/${RUNTIME_PKG}" "${RUNTIME_FILE}" "~150MB"
gst_pkg_download "${BASE}/${DEVEL_PKG}" "${DEVEL_FILE}" "~720MB"

echo "[gstplayer] Extracting runtime package into cache (about 1–2 min)..."
rm -rf "${RUNTIME_CACHE}"
mkdir -p "${RUNTIME_CACHE}"
extract_pkg_to_framework "${RUNTIME_FILE}" "${RUNTIME_CACHE}"

if ! is_runtime_valid "${RUNTIME_CACHE}"; then
  echo "error: runtime GStreamer.framework incomplete at ${RUNTIME_CACHE}" >&2
  exit 1
fi
clean_framework_root "${RUNTIME_CACHE}"

echo "[gstplayer] Building full SDK cache (runtime + devel, about 1–2 min)..."
rm -rf "${SDK_CACHE}"
ditto "${RUNTIME_CACHE}" "${SDK_CACHE}"
extract_pkg_to_framework "${DEVEL_FILE}" "${SDK_CACHE}"

if ! is_sdk_valid "${SDK_CACHE}"; then
  echo "error: full SDK GStreamer.framework incomplete at ${SDK_CACHE}" >&2
  exit 1
fi
clean_framework_root "${SDK_CACHE}"

write_stamp
# shellcheck source=gstreamer_paths.sh
source "${SCRIPT_DIR}/gstreamer_paths.sh"

echo "[gstplayer] GStreamer ${GST_VER} ready (SDK: ${GSTREAMER_FRAMEWORK_SRC}, runtime: ${GSTREAMER_RUNTIME_FRAMEWORK_SRC})"
if command -v lipo >/dev/null 2>&1; then
  lipo -info "${GSTREAMER_RUNTIME_FRAMEWORK_SRC}/Versions/1.0/lib/libgstreamer-1.0.0.dylib" || true
fi
write_spm_prebuild_outputs
