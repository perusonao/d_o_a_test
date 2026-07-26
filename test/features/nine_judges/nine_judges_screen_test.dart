import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('救済者画面は3×3、得点、ボーナス、LIFE/EYE/審判を表示', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: NineJudgesGameSettings(
            mode: GameMode.hotseat,
            firstPlayer: Faction.savior,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('nine-judges-board')), findsOneWidget);
    expect(find.byKey(const Key('current-bonus')), findsOneWidget);
    expect(find.byKey(const Key('bonus-history')), findsOneWidget);
    expect(find.byKey(const Key('faction-savior')), findsOneWidget);
    expect(find.text('0 POINT'), findsNWidgets(2));
    expect(find.byKey(const Key('action-life')), findsOneWidget);
    expect(find.byKey(const Key('action-eye')), findsOneWidget);
    expect(find.byKey(const Key('action-specialVerdict')), findsOneWidget);
    expect(find.text('JUDGE'), findsOneWidget);
    expect(find.text('TURN'), findsNothing);
    expect(find.textContaining('TURN 1'), findsOneWidget);
    expect(find.byKey(const Key('coordinate-A1')), findsOneWidget);
    expect(find.byKey(const Key('coordinate-C3')), findsOneWidget);
    expect(find.byKey(const Key('action-death')), findsOneWidget);
    expect(find.textContaining('SAVE'), findsNothing);
    expect(find.byKey(const Key('debug-button')), findsNothing);
    expect(find.text('人物とアクションを選択してください'), findsNothing);
    expect(find.byKey(const Key('verdict-status-savior')), findsOneWidget);
    expect(find.byKey(const Key('verdict-status-executor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ボーナス履歴は現在・使用済み・残りを表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    await tester.tap(find.byKey(const Key('bonus-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bonus-history-title')), findsOneWidget);
    expect(find.byKey(const Key('bonus-history-current')), findsOneWidget);
    expect(find.byKey(const Key('remaining-bonuses')), findsOneWidget);
    expect(find.text('使用済み'), findsOneWidget);
    expect(find.text('残り（順序非公開）'), findsOneWidget);
    expect(find.textContaining(RegExp(r'[1-9] / [1-9]')), findsNothing);
  });

  testWidgets('CPU対戦であなた・CPU・現在手番を明示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: NineJudgesGameSettings(
            mode: GameMode.cpu,
            cpuFaction: Faction.executor,
            firstPlayer: Faction.savior,
          ),
        ),
      ),
    );
    expect(find.text('あなた'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.textContaining('あなた（救済者）の手番'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recent-history')));
    await tester.pumpAndSettle();
    expect(find.text('直近の履歴'), findsOneWidget);
  });

  testWidgets('人物状態は審議中・生・確定を別ラベルで表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    expect(find.byKey(const Key('verdict-deliberating')), findsNWidgets(9));
    await tester.tap(find.byKey(const Key('action-life')));
    await tester.pump();
    await tester.tap(find.byType(InkWell).last);
  });

  testWidgets('確定時に属性・ボーナス・得点者を公開する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    await tester.tap(find.byKey(const Key('action-specialVerdict')));
    await tester.pump();
    await tester.tap(find.byType(PersonCardWidget).first);
    await tester.pump();
    expect(find.byKey(const Key('judge-confirm-dialog')), findsOneWidget);
    expect(find.text('JUDGEを使用しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-judge')));
    await tester.pump();
    expect(find.byKey(const Key('confirmation-reveal')), findsOneWidget);
    expect(find.byKey(const Key('nine-judges-board')), findsOneWidget);
    expect(find.text('JUDGEMENT'), findsOneWidget);
    expect(find.textContaining('POINT'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirmation-reveal')));
    await tester.pump();
    expect(find.byKey(const Key('confirmation-reveal')), findsNothing);
  });

  testWidgets('JUDGE確認をキャンセルすると人物を確定しない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    await tester.tap(find.byKey(const Key('action-specialVerdict')));
    await tester.pump();
    await tester.tap(find.byType(PersonCardWidget).first);
    await tester.pump();
    expect(find.byKey(const Key('judge-confirm-dialog')), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmation-reveal')), findsNothing);
    expect(find.byKey(const Key('verdict-deliberating')), findsNWidgets(9));
  });

  testWidgets('EYE実施者をYOU/CPUで区別し属性は非表示にできる', (tester) async {
    const person = PersonCard(id: 'test', attribute: PersonAttribute.evil);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 120,
            child: PersonCardWidget(
              person: person,
              attributeVisible: false,
              viewerEyeKnown: false,
              opponentEyeKnown: true,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('正体不明'), findsOneWidget);
    expect(find.text('悪人'), findsNothing);
  });

  testWidgets('生死チップを順番通り最大3個、確定後も表示する', (tester) async {
    const person = PersonCard(
      id: 'history',
      attribute: PersonAttribute.good,
      verdictState: VerdictState.aliveConfirmed,
      verdictActionCount: 3,
      verdictHistory: [
        VerdictActionType.life,
        VerdictActionType.death,
        VerdictActionType.life,
      ],
      awardedBonus: 9,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 140,
            child: PersonCardWidget(
              person: person,
              attributeVisible: true,
              viewerEyeKnown: false,
              opponentEyeKnown: false,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('生'), findsNWidgets(2));
    expect(find.text('死'), findsOneWidget);
    expect(find.byKey(const Key('confirmed-label')), findsOneWidget);
    expect(
      find.byKey(const Key('card-surface-aliveConfirmed')),
      findsOneWidget,
    );
  });

  testWidgets('DEAD確定カードは専用状態面を表示する', (tester) async {
    const person = PersonCard(
      id: 'dead',
      attribute: PersonAttribute.evil,
      verdictState: VerdictState.deadConfirmed,
      awardedBonus: 4,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 140,
            child: PersonCardWidget(
              person: person,
              attributeVisible: true,
              viewerEyeKnown: false,
              opponentEyeKnown: false,
              viewerLabel: 'YOU',
              opponentLabel: 'CPU',
              selected: false,
              cpuHighlighted: false,
              enabled: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('card-surface-deadConfirmed')), findsOneWidget);
    expect(find.textContaining('DEAD'), findsWidgets);
  });

  testWidgets('善人・悪人・中立は形の異なるアイコンで表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final attribute in PersonAttribute.values)
                Expanded(
                  child: PersonCardWidget(
                    person: PersonCard(
                      id: attribute.name,
                      attribute: attribute,
                    ),
                    attributeVisible: true,
                    viewerEyeKnown: false,
                    opponentEyeKnown: false,
                    viewerLabel: 'YOU',
                    opponentLabel: 'CPU',
                    selected: false,
                    cpuHighlighted: false,
                    enabled: false,
                    onTap: () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('attribute-icon-good')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-evil')), findsOneWidget);
    expect(find.byKey(const Key('attribute-icon-neutral')), findsOneWidget);
  });

  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}でoverflowしない', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
        ),
      );
      expect(find.byKey(const Key('nine-judges-board')), findsOneWidget);
      expect(find.byKey(const Key('action-life')), findsOneWidget);
      expect(find.byKey(const Key('action-eye')), findsOneWidget);
      expect(find.byKey(const Key('action-specialVerdict')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
