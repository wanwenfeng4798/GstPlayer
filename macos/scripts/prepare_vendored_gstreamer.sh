#!/usr/bin/env bash
# Slim a GStreamer.framework copy for app embed / CocoaPods vendoring:
# prune plugins, drop orphan dylibs, optional arch thin, optional registry seed,
# then strip devel/CLI artifacts.
#
# Usage:
#   prepare_vendored_gstreamer.sh --link-vendored
#   prepare_vendored_gstreamer.sh /path/to/GStreamer.framework [--with-seed]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "${1:-}" == "--link-vendored" ]]; then
  VENDORED_DIR="${MACOS_DIR}/Vendored"
  VENDORED_FW="${VENDORED_DIR}/GStreamer.framework"
  # shellcheck source=gstreamer_paths.sh
  source "${SCRIPT_DIR}/gstreamer_paths.sh"
  if [[ "${GSTPLAYER_ALLOW_HOMEBREW_GSTREAMER:-}" == "1" ]]; then
    rm -rf "${VENDORED_DIR}"
    exit 0
  fi
  RUNTIME_SRC="${GSTREAMER_RUNTIME_FRAMEWORK_SRC}"
  if [[ ! -f "${RUNTIME_SRC}/Versions/1.0/lib/libgstreamer-1.0.0.dylib" ]]; then
    echo "error: runtime GStreamer.framework not found at ${RUNTIME_SRC}" >&2
    echo "Run: sh macos/scripts/ensure_gstreamer_macos.sh" >&2
    exit 1
  fi
  mkdir -p "${VENDORED_DIR}"
  rm -rf "${VENDORED_FW}"
  cp -Rc "${RUNTIME_SRC}" "${VENDORED_FW}"
  bash "${SCRIPT_DIR}/prepare_vendored_gstreamer.sh" "${VENDORED_FW}"
  size="$(du -sh "${VENDORED_FW}" | awk '{print $1}')"
  echo "[gstplayer] Vendored slim GStreamer.framework (${size}) from ${RUNTIME_SRC}"
  exit 0
fi

FRAMEWORK="${1:?framework path required}"
WITH_SEED=0
if [[ "${2:-}" == "--with-seed" ]]; then
  WITH_SEED=1
fi
WHITELIST="${MACOS_DIR}/gstreamer_playback_plugins.txt"
PLUGIN_DIR="${FRAMEWORK}/Versions/1.0/lib/gstreamer-1.0"
LIB_DIR="${FRAMEWORK}/Versions/1.0/lib"
ARCH="${GSTPLAYER_GSTREAMER_ARCH:-universal}"

if [[ ! -d "${FRAMEWORK}" ]]; then
  echo "error: framework not found: ${FRAMEWORK}" >&2
  exit 1
fi

# --- prune plugins -----------------------------------------------------------
if [[ ! -d "${PLUGIN_DIR}" ]]; then
  echo "error: plugin dir not found: ${PLUGIN_DIR}" >&2
  exit 1
fi
if [[ ! -f "${WHITELIST}" ]]; then
  echo "error: whitelist not found: ${WHITELIST}" >&2
  exit 1
fi

is_whitelisted() {
  local name="$1"
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "${line}" ]] && continue
    if [[ "${line}" == "${name}" ]]; then
      return 0
    fi
  done < "${WHITELIST}"
  return 1
}

removed=0
kept=0
for plugin in "${PLUGIN_DIR}"/libgst*.dylib; do
  [[ -e "${plugin}" ]] || continue
  base="$(basename "${plugin}")"
  name="${base#libgst}"
  name="${name%.dylib}"
  if is_whitelisted "${name}"; then
    kept=$((kept + 1))
  else
    rm -f "${plugin}"
    removed=$((removed + 1))
  fi
done
echo "[gstplayer] Pruned GStreamer plugins: kept ${kept}, removed ${removed}"

# --- prune orphan dylibs -----------------------------------------------------
is_protected() {
  case "$1" in
    libMoltenVK.dylib|libgstreamer-1.0.0.dylib|libgstbase-1.0.0.dylib|\
    libgstreamer-1.0.dylib|libgstbase-1.0.dylib|libglib-2.0.0.dylib|\
    libgobject-2.0.0.dylib|libgio-2.0.0.dylib|libgmodule-2.0.0.dylib|\
    libgiolibopenssl.so|libgioopenssl.so|\
    libintl.8.dylib|liborc-0.4.0.dylib|libavcodec.61.dylib|libavformat.61.dylib|\
    libavutil.59.dylib|libswresample.5.dylib|libcrypto.3.dylib|libssl.3.dylib)
      return 0
      ;;
  esac
  return 1
}

