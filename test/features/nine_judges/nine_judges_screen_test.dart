import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
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
    expect(find.text('現在の生死で最終確定'), findsOneWidget);
  });

  testWidgets('対戦モードとEASY・NORMALを選択できる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NineJudgesGameScreen()));
    expect(find.text('CPU対戦'), findsOneWidget);
    expect(find.text('2人対戦'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    await tester.tap(find.text('EASY'));
    await tester.tap(find.byKey(const Key('start-game')));
    await tester.pump();
    expect(find.textContaining('救済者（あなた）'), findsOneWidget);
    expect(find.textContaining('執行者（CPU）'), findsOneWidget);
  });

  testWidgets('人物カードに未知数字・LIFE防護・判決済みを明示する', (tester) async {
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
    expect(find.textContaining('?'), findsOneWidget);
    expect(find.byKey(const Key('life-shield')), findsOneWidget);
    expect(find.byKey(const Key('judged-label')), findsOneWidget);
  });
}

void _noop() {}
