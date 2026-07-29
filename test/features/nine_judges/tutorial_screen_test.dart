import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Section: improved first-time tutorial UX (shorter 今やること/覚えること
/// copy, a spotlighted target card + glowing single advance button, a STEP
/// counter/progress bar, a non-blocking success beat, and a dedicated
/// completion screen). None of this touches the underlying rules engine —
/// see onboarding_test.dart / external_test_telemetry_test.dart for the
/// unchanged production-rules/event-recording coverage this still passes.
void main() {
  Future<void> pumpTutorial(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));
  }

  testWidgets('各ステップは【今やること】【覚えること】の2段構成で表示される', (tester) async {
    await pumpTutorial(tester);
    expect(find.text('【今やること】'), findsOneWidget);
    expect(find.text('【覚えること】'), findsOneWidget);
    expect(find.textContaining('盤面を確認'), findsOneWidget);
  });

  testWidgets('STEP表示と進捗バーが表示される', (tester) async {
    await pumpTutorial(tester);
    expect(find.text('STEP 1 / 11'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-progress-0')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-progress-10')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(find.text('STEP 2 / 11'), findsOneWidget);
  });

  testWidgets('対象カードをタップするだけでも操作ステップが進む(ボタンと同じ結果)', (tester) async {
    await pumpTutorial(tester);
    // Step 1 (index 1 after the intro beat) spotlights B3 for LIFE.
    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(find.text('STEP 2 / 11'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-spotlight-callout')), findsOneWidget);

    // Tapping the spotlighted card directly (not the button) must also
    // advance the scripted lesson.
    await tester.tap(find.byType(PersonCardWidget).at(7));
    await tester.pump();
    expect(find.text('STEP 3 / 11'), findsOneWidget);
  });

  testWidgets('実操作の直後に非ブロッキングの成功フィードバックが出て、すぐ次の入力ができる', (tester) async {
    await pumpTutorial(tester);
    await tester.tap(find.byKey(const Key('tutorial-next'))); // -> step 1
    await tester.pump();
    await tester.tap(find.byKey(const Key('tutorial-next'))); // LIFE on B3
    await tester.pump();
    expect(find.byKey(const Key('tutorial-success-badge')), findsOneWidget);
    // The badge is decorative only — the next tap must still work
    // immediately, without waiting for its animation to finish.
    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(find.text('STEP 4 / 11'), findsOneWidget);
  });

  testWidgets('スキップを押すと確認ダイアログが出て、キャンセルすればチュートリアルは続く', (tester) async {
    await pumpTutorial(tester);
    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pump();
    expect(find.text('CPU戦を始めますか？'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    await tester.pump();
    expect(find.text('STEP 1 / 11'), findsOneWidget);
  });

  testWidgets('スキップを確定するとtrueでpopされる', (tester) async {
    bool? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const TutorialScreen()),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tutorial-skip-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(popped, isTrue);
  });

  testWidgets('最終ステップまで進むと専用の完了画面(3ボタン)が表示される', (tester) async {
    await pumpTutorial(tester);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
    }
    expect(find.text('チュートリアル完了！'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-complete')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-practice-again')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-go-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「もう一度練習」で最初のステップからやり直せる', (tester) async {
    await pumpTutorial(tester);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('tutorial-practice-again')));
    await tester.pump();
    expect(find.text('STEP 1 / 11'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-message')), findsOneWidget);
  });

  testWidgets('完了後もBoardGridはハイライトなしで正常表示される(ResultScreen相当の既定挙動)', (
    tester,
  ) async {
    await pumpTutorial(tester);
    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(find.byType(BoardGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
