import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/utils/device_user_agent.dart';

void main() {
  test('fromPlatform returns a non-empty Mozilla user agent', () {
    final ua = fromPlatform();
    expect(ua, isNotEmpty);
    expect(ua, startsWith('Mozilla/5.0'));
  });
}
