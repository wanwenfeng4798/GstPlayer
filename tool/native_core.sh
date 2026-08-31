#!/usr/bin/env bash
# NativeCore maintenance helper.
# Usage:
#   ./tool/native_core.sh sync
#   ./tool/native_core.sh verify
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_INCLUDE="${ROOT}/native/include"
SRC_SRC="${ROOT}/native/src"

usage() {
  cat <<'EOF'
Usage:
  ./tool/native_core.sh sync
  ./tool/native_core.sh verify
EOF
}

ensure_native_sources() {
  if [[ ! -d "${SRC_INCLUDE}" || ! -d "${SRC_SRC}" ]]; then
    echo "error: native sources missing under ${ROOT}/native" >&2
    exit 1
  fi
}

sync_platform() {
  local platform="$1"
  local dest="${ROOT}/${platform}/gstplayer/NativeCore"
  mkdir -p "${dest}"

  rm -rf "${dest}/include" "${dest}/src"
  cp -R "${SRC_INCLUDE}" "${dest}/include"
  cp -R "${SRC_SRC}" "${dest}/src"

  for required in gstp_player.c gstp_ffi_keep.c; do
    if [[ ! -f "${dest}/src/${required}" ]]; then
      echo "error: ${platform} NativeCore missing ${required} after sync" >&2
      exit 1
    fi
  done
  if [[ ! -f "${dest}/include/gstp_player.h" ]]; then
    echo "error: ${platform} NativeCore missing include/gstp_player.h after sync" >&2
    exit 1
  fi

  echo "[gstplayer] synced native/ -> ${platform}/gstplayer/NativeCore"
}

run_sync() {
  ensure_native_sources
  sync_platform ios
  sync_platform macos
  echo "[gstplayer] NativeCore sync complete"
}

verify_platform() {
  local platform="$1"
  local core="${ROOT}/${platform}/gstplayer/NativeCore"
  local src="${core}/src"
  local include="${core}/include"

  if [[ -L "${src}" || -L "${include}" ]]; then
    echo "error: ${platform} NativeCore still uses symlinks; run ./tool/native_core.sh sync" >&2
    return 1
  fi

  if [[ -f "${src}" && ! -d "${src}" ]]; then
    echo "error: ${platform} NativeCore/src is a file (pub symlink stub?), not a directory" >&2
    return 1
  fi
  if [[ ! -d "${src}" || ! -d "${include}" ]]; then
    echo "error: ${platform} NativeCore missing include/ or src/ directories" >&2
    return 1
  fi

  local ok=0
  for required in gstp_player.c gstp_ffi_keep.c frame.c pipeline.c; do
    local f="${src}/${required}"
    if [[ ! -f "${f}" ]]; then
      echo "error: ${platform} NativeCore missing src/${required}" >&2
      ok=1
      continue
    fi
    local size
    size="$(wc -c < "${f}" | tr -d ' ')"
    if [[ "${size}" -lt 100 ]]; then
      echo "error: ${platform} NativeCore/src/${required} is only ${size} bytes (stub?)" >&2
      ok=1
    fi
  done

  if [[ ! -f "${include}/gstp_player.h" ]]; then
    echo "error: ${platform} NativeCore missing include/gstp_player.h" >&2
    ok=1
  fi
  return "${ok}"
}

run_verify() {
  ensure_native_sources
  local failed=0
  verify_platform ios || failed=1
  verify_platform macos || failed=1

  if [[ "${failed}" -ne 0 ]]; then
    echo "NativeCore verification failed" >&2
    exit 1
  fi
  echo "[gstplayer] NativeCore verification OK"
}

cmd="${1:-}"
case "${cmd}" in
  sync)
    run_sync
    ;;
  verify)
    run_verify
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
