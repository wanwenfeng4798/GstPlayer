#!/usr/bin/env bash
# Shared helpers for expanding official GStreamer .pkg files into a framework tree
# without `installer`. Requires macOS `pkgutil --expand-full` (Payload auto-extracted).
#
# Source this file; do not execute directly.
# shellcheck shell=bash

# Expand a flat .pkg into DEST (contents under DEST/*.pkg/Payload/...).
gst_pkg_expand_full() {
  local pkg="$1"
  local dest="$2"
  if ! pkgutil --expand-full "${pkg}" "${dest}" >/dev/null 2>&1; then
    echo "error: pkgutil --expand-full failed for ${pkg}" >&2
    echo "  Requires a recent macOS pkgutil that supports --expand-full." >&2
    return 1
  fi
}

# Merge every subpackage Payload from an expand-full tree into FRAMEWORK_DEST
# using PackageInfo install-location (GStreamer.framework or .../Versions/1.0).
gst_pkg_merge_into_framework() {
  local expanded="$1"
  local framework_dest="$2"
  local subpkg loc dest

  mkdir -p "${framework_dest}"

  for subpkg in "${expanded}"/*.pkg; do
    [[ -d "${subpkg}/Payload" ]] || continue
    [[ -f "${subpkg}/PackageInfo" ]] || continue
    loc="$(sed -n 's/.*install-location="\([^"]*\)".*/\1/p' "${subpkg}/PackageInfo" | head -1)"
    case "${loc}" in
      */GStreamer.framework/Versions/1.0|*/GStreamer.framework/Versions/1.0/)
        dest="${framework_dest}/Versions/1.0"
        ;;
      */GStreamer.framework|*/GStreamer.framework/)
        dest="${framework_dest}"
        ;;
      */iPhone.sdk|*/iPhone.sdk/)
        # iOS devel: Payload already contains GStreamer.framework/
        dest="${framework_dest%/*}"
        if [[ "$(basename "${framework_dest}")" == "GStreamer.framework" ]]; then
          dest="$(dirname "${framework_dest}")"
        else
          dest="${framework_dest}"
        fi
        ;;
      *)
        if [[ -d "${subpkg}/Payload/GStreamer.framework" ]]; then
          dest="$(dirname "${framework_dest}")"
          if [[ "$(basename "${framework_dest}")" != "GStreamer.framework" ]]; then
            dest="${framework_dest}"
          fi
        elif [[ -d "${subpkg}/Payload/Versions" || -d "${subpkg}/Payload/lib" ]]; then
          dest="${framework_dest}/Versions/1.0"
        else
          dest="${framework_dest}"
        fi
        ;;
    esac
    mkdir -p "${dest}"
    ditto "${subpkg}/Payload/" "${dest}/"
  done
}

# Download URL to FILE if missing (or FORCE=1).
# Optional 3rd arg: human size hint for the first-time log (e.g. "~480MB").
gst_pkg_download() {
  local url="$1"
  local file="$2"
  local size_hint="${3:-}"
  if [[ -f "${file}" && "${GSTPLAYER_FORCE_PKG_DOWNLOAD:-}" != "1" ]]; then
    echo "[gstplayer] Using cached package $(basename "${file}")"
    return 0
  fi
  mkdir -p "$(dirname "${file}")"
  if [[ -n "${size_hint}" ]]; then
    echo "[gstplayer] Downloading $(basename "${file}") (${size_hint})..."
  else
    echo "[gstplayer] Downloading $(basename "${file}")..."
  fi
  # Progress meter on stderr so Xcode/Flutter logs stay readable.
  curl -fL --retry 3 --retry-delay 2 --progress-bar \
    "${url}" -o "${file}.partial"
  if [[ -f "${file}.partial" ]]; then
    mv "${file}.partial" "${file}"
  elif [[ ! -f "${file}" ]]; then
    echo "error: download finished but ${file} is missing" >&2
    return 1
  fi
  echo "[gstplayer] Downloaded $(basename "${file}")"
}
