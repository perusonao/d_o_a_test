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

  testWidgets('チュートリアルを最後まで終えてCPU戦を選ぶと、実際にCPU戦が開始される', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    NineJudgesGameSettings? started;
    await tester.pumpWidget(
      MaterialApp(
        home: NineJudgesModeSelectScreen(onStart: (s) => started = s),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('open-tutorial')));
    await tester.tap(find.byKey(const Key('open-tutorial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
    }
    expect(find.byKey(const Key('tutorial-complete')), findsOneWidget);
    // Previously this pop result was silently discarded
    // (Navigator.push<void>), so finishing the tutorial never actually
    // started a match.
    await tester.tap(find.byKey(const Key('tutorial-complete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(started, isNotNull);
    expect(started!.mode, GameMode.cpu);
    expect(started!.factionSelection, FactionSelection.savior);
    expect(started!.firstPlayerSelection, FirstPlayerSelection.human);
  });

  testWidgets('チュートリアルで「ホームへ戻る」を選んだ場合はCPU戦を開始しない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    NineJudgesGameSettings? started;
    await tester.pumpWidget(
      MaterialApp(
        home: NineJudgesModeSelectScreen(onStart: (s) => started = s),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('open-tutorial')));
    await tester.tap(find.byKey(const Key('open-tutorial')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('tutorial-go-home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(started, isNull);
  });
}
