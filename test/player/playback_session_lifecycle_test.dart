import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/gstplayer.dart';
import 'package:gstplayer/src/domain/player_events.dart'
    show MediaSourceDto, MediaSourceDto_Uri;
import 'package:gstplayer/src/player/playback_session.dart';

import '../support/fake_player_command_port.dart';
import '../support/player_event_fixtures.dart';

class GatedPort extends FakePlayerCommandPort {
  final createGate = Completer<void>();
  Completer<void>? loadGate;
  Completer<void>? tracksGate;
  var creates = 0;
  var disposals = 0;
  bool failBlockedLoad = false;
  @override
  Future<void> create() async {
    creates++;
    await createGate.future;
    await super.create();
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await super.dispose();
  }

  @override
  Future<void> loadSource(
    MediaSourceDto source, {
    required bool autoPlay,
  }) async {
    final gate = loadGate;
    loadGate = null;
    await gate?.future;
    if (gate != null && failBlockedLoad) throw StateError('old load failed');
    await super.loadSource(source, autoPlay: autoPlay);
  }

  @override
  Future<List<MediaTrack>> getTracks() async {
    await tracksGate?.future;
    return super.getTracks();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'concurrent initialize shares one creation and disposal is idempotent',
    () async {
      final port = GatedPort();
      final session = PlaybackSession(port: port);
      final first = session.initialize();
      final second = session.initialize();
      expect(identical(first, second), isTrue);
      expect(port.creates, 1);
      port.createGate.complete();
      await first;
      await Future.wait([session.dispose(), session.dispose()]);
      expect(port.disposals, 1);
    },
  );
  test(
    'dispose waits for pending initialization and prevents revival',
    () async {
      final port = GatedPort();
      final session = PlaybackSession(port: port);
      final initializing = session.initialize();
      final disposing = session.dispose();
      port.createGate.complete();
      await Future.wait([initializing, disposing]);
      expect(session.initialized, isFalse);
      expect(session.playerId, isNull);
      expect(port.disposals, 1);
      await expectLater(session.initialize(), throwsStateError);
    },
  );
  test('stale load failure cannot overwrite a newer open', () async {
    final port = GatedPort()..createGate.complete();
    final session = PlaybackSession(port: port);
    await session.initialize();
    final gate = Completer<void>();
    port.loadGate = gate;
    port.failBlockedLoad = true;
    final old = session.open(
      const VideoSource.network('https://example.com/old'),
    );
    await Future<void>.delayed(Duration.zero);
    final fresh = session.open(
      const VideoSource.network('https://example.com/new'),
    );
    gate.complete();
    await Future.wait([old, fresh]);
    expect(session.error, isNull);
    expect((port.lastLoadedSource as MediaSourceDto_Uri).uri, endsWith('/new'));
    await session.dispose();
  });
  test('track query completing after disposal does not notify', () async {
    final port = GatedPort()..createGate.complete();
    final session = PlaybackSession(port: port);
    await session.initialize();
    final gate = Completer<void>();
    port.tracksGate = gate;
    final query = session.refreshTracks();
    await session.dispose();
    gate.complete();
    await query;
    expect(session.tracks, isEmpty);
  });
  test('native errors clear initial loading overlay', () async {
    final port = FakePlayerCommandPort();
    final session = PlaybackSession(port: port);
    await session.initialize();
    await session.open(const VideoSource.network('https://example.com/bad'));
    port.emit(PlayerEventFixtures.error());
    await Future<void>.delayed(Duration.zero);
    expect(session.showLoadingOverlay, isFalse);
    expect(session.hideVideoSurface, isFalse);
    await session.dispose();
  });
  test(
    'paused preroll with a frame clears loading without requiring play',
    () async {
      final port = FakePlayerCommandPort();
      final session = PlaybackSession(port: port);
      await session.initialize();
      await session.open(
        const VideoSource.network('https://example.com/video'),
      );
      for (final kind in [
        PlayerEventKind.videoSize,
        PlayerEventKind.buffering,
        PlayerEventKind.stateChanged,
      ]) {
        port.emit(
          PlayerEvent(
            kind: kind,
            positionMs: 0,
            durationMs: 10000,
            width: 640,
            height: 360,
            bufferingPercent: 100,
            state: PlayerState.paused,
            message: '',
            fps: 30,
            pixelAspectWidth: 1,
            pixelAspectHeight: 1,
            displayAspectWidth: 16,
            displayAspectHeight: 9,
            interlaced: false,
            colorMatrix: '',
            colorRange: '',
            hdrFormat: '',
            isSeekable: true,
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(session.hideVideoSurface, isFalse);
      expect(session.showLoadingOverlay, isFalse);
      await session.dispose();
    },
  );
  test('stop during initial loading clears loading overlay', () async {
    final session = PlaybackSession(port: FakePlayerCommandPort());
    await session.initialize();
    await session.open(const VideoSource.network('https://example.com/video'));
    await session.stop();
    expect(session.showLoadingOverlay, isFalse);
    await session.dispose();
  });
}
