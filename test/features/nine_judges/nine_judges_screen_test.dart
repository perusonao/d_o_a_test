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
    expect(find.textContaining('救済者 0'), findsOneWidget);
    expect(find.byKey(const Key('action-life')), findsOneWidget);
    expect(find.byKey(const Key('action-eye')), findsOneWidget);
    expect(find.byKey(const Key('action-specialVerdict')), findsOneWidget);
    expect(find.byKey(const Key('action-death')), findsNothing);
    expect(find.textContaining('SAVE'), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(find.byKey(const Key('confirmation-reveal')), findsOneWidget);
    expect(find.textContaining('POINT'), findsOneWidget);
  });
}
