#!/usr/bin/env bash
# Shared path resolution for iOS GStreamer integration.
# Source this file from other scripts; do not execute directly.

# Xcode SPM build-tool plugins often run with HOME unset; `set -u` scripts must fix this first.
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

_default_cache_ios="${HOME}/Library/Caches/gstplayer/gstreamer/${GST_VER}/ios/iPhone.sdk"
_legacy_ios="${HOME}/Library/Developer/GStreamer/iPhone.sdk"

GSTPLAYER_GSTREAMER_IOS_ROOT_IS_CUSTOM=0
if [[ -n "${GSTREAMER_ROOT_IOS:-}" ]]; then
  GSTPLAYER_GSTREAMER_IOS_ROOT="${GSTREAMER_ROOT_IOS}"
  GSTPLAYER_GSTREAMER_IOS_ROOT_IS_CUSTOM=1
else
  GSTPLAYER_GSTREAMER_IOS_ROOT="${_default_cache_ios}"
fi

GSTREAMER_IOS_PKG="gstreamer-1.0-devel-${GST_VER}-ios-universal.pkg"
GSTREAMER_IOS_PKG_URL="https://gstreamer.freedesktop.org/data/pkg/ios/${GST_VER}/${GSTREAMER_IOS_PKG}"
GSTPLAYER_GSTREAMER_IOS_PKG_DIR="${HOME}/Library/Caches/gstplayer/gstreamer/${GST_VER}/pkgs"
STAMP="${GSTPLAYER_GSTREAMER_IOS_ROOT}/.install_stamp"
GSTPLAYER_GSTREAMER_IOS_LEGACY="${_legacy_ios}"

export GST_VER \
  GSTPLAYER_GSTREAMER_IOS_ROOT \
  GSTPLAYER_GSTREAMER_IOS_ROOT_IS_CUSTOM \
  GSTREAMER_ROOT_IOS="${GSTPLAYER_GSTREAMER_IOS_ROOT}" \
  GSTREAMER_IOS_PKG \
  GSTREAMER_IOS_PKG_URL \
  GSTPLAYER_GSTREAMER_IOS_PKG_DIR \
  GSTPLAYER_GSTREAMER_IOS_LEGACY \
  STAMP
