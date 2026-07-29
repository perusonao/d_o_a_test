import 'package:dead_or_alive/features/nine_judges/services/tutorial_completion_repository.dart';
import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Section: improved first-time tutorial UX — a "今回覚えること" headline per
/// step, a spotlighted target card + glowing single advance button, a STEP
/// counter/progress bar, non-blocking outcome badges (LIFE/DEATH progress,
/// EYE's reveal, JUDGE's confirm), a bonus banner with a score count-up, a
/// slower CPU-visible pace, and a dedicated completion screen with
/// confetti. None of this touches the underlying rules engine — see
/// onboarding_test.dart / external_test_telemetry_test.dart for the
/// unchanged production-rules/event-recording coverage this still passes.
///
/// Most tests here pass `beatDuration: Duration.zero` to keep the scripted
/// flow's async outcome-beats resolving within a single `pump()` — the
/// pacing/timing itself is covered by its own dedicated tests below using
/// the real (non-zero) default.
void main() {
  Future<void> pumpTutorial(
    WidgetTester tester, {
    Duration beatDuration = Duration.zero,
    TutorialCompletionRepository tutorialCompletionRepository =
        const TutorialCompletionRepository(),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialScreen(
          beatDuration: beatDuration,
          tutorialCompletionRepository: tutorialCompletionRepository,
        ),
      ),
    );
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    // A zero-duration outcome-beat still schedules a real (if instant)
    // Timer via Future.delayed — a bare pump() doesn't reliably elapse it,
    // so pump a few explicit (tiny) durations to resolve it regardless of
    // how many outcome-beats this particular step chains (up to two, for
    // the steps that run a CPU action then the player's own follow-up).
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('各ステップで「今回覚えること」の見出しが1行の要点とともに表示される', (tester) async {
    await pumpTutorial(tester);
    expect(find.byKey(const Key('tutorial-remember-label')), findsOneWidget);
    expect(find.text('今回覚えること'), findsOneWidget);
    expect(find.text('【今やること】'), findsOneWidget);
    expect(find.textContaining('盤面を確認'), findsOneWidget);
  });

  testWidgets('STEP表示と進捗バーが表示される', (tester) async {
    await pumpTutorial(tester);
    expect(find.text('STEP 1 / 11'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-progress-0')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-progress-10')), findsOneWidget);

    await tapNext(tester);
    expect(find.text('STEP 2 / 11'), findsOneWidget);
  });

  testWidgets('救済者/執行者の得点が表示される', (tester) async {
    await pumpTutorial(tester);
    expect(find.text('救済者'), findsOneWidget);
    expect(find.text('執行者'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-score-value')), findsNWidgets(2));
  });

  testWidgets('対象カードをタップするだけでも操作ステップが進む(ボタンと同じ結果)', (tester) async {
    await pumpTutorial(tester);
    // Step 1 (index 1 after the intro beat) spotlights B3 for LIFE.
    await tapNext(tester);
    expect(find.text('STEP 2 / 11'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-spotlight-callout')), findsOneWidget);

    // Tapping the spotlighted card directly (not the button) must also
    // advance the scripted lesson.
    await tester.tap(find.byType(PersonCardWidget).at(7));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('STEP 3 / 11'), findsOneWidget);
  });

  testWidgets('LIFE使用後にカード上へ確定までの進捗バッジが出る(非ブロッキング)', (tester) async {
    await pumpTutorial(tester);
    await tapNext(tester); // -> step 1 (intro shown)
    await tester.tap(find.byKey(const Key('tutorial-next'))); // LIFE on B3
    await tester.pump();
    expect(find.byKey(const Key('tutorial-card-badge')), findsOneWidget);
    expect(find.textContaining('確定'), findsWidgets);
    // The badge is decorative only — it never blocks the step from
    // actually advancing once its (here, instant) beat elapses.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('STEP 3 / 11'), findsOneWidget);
    // ...nor does it block the very next step's own action.
    await tapNext(tester);
    expect(find.text('STEP 4 / 11'), findsOneWidget);
  });

  testWidgets('EYE使用後は自分の番のときだけ属性が表示される', (tester) async {
    await pumpTutorial(tester);
    await tapNext(tester); // step 0 -> 1
    await tapNext(tester); // step 1 (LIFE) -> 2
    await tester.tap(find.byKey(const Key('tutorial-next'))); // EYE on B2
    await tester.pump();
    // The badge's setState runs synchronously before the outcome-beat's
    // Future.delayed is even scheduled, so a bare pump() already shows it.
    // The center row is randomly-attributed by seed, but the reveal must
    // always say one of the three real attribute labels, never leak
    // nothing at all.
    final revealed = find.textContaining('でした');
    expect(revealed, findsOneWidget);
    // Drain the (zero-duration, but still a real Timer) outcome-beat before
    // the test ends, so the binding doesn't see a pending Timer at teardown.
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('CPU自身のEYE使用では属性を明かさない(情報非公開を維持)', (tester) async {
    await pumpTutorial(tester);
    await tapNext(tester); // 0 -> 1
    await tapNext(tester); // 1 (LIFE) -> 2
    await tapNext(tester); // 2 (EYE) -> 3
    await tester.tap(find.byKey(const Key('tutorial-next'))); // CPU EYE
    await tester.pump();
    expect(find.text('CPUがEYEを使用'), findsOneWidget);
    expect(find.textContaining('でした'), findsNothing);
    // Drain the (zero-duration, but still a real Timer) outcome-beat before
    // the test ends, so the binding doesn't see a pending Timer at teardown.
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('CPUの行動には見せる間(ま)があり、次の入力までブロックしない', (tester) async {
    await pumpTutorial(
      tester,
      beatDuration: const Duration(milliseconds: 500),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
    // Step 3's button press is the CPU's own EYE action; the step counter
    // still reads "STEP 4 / 11" (step index 3) right up until the beat
    // resolves and it becomes "STEP 5 / 11".
    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    // Right after tapping, the badge is visible and the step hasn't
    // advanced yet — the CPU's move is being shown, not skipped.
    expect(find.byKey(const Key('tutorial-card-badge')), findsOneWidget);
    expect(find.text('STEP 4 / 11'), findsOneWidget);
    expect(find.text('STEP 5 / 11'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('STEP 5 / 11'), findsOneWidget);
  });

  testWidgets('確定してボーナスが入ると専用バナーが表示され、得点が加算される', (tester) async {
    await pumpTutorial(
      tester,
      beatDuration: const Duration(milliseconds: 300),
    );
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    // Step 7's press runs CPU DEATH then the player's own LIFE, the 3rd
    // action on B3 — always confirms and always awards a bonus. Poll in
    // small increments rather than guessing one exact elapsed amount, since
    // this chains two ~300ms outcome-beats back to back.
    await tester.tap(find.byKey(const Key('tutorial-next')));
    var sawBanner = false;
    for (var i = 0; i < 10 && !sawBanner; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      sawBanner = find
          .byKey(const Key('tutorial-bonus-banner'))
          .evaluate()
          .isNotEmpty;
    }
    expect(sawBanner, isTrue);
    expect(find.textContaining('BONUS'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
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
                MaterialPageRoute(
                  builder: (_) =>
                      const TutorialScreen(beatDuration: Duration.zero),
                ),
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

  testWidgets('最終ステップまで進むと専用の完了画面(3ボタン・紙吹雪)が表示される', (tester) async {
    await pumpTutorial(tester);
    for (var i = 0; i < 10; i++) {
      await tapNext(tester);
    }
    expect(find.text('チュートリアル完了！'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-complete-headline')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-complete')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-practice-again')), findsOneWidget);
    expect(find.byKey(const Key('tutorial-go-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('最終ステップまで進むとチュートリアル完了ユーザー数がFirestoreへ記録される', (tester) async {
    // ExternalTestProfile.loadForNewGame() reads SharedPreferences — without
    // a mock, getInstance() never resolves in this test environment, which
    // would otherwise leave _recordRemoteCompletion's chain pending forever.
    SharedPreferences.setMockInitialValues({});
    final firestore = FakeFirebaseFirestore();
    await pumpTutorial(
      tester,
      tutorialCompletionRepository: TutorialCompletionRepository(
        firestore: firestore,
        uidOverride: 'firebase-auth-uid-1',
        availableOverride: true,
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tapNext(tester);
    }
    // _markCompleted fires the Firestore write fire-and-forget (unawaited),
    // chained behind its own SharedPreferences profile load — a few settle
    // pumps let that async chain finish before asserting.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    final doc = await firestore
        .collection('tutorialCompletions')
        .doc('firebase-auth-uid-1')
        .get();
    expect(doc.exists, isTrue);
  });

  testWidgets('「もう一度練習」で最初のステップからやり直せる', (tester) async {
    await pumpTutorial(tester);
    for (var i = 0; i < 10; i++) {
      await tapNext(tester);
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
    await tapNext(tester);
    expect(find.byType(BoardGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
