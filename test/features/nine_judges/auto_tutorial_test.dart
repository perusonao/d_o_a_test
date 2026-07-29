import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:dead_or_alive/features/nine_judges/services/external_test_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Section (this round): a brand-new device (never completed/skipped the
/// tutorial) is taken straight into it instead of the mode-select menu when
/// [NineJudgesGameScreen.autoStartTutorial] is true (real app entry point —
/// see lib/app/app.dart); every other case (already done it, or the flag
/// off, matching every existing direct-construction test) never pushes the
/// tutorial and the menu just shows immediately, unchanged.
void main() {
  Future<void> settle(WidgetTester tester) async {
    // Deliberately never pumpAndSettle(): the mode-select screen underneath
    // has continuously-repeating idle animations (hero ambient particles,
    // the start button's heartbeat pulse) that would never let it settle.
    // A handful of small explicit pumps resolves the microtask-based
    // SharedPreferences load, the Navigator.push, and its ~300ms route
    // transition (so any subsequent tap lands on the settled widget, not
    // mid-slide).
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('未経験の初回起動ではチュートリアルが自動的に開始される', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(autoStartTutorial: true),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('tutorial-message')), findsOneWidget);
  });

  testWidgets('チュートリアル完了済みの端末では自動開始しない', (tester) async {
    SharedPreferences.setMockInitialValues({
      'external_test.tutorialCompleted': true,
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(autoStartTutorial: true),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('tutorial-message')), findsNothing);
    expect(find.byKey(const Key('start-game')), findsOneWidget);
  });

  testWidgets('チュートリアルをスキップ済みの端末では自動開始しない', (tester) async {
    SharedPreferences.setMockInitialValues({
      'external_test.tutorialSkipped': true,
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(autoStartTutorial: true),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('tutorial-message')), findsNothing);
    expect(find.byKey(const Key('start-game')), findsOneWidget);
  });

  testWidgets('autoStartTutorial未指定(既定false)では自動開始せず即メニューを表示する', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: NineJudgesGameScreen()),
    );
    await settle(tester);

    expect(find.byKey(const Key('tutorial-message')), findsNothing);
    expect(find.byKey(const Key('start-game')), findsOneWidget);
  });

  testWidgets('自動開始したチュートリアルをスキップ確定するとCPU戦が実際に始まる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(autoStartTutorial: true),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('tutorial-message')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tutorial-skip-confirm')));
    await settle(tester);

    expect(find.byKey(const Key('tutorial-message')), findsNothing);
    expect(find.byKey(const Key('game-home-button')), findsOneWidget);

    final profile = await ExternalTestProfile.loadForNewGame();
    expect(profile.hasSkippedTutorial, isTrue);
  });
}
