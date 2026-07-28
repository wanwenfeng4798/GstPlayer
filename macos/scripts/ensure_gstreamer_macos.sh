#!/usr/bin/env bash
# Downloads and installs the official universal GStreamer macOS SDK into the user
# cache. No sudo — uses installer -target CurrentUserHomeDirectory.
#
# Cache layout:
#   GStreamer.framework        — full SDK (runtime + devel) for build/link
#   GStreamerRuntime.framework — runtime snapshot for embed into .app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gstreamer_paths.sh
source "${SCRIPT_DIR}/gstreamer_paths.sh"

BASE="https://gstreamer.freedesktop.org/data/pkg/osx/${GST_VER}"
RUNTIME_PKG="gstreamer-1.0-${GST_VER}-universal.pkg"
DEVEL_PKG="gstreamer-1.0-devel-${GST_VER}-universal.pkg"

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

copy_runtime_snapshot() {
  local src="$1"
  echo "[gstplayer] Snapshotting runtime GStreamer.framework from ${src}..."
  snapshot_framework "${src}" "${RUNTIME_CACHE}"
}

copy_sdk_snapshot() {
  local src="$1"
  echo "[gstplayer] Snapshotting full SDK GStreamer.framework from ${src}..."
  snapshot_framework "${src}" "${SDK_CACHE}"
  write_stamp
}

migrate_runtime_snapshot() {
  local work_dir="$1"
  local runtime_pkg="${work_dir}/${RUNTIME_PKG}"
  local backup
  backup="$(mktemp -d)"

  echo "[gstplayer] Migrating: creating runtime snapshot from existing SDK cache..."
  mv "${SDK_CACHE}" "${backup}/GStreamer.framework"

  if [[ -f "${runtime_pkg}" ]]; then
    installer -pkg "${runtime_pkg}" -target CurrentUserHomeDirectory -allowUntrusted
  else
    echo "[gstplayer] Downloading runtime package for migration..."
    curl -fL --retry 3 --retry-delay 2 "${BASE}/${RUNTIME_PKG}" -o "${runtime_pkg}"
    installer -pkg "${runtime_pkg}" -target CurrentUserHomeDirectory -allowUntrusted
  fi

  if ! is_runtime_valid "${USER_FRAMEWORK}"; then
    mv "${backup}/GStreamer.framework" "${SDK_CACHE}"
    rm -rf "${backup}"
    echo "error: runtime install failed during migration" >&2
    exit 1
  fi

  copy_runtime_snapshot "${USER_FRAMEWORK}"
  mv "${backup}/GStreamer.framework" "${SDK_CACHE}"
  rm -rf "${backup}"

  if ! is_sdk_valid "${SDK_CACHE}"; then
    echo "[gstplayer] SDK cache missing headers after migration; reinstalling devel..."
    local devel_pkg="${work_dir}/${DEVEL_PKG}"
    if [[ ! -f "${devel_pkg}" ]]; then
      curl -fL --retry 3 --retry-delay 2 "${BASE}/${DEVEL_PKG}" -o "${devel_pkg}"
    fi
    installer -pkg "${devel_pkg}" -target CurrentUserHomeDirectory -allowUntrusted
    copy_sdk_snapshot "${USER_FRAMEWORK}"
  fi

  write_stamp
}

if is_sdk_valid "${SDK_CACHE}" && is_runtime_valid "${RUNTIME_CACHE}"; then
  echo "[gstplayer] GStreamer ${GST_VER} cache OK (SDK + runtime)"
  exit 0
fi

if is_sdk_valid "${SDK_CACHE}" && ! is_runtime_valid "${RUNTIME_CACHE}"; then
  WORK_DIR="$(mktemp -d)"
  cleanup() { rm -rf "${WORK_DIR}"; }
  trap cleanup EXIT
  migrate_runtime_snapshot "${WORK_DIR}"
  echo "[gstplayer] GStreamer ${GST_VER} migration complete"
  exit 0
fi

if is_sdk_valid "${USER_FRAMEWORK}" && is_runtime_valid "${USER_FRAMEWORK}"; then
  copy_runtime_snapshot "${USER_FRAMEWORK}"
  if is_sdk_valid "${USER_FRAMEWORK}"; then
    copy_sdk_snapshot "${USER_FRAMEWORK}"
  fi
  echo "[gstplayer] GStreamer ${GST_VER} ready at ${SDK_CACHE}"
  exit 0
fi

if is_sdk_valid "${SYSTEM_FRAMEWORK}"; then
  if is_runtime_valid "${SYSTEM_FRAMEWORK}" || [[ ! -d "${RUNTIME_CACHE}" ]]; then
    copy_runtime_snapshot "${SYSTEM_FRAMEWORK}"
  fi
  copy_sdk_snapshot "${SYSTEM_FRAMEWORK}"
  echo "[gstplayer] GStreamer ${GST_VER} ready at ${SDK_CACHE}"
  exit 0
fi

if [[ -n "${GSTPLAYER_GSTREAMER_ROOT:-}" || -n "${GSTREAMER_FRAMEWORK_SRC:-}" ]]; then
  echo "error: custom GStreamer path is incomplete" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

echo "[gstplayer] Downloading GStreamer ${GST_VER} universal packages..."
curl -fL --retry 3 --retry-delay 2 "${BASE}/${RUNTIME_PKG}" -o "${WORK_DIR}/${RUNTIME_PKG}"
curl -fL --retry 3 --retry-delay 2 "${BASE}/${DEVEL_PKG}" -o "${WORK_DIR}/${DEVEL_PKG}"

echo "[gstplayer] Installing runtime (CurrentUserHomeDirectory)..."
installer -pkg "${WORK_DIR}/${RUNTIME_PKG}" -target CurrentUserHomeDirectory -allowUntrusted

if ! is_runtime_valid "${USER_FRAMEWORK}"; then
  echo "error: runtime GStreamer.framework missing after install at ${USER_FRAMEWORK}" >&2
  exit 1
fi

copy_runtime_snapshot "${USER_FRAMEWORK}"

echo "[gstplayer] Installing devel (CurrentUserHomeDirectory)..."
installer -pkg "${WORK_DIR}/${DEVEL_PKG}" -target CurrentUserHomeDirectory -allowUntrusted

if ! is_sdk_valid "${USER_FRAMEWORK}"; then
  echo "error: full SDK GStreamer.framework missing after devel install at ${USER_FRAMEWORK}" >&2
  exit 1
fi

copy_sdk_snapshot "${USER_FRAMEWORK}"

source "${SCRIPT_DIR}/gstreamer_paths.sh"

echo "[gstplayer] GStreamer ${GST_VER} ready (SDK: ${GSTREAMER_FRAMEWORK_SRC}, runtime: ${GSTREAMER_RUNTIME_FRAMEWORK_SRC})"
if command -v lipo >/dev/null 2>&1; then
  lipo -info "${GSTREAMER_RUNTIME_FRAMEWORK_SRC}/Versions/1.0/lib/libgstreamer-1.0.0.dylib" || true
fi
