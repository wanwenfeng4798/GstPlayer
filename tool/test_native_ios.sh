#!/usr/bin/env bash
# Compile and link all native objects against the real iOS device SDK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/ios/scripts/gstreamer_paths.sh"
OUT="${ROOT}/native/build/ios-validation"
PODS_CONFIGURATION_BUILD_DIR="${OUT}" PLATFORM_NAME=iphoneos GSTP_IOS=1 \
  GSTREAMER_FRAMEWORK_ROOT="${GSTPLAYER_GSTREAMER_IOS_ROOT}" ARCHS=arm64 \
  bash "${ROOT}/native/scripts/build_pod.sh"
python3 - "${ROOT}" "${GSTPLAYER_GSTREAMER_IOS_ROOT}" <<'PY'
import pathlib, re, shlex, subprocess, sys
root = pathlib.Path(sys.argv[1])
framework = sys.argv[2]
out = root / 'native/build/ios-validation'
(out / 'main.c').write_text('#include "gstp_player.h"\nint main(void) { return gstp_version()[0] == 0; }\n')
podspec = (root / 'ios/gstplayer.podspec').read_text()
flags = re.search(r"'OTHER_LDFLAGS' => force_load \+ '([^']+)'", podspec).group(1)
subprocess.run(['xcrun', '--sdk', 'iphoneos', 'clang', '-arch', 'arm64',
    '-miphoneos-version-min=13.0', '-I' + str(root / 'native/include'),
    str(out / 'main.c'), '-Wl,-force_load,' + str(out / 'gstplayer/libgstplayer.a'),
    '-F' + framework, *shlex.split(flags), '-o', str(out / 'link-check')], check=True)
print('PASS: iOS arm64 compilation and static GStreamer link with podspec flags')
PY
