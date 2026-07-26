import 'package:dead_or_alive/features/nine_judges/rules/rules_guide_screen.dart';
import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rules guide provides seven concise pages', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RulesGuideScreen()));

    expect(find.byKey(const Key('rules-pages')), findsOneWidget);
    expect(find.text('あなたの役割'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const Key('rules-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('審判ボーナス'), findsOneWidget);
  });

  testWidgets('fixed tutorial executes the production rules to completion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));
    expect(find.byKey(const Key('tutorial-message')), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
    }

    expect(find.byKey(const Key('tutorial-complete')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
