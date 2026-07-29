import 'package:dead_or_alive/features/nine_judges/characters/result_character_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/characters/special_verdict_overlay.dart';
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

  testWidgets('CPUが先手のとき、演出が表示されている間は初手を行わず、演出終了後に開始する', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NineJudgesGameScreen()));
    await tester.tap(find.text('CPU')); // 先攻セレクタでCPUを選ぶ
    await tester.ensureVisible(find.byKey(const Key('start-game')));
    await tester.tap(find.byKey(const Key('start-game')));
    await tester.pump();
    expect(find.byKey(const Key('character-intro-overlay')), findsOneWidget);

    // 演出表示中は、CPUの通常の着手待ち時間(550ms)を優に超えて待っても
    // 初手はまだ処理されない — 演出とCPUの初手が競合しないことの確認。
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('cpu-action-message')), findsNothing);

    // 演出をスキップすると、そこから初めてCPUの初手が処理される。
    await tester.tap(find.byKey(const Key('character-intro-overlay')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('character-intro-overlay')), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const Key('cpu-action-message')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
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

  testWidgets('ResultCharacterOverlay: スコアを渡すと勝敗→メッセージの下にスコアが並ぶ', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResultCharacterOverlay(
          faction: Faction.savior,
          message: '希望は未来へ受け継がれる。',
          isVictory: true,
          saviorScore: 12,
          executorScore: 6,
          onDone: _noop,
        ),
      ),
    );
    expect(find.textContaining('救済者 12'), findsOneWidget);
    expect(find.textContaining('執行者 6'), findsOneWidget);
  });

  testWidgets('ResultCharacterOverlay: スコア未指定なら何も表示しない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResultCharacterOverlay(
          faction: Faction.savior,
          message: '希望は未来へ受け継がれる。',
          isVictory: true,
          onDone: _noop,
        ),
      ),
    );
    // "WINNER 救済者" itself legitimately contains 救済者 — the score line's
    // own "―" separator is the part that must be absent when no score was
    // supplied.
    expect(find.textContaining('―'), findsNothing);
  });

  testWidgets('SpecialVerdictOverlay: 執行者は救済者より暗転が強い', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SpecialVerdictOverlay(
          actor: Faction.savior,
          instant: true,
          onDone: _noop,
        ),
      ),
    );
    await tester.pump();
    final saviorColor = tester
        .widget<ColoredBox>(find.byKey(const Key('special-verdict-darken')))
        .color;

    await tester.pumpWidget(
      MaterialApp(
        home: SpecialVerdictOverlay(
          actor: Faction.executor,
          instant: true,
          onDone: _noop,
        ),
      ),
    );
    await tester.pump();
    final executorColor = tester
        .widget<ColoredBox>(find.byKey(const Key('special-verdict-darken')))
        .color;

    expect(executorColor.a, greaterThan(saviorColor.a));
  });
}
