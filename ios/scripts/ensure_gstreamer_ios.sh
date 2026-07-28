#!/usr/bin/env bash
# Downloads and extracts the official GStreamer iOS SDK into the user cache.
# No sudo / installer — uses pkgutil --expand-full.
#
# Cache layout:
#   ~/Library/Caches/gstplayer/gstreamer/<ver>/ios/iPhone.sdk/GStreamer.framework
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=gstreamer_paths.sh
source "${SCRIPT_DIR}/gstreamer_paths.sh"
# shellcheck source=../../tool/gstreamer_pkg_expand.sh
source "${ROOT}/tool/gstreamer_pkg_expand.sh"

is_sdk_valid() {
  local root="$1"
  [[ -f "${root}/GStreamer.framework/Headers/gst/gst.h" ]]
}

write_stamp() {
  mkdir -p "${GSTPLAYER_GSTREAMER_IOS_ROOT}"
  {
    echo "version=${GST_VER}"
    echo "root=${GSTPLAYER_GSTREAMER_IOS_ROOT}"
    echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "${STAMP}"
}

# Cache hit: stay quiet (SPM / pod install may call this often).
if is_sdk_valid "${GSTPLAYER_GSTREAMER_IOS_ROOT}"; then
  if [[ "${GSTPLAYER_VERBOSE:-}" == "1" ]]; then
    echo "[gstplayer] GStreamer iOS ${GST_VER} cache OK at ${GSTPLAYER_GSTREAMER_IOS_ROOT}"
  fi
  exit 0
fi

if [[ "${GSTPLAYER_GSTREAMER_IOS_ROOT_IS_CUSTOM}" == "1" ]]; then
  echo "error: custom GStreamer iOS path is incomplete at ${GSTPLAYER_GSTREAMER_IOS_ROOT}" >&2
  echo "  Expected GStreamer.framework/Headers/gst/gst.h" >&2
  exit 1
fi

# Prefer an existing user-domain installer layout without re-downloading.
if is_sdk_valid "${GSTPLAYER_GSTREAMER_IOS_LEGACY}"; then
  echo "[gstplayer] Copying existing iOS SDK from ${GSTPLAYER_GSTREAMER_IOS_LEGACY} (~1 min)..."
  mkdir -p "$(dirname "${GSTPLAYER_GSTREAMER_IOS_ROOT}")"
  rm -rf "${GSTPLAYER_GSTREAMER_IOS_ROOT}"
  ditto "${GSTPLAYER_GSTREAMER_IOS_LEGACY}" "${GSTPLAYER_GSTREAMER_IOS_ROOT}"
  write_stamp
  echo "[gstplayer] GStreamer iOS ${GST_VER} ready at ${GSTPLAYER_GSTREAMER_IOS_ROOT}"
  exit 0
fi

if [[ -e "${GSTPLAYER_GSTREAMER_IOS_ROOT}" ]]; then
  echo "[gstplayer] Removing incomplete iOS GStreamer cache at ${GSTPLAYER_GSTREAMER_IOS_ROOT}..."
  rm -rf "${GSTPLAYER_GSTREAMER_IOS_ROOT}"
fi

echo "[gstplayer] =============================================="
echo "[gstplayer] First-time GStreamer iOS ${GST_VER} setup"
echo "[gstplayer] Download: ~480MB devel package (often 1–3 min)"
echo "[gstplayer] Extract:  typically ~1–2 min after download"
echo "[gstplayer] Cache:    ${GSTPLAYER_GSTREAMER_IOS_ROOT}"
echo "[gstplayer] Later builds reuse this cache (no re-download)."
echo "[gstplayer] =============================================="

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

PKG_FILE="${GSTPLAYER_GSTREAMER_IOS_PKG_DIR}/${GSTREAMER_IOS_PKG}"
gst_pkg_download "${GSTREAMER_IOS_PKG_URL}" "${PKG_FILE}" "~480MB"

EXPAND="${WORK_DIR}/expand"
echo "[gstplayer] Expanding ${GSTREAMER_IOS_PKG} (about 1–2 min)..."
gst_pkg_expand_full "${PKG_FILE}" "${EXPAND}"

STAGE="${WORK_DIR}/stage"
mkdir -p "${STAGE}"
# iOS install-location is iPhone.sdk; Payload contains GStreamer.framework (+ Templates).
for subpkg in "${EXPAND}"/*.pkg; do
  [[ -d "${subpkg}/Payload" ]] || continue
  ditto "${subpkg}/Payload/" "${STAGE}/"
done

if [[ ! -f "${STAGE}/GStreamer.framework/Headers/gst/gst.h" ]]; then
  echo "error: GStreamer.framework missing after expanding ${GSTREAMER_IOS_PKG}" >&2
  find "${EXPAND}" -maxdepth 3 -type d 2>/dev/null | head -40 >&2 || true
  exit 1
fi

mkdir -p "$(dirname "${GSTPLAYER_GSTREAMER_IOS_ROOT}")"
rm -rf "${GSTPLAYER_GSTREAMER_IOS_ROOT}"
ditto "${STAGE}" "${GSTPLAYER_GSTREAMER_IOS_ROOT}"

if ! is_sdk_valid "${GSTPLAYER_GSTREAMER_IOS_ROOT}"; then
  echo "error: iOS SDK extraction failed at ${GSTPLAYER_GSTREAMER_IOS_ROOT}" >&2
  exit 1
fi

write_stamp
echo "[gstplayer] GStreamer iOS ${GST_VER} ready at ${GSTPLAYER_GSTREAMER_IOS_ROOT}"
