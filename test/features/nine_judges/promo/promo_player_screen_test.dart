import 'package:dead_or_alive/features/nine_judges/promo/screens/promo_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the default script, shows the board and a caption, no exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PromoPlayerScreen()));
    await tester.pump(); // let rootBundle.loadString's Future resolve
    await tester.pump(); // start() fires its first advanceTo(Duration.zero)

    expect(find.byKey(const Key('promo-player-stack')), findsOneWidget);
    expect(find.byKey(const Key('promo-error')), findsNothing);

    // The first caption cue covers t=[0,1), so it should already be showing.
    expect(find.byKey(const Key('promo-caption-text')), findsOneWidget);

    // The score banner is always visible, from the very first frame.
    expect(find.text('救済者'), findsOneWidget);
    expect(find.text('執行者'), findsOneWidget);

    // No end card yet — the default script's endCard starts at t=12.5s and
    // start()'s Timer.periodic advances against a real Stopwatch, so a
    // widget-test pump() (fake-clock only) can't fast-forward it here.
    expect(find.byKey(const Key('promo-end-card')), findsNothing);

    // Advance past the scripted actions without throwing.
    await tester.pump(const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
  });

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
