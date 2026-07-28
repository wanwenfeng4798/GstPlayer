#!/usr/bin/env bash
# Shared path resolution for macOS GStreamer integration.
# Source this file from other scripts; do not execute directly.

if [[ -z "${HOME:-}" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    HOME="$(python3 -c 'import os, pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')"
  else
    user="$(id -un)"
    HOME="$(eval echo "~${user}")"
  fi
  export HOME
fi

GST_VER="${GST_VER:-1.28.5}"

_default_cache_root="${HOME}/Library/Caches/gstplayer/gstreamer/${GST_VER}"

if [[ -n "${GSTPLAYER_GSTREAMER_ROOT:-}" ]]; then
  GSTPLAYER_GSTREAMER_CACHE="${GSTPLAYER_GSTREAMER_ROOT}"
else
  GSTPLAYER_GSTREAMER_CACHE="${_default_cache_root}"
fi

# GSTREAMER_FRAMEWORK_SRC (full SDK): explicit > cache > legacy system install
if [[ -n "${GSTREAMER_FRAMEWORK_SRC:-}" ]]; then
  :
elif [[ -d "${GSTPLAYER_GSTREAMER_CACHE}/GStreamer.framework" ]]; then
  GSTREAMER_FRAMEWORK_SRC="${GSTPLAYER_GSTREAMER_CACHE}/GStreamer.framework"
elif [[ -d "/Library/Frameworks/GStreamer.framework" ]]; then
  GSTREAMER_FRAMEWORK_SRC="/Library/Frameworks/GStreamer.framework"
  if [[ -z "${GSTPLAYER_GSTREAMER_ROOT:-}" ]]; then
    GSTPLAYER_GSTREAMER_CACHE="/Library/Frameworks"
  fi
else
  GSTREAMER_FRAMEWORK_SRC="${GSTPLAYER_GSTREAMER_CACHE}/GStreamer.framework"
fi

# GSTREAMER_RUNTIME_FRAMEWORK_SRC (embed-only): explicit > cache runtime snapshot
if [[ -n "${GSTREAMER_RUNTIME_FRAMEWORK_SRC:-}" ]]; then
  :
elif [[ -d "${GSTPLAYER_GSTREAMER_CACHE}/GStreamerRuntime.framework" ]]; then
  GSTREAMER_RUNTIME_FRAMEWORK_SRC="${GSTPLAYER_GSTREAMER_CACHE}/GStreamerRuntime.framework"
else
  GSTREAMER_RUNTIME_FRAMEWORK_SRC="${GSTPLAYER_GSTREAMER_CACHE}/GStreamerRuntime.framework"
fi

# Directory passed to -framework / FRAMEWORK_SEARCH_PATHS (parent of GStreamer.framework)
_parent="$(dirname "${GSTREAMER_FRAMEWORK_SRC}")"
if [[ -d "${_parent}" ]]; then
  GSTREAMER_SEARCH_FRAMEWORK="$(cd "${_parent}" && pwd)"
else
  GSTREAMER_SEARCH_FRAMEWORK="${_parent}"
fi

export GST_VER GSTPLAYER_GSTREAMER_CACHE GSTREAMER_FRAMEWORK_SRC GSTREAMER_RUNTIME_FRAMEWORK_SRC GSTREAMER_SEARCH_FRAMEWORK
