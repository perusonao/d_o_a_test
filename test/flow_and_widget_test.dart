import 'package:dead_or_alive/app/app.dart';
import 'package:dead_or_alive/features/game/application/game_controller.dart';
import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 現在の手番プレイヤーが打てる「有効な手」を1つ探す（禁止手を避ける）。
({String cardId, int pos})? findValidMove(GameState s) {
  for (final card in s.currentPlayer.usableCards) {
    for (final h in s.humans) {
      final ok = card.type == ActionType.diagnose
          ? !s.canSeeFace(s.current, h.position)
          : !GameEngine.isNoOpBlocked(card.type, h);
      if (ok) return (cardId: card.id, pos: h.position);
    }
  }
  return null;
}

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
      final move = findValidMove(s)!;
      controller.selectActionCard(move.cardId);
      controller.selectPosition(move.pos);
      controller.confirm();
      guard++;
    }

    final s = container.read(gameControllerProvider)!;
    expect(s.phase, GamePhase.finished);
    final r = controller.result();
    expect(r, isNotNull);
    expect(r!.saviorScore + r.executionerScore, 18);
  });

  testWidgets('9人の審判の盤面を表示する', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DeadOrAliveApp()));
    expect(find.text('9人の審判'), findsOneWidget);
    expect(find.byKey(const Key('judge-slot-0')), findsOneWidget);
    expect(find.byKey(const Key('save-button')), findsOneWidget);
  });
}
