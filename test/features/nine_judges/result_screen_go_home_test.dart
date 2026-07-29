import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Result screens previously had no way back to the title/mode-select
/// screen at all (only "新しいゲーム", which restarts with the same
/// settings in place) — see result_screen.dart's new `onGoHome` param.
void main() {
  NineJudgesController buildController() {
    final controller = NineJudgesController(
      seed: 1,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        skipCpuDelays: true,
      ),
    );
    return controller;
  }

  testWidgets('onGoHomeを渡すと「ホームへ戻る」ボタンが表示され、タップで呼ばれる', (tester) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(controller: controller, onGoHome: () => tapped = true),
      ),
    );

    expect(find.byKey(const Key('result-go-home')), findsOneWidget);
    await tester.tap(find.byKey(const Key('result-go-home')));
    expect(tapped, isTrue);
  });

  testWidgets('onGoHomeを渡さない場合は「ホームへ戻る」ボタンを表示しない(既定の後方互換)', (
    tester,
  ) async {
    final controller = buildController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: ResultScreen(controller: controller)));

    expect(find.byKey(const Key('result-go-home')), findsNothing);
  });
}
