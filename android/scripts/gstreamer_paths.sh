#!/usr/bin/env bash
# Shared path resolution for Android GStreamer integration.
# Source this file from other scripts; do not execute directly.

GST_VER="${GST_VER:-1.28.6}"

GSTPLAYER_GSTREAMER_ANDROID_ROOT_IS_CUSTOM=0
if [[ -n "${GSTREAMER_ROOT_ANDROID:-}" ]]; then
  GSTPLAYER_GSTREAMER_ANDROID_ROOT="${GSTREAMER_ROOT_ANDROID}"
  GSTPLAYER_GSTREAMER_ANDROID_ROOT_IS_CUSTOM=1
elif [[ -n "${GSTPLAYER_GSTREAMER_ROOT:-}" ]]; then
  GSTPLAYER_GSTREAMER_ANDROID_ROOT="${GSTPLAYER_GSTREAMER_ROOT}"
  GSTPLAYER_GSTREAMER_ANDROID_ROOT_IS_CUSTOM=1
else
  case "$(uname -s)" in
    Darwin)
      _cache_parent="${HOME}/Library/Caches"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      _cache_parent="${LOCALAPPDATA:-${HOME}/AppData/Local}"
      ;;
    *)
      _cache_parent="${XDG_CACHE_HOME:-${HOME}/.cache}"
      ;;
  esac
  GSTPLAYER_GSTREAMER_ANDROID_ROOT="${_cache_parent}/gstplayer/gstreamer/android/${GST_VER}"
fi

GSTREAMER_ANDROID_TARBALL="gstreamer-1.0-android-universal-${GST_VER}.tar.xz"
GSTREAMER_ANDROID_TARBALL_URL="https://gstreamer.freedesktop.org/data/pkg/android/${GST_VER}/${GSTREAMER_ANDROID_TARBALL}"

STAMP="${GSTPLAYER_GSTREAMER_ANDROID_ROOT}/.install_stamp"

export GST_VER \
  GSTPLAYER_GSTREAMER_ANDROID_ROOT \
  GSTPLAYER_GSTREAMER_ANDROID_ROOT_IS_CUSTOM \
  GSTREAMER_ROOT_ANDROID="${GSTPLAYER_GSTREAMER_ANDROID_ROOT}" \
  GSTREAMER_ANDROID_TARBALL \
  GSTREAMER_ANDROID_TARBALL_URL \
  STAMP