if [[ -d "${LIB_DIR}" ]]; then
  raw_refs="$(mktemp)"
  refs_file="$(mktemp)"
  while IFS= read -r macho; do
    otool -L "${macho}" 2>/dev/null | tail -n +2 | awk '{print $1}' >> "${raw_refs}" || true
  done < <(find "${FRAMEWORK}" \( -name '*.dylib' -o -name '*.so' \) -type f)

  while IFS= read -r dep; do
    [[ -n "${dep}" ]] || continue
    basename "${dep}"
  done < "${raw_refs}" | sort -u > "${refs_file}"
  rm -f "${raw_refs}"

  removed=0
  for dylib in "${LIB_DIR}"/*.dylib; do
    [[ -e "${dylib}" ]] || continue
    base="$(basename "${dylib}")"
    if is_protected "${base}"; then
      continue
    fi
    if ! grep -Fxq "${base}" "${refs_file}" 2>/dev/null; then
      rm -f "${dylib}"
      removed=$((removed + 1))
      echo "[gstplayer] Removed orphan dylib: ${base}"
    fi
  done
  rm -f "${refs_file}"
  echo "[gstplayer] Orphan dylib cleanup removed ${removed} file(s)"

  dangling=0
  while IFS= read -r -d '' link; do
    rm -f "${link}"
    dangling=$((dangling + 1))
    echo "[gstplayer] Removed dangling symlink: $(basename "${link}")"
  done < <(find "${LIB_DIR}" -type l ! -exec test -e {} \; -print0 2>/dev/null)
  if [[ "${dangling}" -gt 0 ]]; then
    echo "[gstplayer] Dangling symlink cleanup removed ${dangling} link(s)"
  fi
fi

# --- thin arch ---------------------------------------------------------------
if [[ "${ARCH}" == "universal" ]]; then
  echo "[gstplayer] GStreamer framework arch: universal (no thinning)"
elif [[ "${ARCH}" != "arm64" && "${ARCH}" != "x86_64" ]]; then
  echo "error: unsupported arch '${ARCH}' (use arm64, x86_64, or universal)" >&2
  exit 1
elif ! command -v lipo >/dev/null 2>&1; then
  echo "error: lipo not found" >&2
  exit 1
else
  thin_one() {
    local file="$1"
    if ! file "${file}" | grep -q 'Mach-O'; then
      return 0
    fi
    if ! lipo -info "${file}" 2>/dev/null | grep -q 'Architectures'; then
      return 0
    fi
    if ! lipo -info "${file}" 2>/dev/null | grep -q "${ARCH}"; then
      echo "warning: ${file} has no ${ARCH} slice; skipping" >&2
      return 0
    fi
    local tmp
    tmp="$(mktemp "${file}.thin.XXXXXX")"
    lipo -thin "${ARCH}" "${file}" -output "${tmp}"
    mv "${tmp}" "${file}"
  }
  while IFS= read -r macho; do
    thin_one "${macho}"
  done < <(find "${FRAMEWORK}" \( -name '*.dylib' -o -name '*.so' -o -name 'GStreamer' \) -type f)
  echo "[gstplayer] Thinned GStreamer.framework to ${ARCH}"
fi

# --- seed registry (optional; needs gst-inspect before strip) ----------------
if [[ "${WITH_SEED}" -eq 1 ]]; then
  LIB="${FRAMEWORK}/Versions/1.0/lib"
  PLUGINS="${LIB}/gstreamer-1.0"
  INSPECT="${FRAMEWORK}/Versions/1.0/bin/gst-inspect-1.0"
  SEED="${LIB}/gstreamer-registry.bin.seed"
  if [[ -d "${PLUGINS}" && -x "${INSPECT}" ]]; then
    TMP_REG="$(mktemp -t gstp-gst-registry)"
    rm -f "${TMP_REG}"
    export GST_PLUGIN_SYSTEM_PATH="${PLUGINS}"
    export GST_PLUGIN_PATH=""
    export GST_REGISTRY_FORK=no
    export GST_REGISTRY="${TMP_REG}"
    export GST_PLUGIN_SYSTEM_PATH_1_0="${PLUGINS}"
    if "${INSPECT}" > /dev/null 2>&1 && [[ -f "${TMP_REG}" ]]; then
      cp -f "${TMP_REG}" "${SEED}"
      echo "[gstplayer] Seeded GStreamer registry ($(du -h "${SEED}" | awk '{print $1}'))"
    else
      echo "warning: gst-inspect registry seed skipped" >&2
    fi
    rm -f "${TMP_REG}"
  else
    echo "warning: gst-inspect-1.0 missing; skipping registry seed" >&2
  fi
fi

# --- strip devel / CLI -------------------------------------------------------
find "${FRAMEWORK}" -maxdepth 1 -name '.*' -type f -delete 2>/dev/null || true
find "${FRAMEWORK}" -name '*.a' -delete 2>/dev/null || true
rm -rf \
  "${FRAMEWORK}/Versions/1.0/include" \
  "${FRAMEWORK}/Versions/1.0/share" \
  "${FRAMEWORK}/Versions/1.0/bin" \
  "${FRAMEWORK}/Versions/1.0/libexec" \
  "${FRAMEWORK}/Versions/1.0/lib/pkgconfig" \
  "${FRAMEWORK}/Versions/1.0/etc/fonts" \
  2>/dev/null || true
rm -f \
  "${FRAMEWORK}/Commands" \
  "${FRAMEWORK}/Headers" \
  "${FRAMEWORK}/Versions/1.0/Commands"

dangling=0
while IFS= read -r -d '' link; do
  rm -f "${link}"
  dangling=$((dangling + 1))
  echo "[gstplayer] Removed dangling symlink: ${link#${FRAMEWORK}/}"
done < <(find "${FRAMEWORK}" -type l ! -exec test -e {} \; -print0 2>/dev/null)
if [[ "${dangling}" -gt 0 ]]; then
  echo "[gstplayer] Framework dangling symlink cleanup removed ${dangling} link(s)"
fi

echo "[gstplayer] Prepared vendored GStreamer.framework"
