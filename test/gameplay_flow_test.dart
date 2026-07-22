import 'package:dead_or_alive/features/game/application/game_controller.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// コントローラを直接駆動し、1試合が最後まで進行できることを確認する。
void main() {
  test('プレイヤーとCPUが交互に行動し、最後まで進行して finished になる', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.startGame(Faction.good);

    var guard = 0;
    while (guard < 200) {
      final state = container.read(gameControllerProvider)!;
      if (state.phase == GamePhase.finished) break;

      if (state.phase == GamePhase.playerTurn && !state.isBusy) {
        // 未使用カードとCPUの人カードを1つずつ選んで決定。
        final card = state.player.usableCards.first;
        final target = state.cpu.persons.first;
        controller.selectLifeDeathCard(card.id);
        controller.selectPerson(target.id);
        await controller.confirm(); // 内部で CPU ターンまで回る。
      }
      guard++;
    }

    final finalState = container.read(gameControllerProvider)!;
    expect(finalState.phase, GamePhase.finished);
    // 両者の手札が尽きている。
    expect(finalState.player.hasUsableCards, isFalse);
    expect(finalState.cpu.hasUsableCards, isFalse);

    // 結果が集計できる。
    final result = controller.result();
    expect(result, isNotNull);
    expect(result!.usedCardsTotal, greaterThan(0));
  });
}
