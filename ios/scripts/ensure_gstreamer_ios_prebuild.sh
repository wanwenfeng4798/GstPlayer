#!/usr/bin/env bash
# SPM prebuild wrapper: ensure iOS SDK, then write stamp files into $1
# (SwiftPM prebuildCommand output directory).
set -euo pipefail

OUT_DIR="${1:?output directory required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sh "${SCRIPT_DIR}/ensure_gstreamer_ios.sh"

# shellcheck source=gstreamer_paths.sh
source "${SCRIPT_DIR}/gstreamer_paths.sh"

HEADER="${GSTPLAYER_GSTREAMER_IOS_ROOT}/GStreamer.framework/Headers/gst/gst.h"
APPSINK="$(dirname "${HEADER}")/app/gstappsink.h"

if [[ ! -f "${HEADER}" || ! -f "${APPSINK}" ]]; then
  echo "error: GStreamer iOS headers missing after ensure:" >&2
  echo "  ${HEADER}" >&2
  echo "  ${APPSINK}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
# Avoid emitting .h files into plugin output directory.
# Xcode prints: "C header file generation not enabled" for those outputs.
rm -f "${OUT_DIR}/gst.h" "${OUT_DIR}/gstappsink.h"
echo "ok $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${OUT_DIR}/ensured"
