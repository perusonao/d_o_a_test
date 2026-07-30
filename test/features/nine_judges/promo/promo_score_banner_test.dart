import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_score_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows both faction scores and updates live as they change', (
    tester,
  ) async {
    final controller = NineJudgesController(
      seed: 5,
      settings: const NineJudgesGameSettings(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: PromoScoreBanner(controller: controller)),
    );

    expect(find.text('0'), findsNWidgets(2));

    controller.scores[Faction.savior] = 3;
    controller.scores[Faction.executor] = 1;
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
