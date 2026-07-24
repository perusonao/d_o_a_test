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

    await tester.pumpWidget(const MaterialApp(home: NineJudgesGameScreen()));

    expect(find.byType(Scrollable), findsNothing);
    expect(find.byKey(const Key('judge-slot-0')), findsOneWidget);
    expect(find.byKey(const Key('judge-slot-8')), findsOneWidget);
    expect(find.text('LIFE'), findsOneWidget);
    expect(find.text('DEATH'), findsOneWidget);
    expect(find.text('EYE'), findsOneWidget);
    expect(find.byKey(const Key('judge-button')), findsOneWidget);
    expect(find.textContaining('SAVE'), findsNothing);
    expect(tester.takeException(), isNull);
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
