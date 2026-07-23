import 'package:dead_or_alive/app/app.dart';
import 'package:dead_or_alive/app/router.dart';
import 'package:dead_or_alive/features/game/application/game_controller.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('確認→対戦→終了まで通しで進み、得点合計は18', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);

    controller.startGame(Faction.savior);
    controller.confirmPeek(); // peekA -> peekB
    controller.confirmPeek(); // peekB -> playing
    expect(container.read(gameControllerProvider)!.phase, GamePhase.playing);

    var guard = 0;
    while (guard < 60) {
      final s = container.read(gameControllerProvider)!;
      if (s.phase == GamePhase.finished) break;
      final card = s.currentPlayer.usableCards.first;
      controller.selectActionCard(card.id);
      controller.selectPosition(0); // 位置0に使い続ける
      controller.confirm();
      guard++;
    }

    final s = container.read(gameControllerProvider)!;
    expect(s.phase, GamePhase.finished);
    final r = controller.result();
    expect(r, isNotNull);
    expect(r!.saviorScore + r.executionerScore, 18);
  });

  testWidgets('タイトル→開始で確認フェーズに入る', (tester) async {
    appRouter.go(AppRoutes.title);
    await tester.pumpWidget(const ProviderScope(child: DeadOrAliveApp()));
    await tester.pumpAndSettle();

    expect(find.text('DEAD OR ALIVE'), findsOneWidget);
    await tester.tap(find.text('Aが救済者で開始'));
    await tester.pumpAndSettle();

    // 確認フェーズのボタンが出る。
    expect(find.text('確認した → プレイヤーBへ'), findsOneWidget);
  });
}
