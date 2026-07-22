import 'package:dead_or_alive/features/game/application/game_controller.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// コントローラを直接駆動し、1試合が最後まで進行できることを確認する。
void main() {
  test('救済者で開始し、最後まで進行して finished・集計できる', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);

    // 救済者=弱い役=先手なので、プレイヤーから始まる。
    await controller.startGame(Role.savior);

    var guard = 0;
    while (guard < 100) {
      final s = container.read(gameControllerProvider)!;
      if (s.phase == GamePhase.finished) break;
      if (s.phase == GamePhase.playerTurn && !s.isBusy) {
        final card = s.player.usableCards.first;
        // 封印されていない対象を選ぶ。
        final target = s.persons.firstWhere((p) => !p.sealed);
        controller.selectLifeDeathCard(card.id);
        controller.selectPosition(target.position);
        await controller.confirm();
      }
      guard++;
    }

    final s = container.read(gameControllerProvider)!;
    expect(s.phase, GamePhase.finished);
    expect(s.player.hasUsableCards, isFalse);
    expect(s.cpu.hasUsableCards, isFalse);

    final result = controller.result();
    expect(result, isNotNull);
    // 得点は 0 以上、勝者は救済者/執行者/引き分けのいずれか。
    expect(result!.saviorScore, greaterThanOrEqualTo(0));
    expect(result.executionerScore, greaterThanOrEqualTo(0));
  });
}
