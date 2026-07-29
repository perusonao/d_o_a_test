import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ゲーム開始/オンライン対戦ボタンは鼓動/グロー演出があってもタップが機能する', (tester) async {
    NineJudgesGameSettings? started;
    await tester.pumpWidget(
      MaterialApp(
        home: NineJudgesModeSelectScreen(onStart: (s) => started = s),
      ),
    );
    // Let the idle pulse animation run a bit before tapping, to prove the
    // continuous animation never blocks the tap itself.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('start-game')));
    await tester.tap(find.byKey(const Key('start-game')));
    await tester.pump();
    expect(started, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('オンライン対戦ボタンにはβバッジが表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: NineJudgesModeSelectScreen(onStart: (_) {})),
    );
    expect(find.text('β'), findsOneWidget);
  });
}
