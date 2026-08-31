import 'package:flutter_test/flutter_test.dart';
import 'package:gstplayer/src/overlay/danmaku.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('danmaku interpolates position while playing', (tester) async {
    const items = [
      DanmakuItem(
        at: Duration.zero,
        text: 'hello',
        duration: Duration(seconds: 10),
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 200,
            child: DanmakuOverlay(
              items: items,
              position: Duration.zero,
              enabled: true,
              isPlaying: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final before = tester.getTopLeft(find.text('hello'));
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester.getTopLeft(find.text('hello'));
    expect(after.dx, lessThan(before.dx));
  });

  testWidgets('danmaku does not extrapolate while paused', (tester) async {
    const items = [
      DanmakuItem(
        at: Duration.zero,
        text: 'hello',
        duration: Duration(seconds: 10),
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 200,
            child: DanmakuOverlay(
              items: items,
              position: Duration(milliseconds: 500),
              enabled: true,
              isPlaying: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = tester.getTopLeft(find.text('hello'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.text('hello')).dx, before.dx);
  });

  testWidgets('danmaku ignores small native drift while playing', (tester) async {
    const items = [
      DanmakuItem(
        at: Duration.zero,
        text: 'hello',
        duration: Duration(seconds: 10),
      ),
    ];

    var position = Duration.zero;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DanmakuOverlay(
                items: items,
                position: position,
                enabled: true,
                isPlaying: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before = tester.getTopLeft(find.text('hello'));

    position = const Duration(milliseconds: 150);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DanmakuOverlay(
            items: items,
            position: position,
            enabled: true,
            isPlaying: true,
          ),
        ),
      ),
    );
    await tester.pump();
    final after = tester.getTopLeft(find.text('hello'));
    // Small native corrections must not jump backward along the scroll path.
    expect(after.dx, lessThanOrEqualTo(before.dx + 1));
  });
}
