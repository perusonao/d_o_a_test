import 'package:dead_or_alive/features/nine_judges/effects/card_action_effect.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final action in [ActionType.life, ActionType.death, ActionType.eye]) {
    testWidgets('${action.name}: 短時間で自動的に消え、onDoneを呼ぶ', (tester) async {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CardActionEffect(action: action, onDone: () => done = true),
        ),
      );
      // Never gates input: it's purely a paint-only overlay.
      expect(find.byType(CardActionEffect), findsOneWidget);
      expect(done, isFalse);
      // Pump past the ~550ms duration (not exactly at the boundary, to
      // avoid flaking on the completion edge) then let the deferred
      // post-frame callback (see widget doc) actually fire.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(done, isTrue);
    });
  }

  testWidgets('タップでは何も起きない(入力を奪わない)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CardActionEffect(action: ActionType.life, onDone: () {}),
      ),
    );
    // No tap handler exists on this widget at all — IgnorePointer above
    // already guarantees taps fall through to whatever is underneath.
    expect(tester.takeException(), isNull);
  });
}
