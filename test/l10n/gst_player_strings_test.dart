import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/l10n/gst_player_language.dart';
import 'package:gstplayer/src/l10n/gst_player_strings.dart';

void main() {
  test('zh and en strings differ for settings chrome', () {
    final zh = GstPlayerStrings.of(GstPlayerLanguage.zh);
    final en = GstPlayerStrings.of(GstPlayerLanguage.en);
    expect(zh.settings, '设置');
    expect(en.settings, 'Settings');
    expect(zh.lockControls, '锁屏');
    expect(en.lockControls, 'Lock controls');
    expect(zh.unlockControls, '解锁');
    expect(en.unlockControls, 'Unlock controls');
    expect(zh.danmakuHint, '发个弹幕呗～');
    expect(en.send, 'Send');
    expect(zh.audioTrackFallback(3), '音轨 3');
    expect(en.audioTrackFallback(3), 'Track 3');
    expect(zh.seekWaitForBuffering, '请等待缓冲完成');
    expect(en.seekWaitForBuffering, 'Please wait until buffering completes');
    expect(zh.seekNotSupported, '该文件不支持拖动');
    expect(en.seekNotSupported, 'This file cannot be scrubbed');
  });
}
