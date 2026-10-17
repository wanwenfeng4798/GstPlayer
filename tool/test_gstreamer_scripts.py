#!/usr/bin/env python3
"""Regression checks for SDK cache boundaries, versions and iOS extraction."""
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


def environment():
    env = os.environ.copy()
    for key in ('GST_VER', 'GSTPLAYER_GSTREAMER_ROOT', 'GSTREAMER_ROOT_IOS',
                'GSTREAMER_FRAMEWORK_SRC', 'GSTREAMER_RUNTIME_FRAMEWORK_SRC'):
        env.pop(key, None)
    return env


class GStreamerScripts(unittest.TestCase):
    def test_default_cache_is_always_in_user_caches(self):
        script = 'source macos/scripts/gstreamer_paths.sh; printf "%s" "$GSTPLAYER_GSTREAMER_CACHE"'
        cache = subprocess.check_output(['bash', '-c', script], cwd=ROOT, env=environment(), text=True)
        self.assertEqual(cache, str(Path.home() / 'Library/Caches/gstplayer/gstreamer/1.28.8'))

    def test_incomplete_custom_paths_are_never_removed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sentinel = root / 'GStreamer.framework/sentinel'
            sentinel.parent.mkdir(); sentinel.write_text('keep')
            for platform, variable in [('macos', 'GSTPLAYER_GSTREAMER_ROOT'), ('ios', 'GSTREAMER_ROOT_IOS')]:
                env = environment(); env[variable] = tmp
                result = subprocess.run(['bash', str(ROOT / platform / 'scripts' / ('ensure_gstreamer_' + platform + '.sh'))],
                                        env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(sentinel.read_text(), 'keep')
                self.assertIn('custom', result.stderr)

    def test_sdk_version_must_match(self):
        with tempfile.TemporaryDirectory() as tmp:
            headers = Path(tmp) / 'gst'; headers.mkdir()
            (headers / 'gstversion.h').write_text('#define GST_VERSION_MAJOR (1)\n#define GST_VERSION_MINOR (28)\n#define GST_VERSION_MICRO (8)\n')
            command = 'source "$1"; gst_sdk_matches_version "$2" "$3"'
            for version, success in [('1.28.8', True), ('1.28.6', False)]:
                result = subprocess.run(['bash', '-c', command, 'test', str(ROOT / 'tool/gstreamer_pkg_expand.sh'), tmp, version])
                self.assertEqual(result.returncode == 0, success)

    def test_ios_xcframework_extract_and_cache_hit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            scripts = root / 'ios/scripts'; scripts.mkdir(parents=True)
            (root / 'tool').mkdir()
            for name in ('ensure_gstreamer_ios.sh', 'gstreamer_paths.sh'):
                shutil.copy(ROOT / 'ios/scripts' / name, scripts / name)
            shutil.copy(ROOT / 'tool/gstreamer_pkg_expand.sh', root / 'tool')
            paths = scripts / 'gstreamer_paths.sh'
            paths.write_text(paths.read_text().replace('${HOME}/Library/Caches/gstplayer/gstreamer/${GST_VER}', str(root / 'cache'))
                             .replace('${HOME}/Library/Developer/GStreamer/iPhone.sdk', str(root / 'legacy')))
            library = root / 'fixture/GStreamer.xcframework/ios-arm64'
            headers = library / 'Headers/gst'; headers.mkdir(parents=True)
            (headers / 'gst.h').write_text('/* fixture */')
            (headers / 'gstversion.h').write_text('#define GST_VERSION_MAJOR (1)\n#define GST_VERSION_MINOR (28)\n#define GST_VERSION_MICRO (8)\n')
            (library / 'libGStreamer.a').write_bytes(b'!<arch>\n')
            packages = root / 'cache/pkgs'; packages.mkdir(parents=True)
            with tarfile.open(packages / 'gstreamer-1.28.8-xcframework.tar.xz', 'w:xz') as archive:
                archive.add(root / 'fixture/GStreamer.xcframework', arcname='GStreamer.xcframework')
            for _ in range(2):
                subprocess.run(['bash', str(scripts / 'ensure_gstreamer_ios.sh')], env=environment(), check=True, capture_output=True)
            self.assertEqual((root / 'cache/ios/iPhone.sdk/GStreamer.framework/GStreamer').read_bytes(), b'!<arch>\n')


if __name__ == '__main__':
    unittest.main()
