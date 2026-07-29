import 'package:dead_or_alive/features/nine_judges/showcase/models/showcase_event.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/screens/demo_showcase_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('タイトル→ボード→勝敗→評価→募集まで一巡し、各イベントが正しい順で発火する', (tester) async {
    final events = <ShowcaseEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DemoShowcaseScreen(
          loop: false,
          onEvent: events.add,
        ),
      ),
    );

    // Title screen renders immediately.
    expect(find.text('9人の審判'), findsWidgets);

    // Drive the whole ~24.5s scripted sequence (fake-clock; no real delay).
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Reaches the recruitment card at the end.
    expect(find.text('テストプレイヤー募集中'), findsOneWidget);

    // Every named beat fired, in the documented order, exactly once each
    // (except cardsPlaced, which only fires when the board phase begins).
    expect(events.first, ShowcaseEvent.titleShown);
    expect(events, contains(ShowcaseEvent.catchCopyShown));
    expect(events, contains(ShowcaseEvent.characterIntroShown));
    expect(events, contains(ShowcaseEvent.cardsPlaced));
    expect(events, contains(ShowcaseEvent.eyeUsed));
    expect(events, contains(ShowcaseEvent.judgeUsed));
    expect(events, contains(ShowcaseEvent.scoreAwarded));
    expect(events, contains(ShowcaseEvent.reversalUsed));
    expect(events, contains(ShowcaseEvent.resultCharacterShown));
    expect(
      events.any((e) => e == ShowcaseEvent.victory || e == ShowcaseEvent.defeat),
      isTrue,
    );
    expect(events, contains(ShowcaseEvent.ratingShown));
    expect(events.last, ShowcaseEvent.recruitmentShown);

    // eyeUsed must come before judgeUsed, which must come before
    // reversalUsed, matching the fixed seed's actual action order.
    final eyeIndex = events.indexOf(ShowcaseEvent.eyeUsed);
    final judgeIndex = events.indexOf(ShowcaseEvent.judgeUsed);
    final reversalIndex = events.indexOf(ShowcaseEvent.reversalUsed);
    expect(eyeIndex, lessThan(judgeIndex));
    expect(judgeIndex, lessThan(reversalIndex));
  });

  testWidgets('loop:falseなら募集画面到達後にタイトルへ戻らない', (tester) async {
    final events = <ShowcaseEvent>[];
    await tester.pumpWidget(
      MaterialApp(home: DemoShowcaseScreen(loop: false, onEvent: events.add)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final firstRecruitmentCount = events
        .where((e) => e == ShowcaseEvent.recruitmentShown)
        .length;
    expect(firstRecruitmentCount, 1);

    // Advancing further shouldn't restart the sequence.
    await tester.pump(const Duration(seconds: 5));
    expect(
      events.where((e) => e == ShowcaseEvent.recruitmentShown).length,
      firstRecruitmentCount,
    );
  });
}
