import 'package:dead_or_alive/features/nine_judges/promo/screens/promo_player_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recordingZoom scales up the board layer only', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: PromoPlayerScreen(recordingZoom: 1.5)),
    );
    await tester.pump(); // let rootBundle.loadString's Future resolve
    await tester.pump(); // let the resulting setState rebuild land

    final recordingZoomFinder = find.ancestor(
      of: find.byType(BoardArea),
      matching: find.byWidgetPredicate(
        (w) => w is Transform && w.transform.getMaxScaleOnAxis() > 1.001,
      ),
    );
    expect(recordingZoomFinder, findsOneWidget);
    final scaleTransform = tester.widget<Transform>(recordingZoomFinder);
    expect(scaleTransform.transform.getMaxScaleOnAxis(), closeTo(1.5, 0.001));

    // The score banner sits outside that scaled subtree entirely.
    expect(
      find.ancestor(
        of: find.text('救済者'),
        matching: find.byWidgetPredicate(
          (w) => w is Transform && w.transform.getMaxScaleOnAxis() > 1.001,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'sits on a setup screen with the guide + start button until tapped, then plays with the guide hidden',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: PromoPlayerScreen()));
      await tester.pump(); // let rootBundle.loadString's Future resolve
      await tester.pump(); // let the resulting setState rebuild land

      expect(find.byKey(const Key('promo-player-stack')), findsOneWidget);
      expect(find.byKey(const Key('promo-error')), findsNothing);
      // Before the tap: setup phase — start button + safe-area guide are
      // showing, nothing has started playing yet (no caption, no dead air).
      expect(find.byKey(const Key('promo-recording-start')), findsOneWidget);
      expect(find.byKey(const Key('promo-safe-area-guide')), findsOneWidget);
      expect(find.byKey(const Key('promo-caption-text')), findsNothing);

      // The score banner is always visible, even before recording starts.
      expect(find.text('救済者'), findsOneWidget);
      expect(find.text('執行者'), findsOneWidget);

      await tester.tap(find.byKey(const Key('promo-recording-start')));
      await tester.pump(); // start() fires its first advanceTo(Duration.zero)

      // After the tap: the setup button and guide are both gone, and the
      // first caption cue (t=[0,1)) is already showing.
      expect(find.byKey(const Key('promo-recording-start')), findsNothing);
      expect(find.byKey(const Key('promo-safe-area-guide')), findsNothing);
      expect(find.byKey(const Key('promo-caption-text')), findsOneWidget);

      // No end card yet — the default script's endCard starts at t=12.5s and
      // start()'s Timer.periodic advances against a real Stopwatch, so a
      // widget-test pump() (fake-clock only) can't fast-forward it here.
      expect(find.byKey(const Key('promo-end-card')), findsNothing);

      // Advance past the scripted actions without throwing.
      await tester.pump(const Duration(seconds: 8));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unloadable script asset shows an error instead of crashing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: PromoPlayerScreen(scriptAssetPath: 'assets/promo/missing.json'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('promo-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
