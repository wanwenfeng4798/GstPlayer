import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/player/playback_session.dart';
import 'package:gstplayer/src/gstplayer_controller.dart';

import 'support/fake_player_command_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GstPlayerController', () {
    test('delegates initialize to PlaybackSession', () async {
      final port = FakePlayerCommandPort();
      final session = PlaybackSession(port: port);
      final controller = GstPlayerController(session: session);

      await controller.initialize();

      expect(controller.initialized.value, isTrue);
      expect(controller.playerId.value, 42);

      await controller.dispose();
    });

    test('delegates dispose to PlaybackSession', () async {
      final port = FakePlayerCommandPort();
      final session = PlaybackSession(port: port);
      final controller = GstPlayerController(session: session);

      await controller.initialize();
      await controller.dispose();

      expect(port.playerId, isNull);
    });
  });
}
