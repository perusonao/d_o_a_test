import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';

void main() {
  testWidgets('360x640で盤面と操作をスクロールなしで表示する', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );

    expect(find.byType(Scrollable), findsNothing);
    expect(find.byKey(const Key('judge-slot-0')), findsOneWidget);
    expect(find.byKey(const Key('judge-slot-8')), findsOneWidget);
    expect(find.text('LIFE'), findsOneWidget);
    expect(find.text('DEATH'), findsOneWidget);
    expect(find.text('EYE'), findsOneWidget);
    expect(find.byKey(const Key('judge-button')), findsOneWidget);
    expect(find.byKey(const Key('own-hand')), findsOneWidget);
    expect(find.byKey(const Key('opponent-hand')), findsOneWidget);
    expect(find.textContaining('JUDGE 2'), findsNWidgets(2));
    expect(find.textContaining('EYE 1'), findsNWidgets(2));
    expect(find.textContaining('残り6手'), findsNWidgets(2));
    expect(find.textContaining('TURN 1 / 12'), findsOneWidget);
    expect(
      find.byKey(const Key('initial-knowledge-confirmation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rules-button')), findsOneWidget);
    expect(find.text('アクションを選択してください'), findsOneWidget);
    expect(find.textContaining('SAVE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ルール概要を右上の？から確認できる', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(initialSettings: NineJudgesGameSettings()),
      ),
    );
    await tester.tap(find.byKey(const Key('rules-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rules-dialog')), findsOneWidget);
    expect(find.text('死→生 / 生ならDEATHを1回防ぐ'), findsOneWidget);
    expect(find.textContaining('有限カード'), findsOneWidget);
  });

  testWidgets('対戦モードとEASY・NORMALを選択できる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NineJudgesGameScreen()));
    expect(find.text('CPU対戦'), findsOneWidget);
    expect(find.text('2人対戦'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    await tester.tap(find.text('EASY'));
    await tester.tap(find.text('救済者'));
    await tester.tap(find.text('自分'));
    await tester.tap(find.byKey(const Key('start-game')));
    await tester.pump();
    expect(find.textContaining('救済者（あなた）'), findsOneWidget);
    expect(find.textContaining('執行者（CPU）'), findsOneWidget);
  });

  testWidgets('人物カードにLIFE防護・判決済みを明示し数字を表示しない', (tester) async {
    const slot = BoardSlot(
      person: PersonCard(
        id: 'good-2',
        attribute: PersonAttribute.good,
        rank: 2,
        isAlive: true,
        isJudged: true,
        hasLifeShield: true,
      ),
      hiddenNumber: 7,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 110,
            height: 150,
            child: PersonCardWidget(
              slot: slot,
              attributeVisible: true,
              numberVisible: false,
              selected: false,
              enabled: false,
              onTap: _noop,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('number-?')), findsNothing);
    expect(find.byKey(const Key('life-shield')), findsOneWidget);
    expect(find.byKey(const Key('judged-label')), findsOneWidget);
    expect(find.text('判定済'), findsOneWidget);
    expect(find.byKey(const Key('under-review-label')), findsNothing);
  });

  testWidgets('未審議・審議中・判定済を排他的に表示する', (tester) async {
    Future<void> show(PersonCard person) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 110,
              height: 150,
              child: PersonCardWidget(
                slot: BoardSlot(person: person),
                attributeVisible: true,
                numberVisible: false,
                selected: false,
                enabled: false,
                onTap: _noop,
              ),
            ),
          ),
        ),
      );
    }

    await show(
      const PersonCard(
        id: 'good-1',
        attribute: PersonAttribute.good,
        rank: 1,
        isAlive: true,
      ),
    );
    expect(find.byKey(const Key('not-reviewed-label')), findsOneWidget);

    await show(
      const PersonCard(
        id: 'good-1',
        attribute: PersonAttribute.good,
        rank: 1,
        isAlive: true,
        isUnderReview: true,
      ),
    );
    expect(find.byKey(const Key('under-review-label')), findsOneWidget);
    expect(find.byKey(const Key('judged-label')), findsNothing);

    await show(
      const PersonCard(
        id: 'good-1',
        attribute: PersonAttribute.good,
        rank: 1,
        isAlive: true,
        isJudged: true,
        isUnderReview: false,
      ),
    );
    expect(find.byKey(const Key('judged-label')), findsOneWidget);
    expect(find.byKey(const Key('under-review-label')), findsNothing);
  });

  testWidgets('EYE対象選択後に確認情報を選べる', (tester) async {
    final controller = NineJudgesController(random: Random(2));
    addTearDown(controller.dispose);
    controller.chooseAction(ActionType.eye);
    final target = List.generate(
      9,
      (index) => index,
    ).firstWhere(controller.canTarget);
    controller.selectSlot(target);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActionPanel(controller: controller)),
      ),
    );
    expect(find.text('何を確認しますか？'), findsOneWidget);
    expect(find.text('属性を見る'), findsOneWidget);
  });

  testWidgets('CPU先攻ではCPUが思考中と表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: NineJudgesGameSettings(
            mode: GameMode.cpu,
            factionSelection: FactionSelection.savior,
            firstPlayerSelection: FirstPlayerSelection.cpu,
          ),
        ),
      ),
    );
    expect(find.text('CPUが思考中…'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('cpu-action-message')), findsOneWidget);
    expect(find.byKey(const Key('cpu-target-highlight')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cpu-action-message')));
    await tester.pump();
    expect(find.byKey(const Key('cpu-action-message')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });
}

void _noop() {}
