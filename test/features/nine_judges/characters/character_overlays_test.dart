import 'package:dead_or_alive/features/nine_judges/characters/result_character_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop() {}

void main() {
  testWidgets(
    'ゲーム開始ボタンでCharacterIntroOverlayが表示され、タップでスキップして盤面が操作できる',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NineJudgesGameScreen()));
      // Default mode on the title screen is already CPU対戦; force the
      // human to go first so no CPU-turn timer is scheduled while this test
      // only pumps a few explicit steps (a pending CPU delay Timer would
      // otherwise trip flutter_test's "still pending" teardown check).
      await tester.tap(find.text('自分'));
      await tester.ensureVisible(find.byKey(const Key('start-game')));
      await tester.tap(find.byKey(const Key('start-game')));
      await tester.pump();
      expect(find.byKey(const Key('character-intro-overlay')), findsOneWidget);
      // The board is already mounted underneath the overlay, not deferred.
      expect(find.byKey(const Key('nine-judges-board')), findsOneWidget);
      await tester.tap(find.byKey(const Key('character-intro-overlay')));
      // The tap defers to a post-frame callback, so one pump runs it and a
      // second reflects the resulting setState/rebuild.
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('character-intro-overlay')), findsNothing);
    },
  );

  testWidgets('2人対戦ではCharacterIntroOverlayに陣営パーソナライズ文言が出ない', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NineJudgesGameScreen()));
    await tester.tap(find.text('2人対戦'));
    await tester.ensureVisible(find.byKey(const Key('start-game')));
    await tester.tap(find.byKey(const Key('start-game')));
    await tester.pump();
    expect(find.byKey(const Key('character-intro-overlay')), findsOneWidget);
    expect(find.textContaining('あなたは'), findsNothing);
  });

  testWidgets('ResultCharacterOverlay: 勝利時は勝者の陣営とメッセージを表示しタップで完了する', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ResultCharacterOverlay(
          faction: Faction.savior,
          message: '希望は未来へ受け継がれる。',
          isVictory: true,
          onDone: () => done = true,
        ),
      ),
    );
    expect(find.byKey(const Key('result-character-overlay')), findsOneWidget);
    expect(find.textContaining('WINNER'), findsOneWidget);
    expect(find.text('希望は未来へ受け継がれる。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('result-character-overlay')));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('ResultCharacterOverlay: CPU戦敗北時は前向きなメッセージを表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResultCharacterOverlay(
          faction: Faction.executor,
          message: '次の審判で真実を証明してください。',
          isVictory: false,
          onDone: _noop,
        ),
      ),
    );
    expect(find.textContaining('WINNER'), findsNothing);
    expect(find.text('次の審判で真実を証明してください。'), findsOneWidget);
  });
}
