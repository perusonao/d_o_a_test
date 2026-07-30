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

    // The first caption cue covers t=[0,2), so it should already be showing.
    expect(find.byKey(const Key('promo-caption-text')), findsOneWidget);

    // Advance past the scripted actions (t=7s) without throwing.
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
