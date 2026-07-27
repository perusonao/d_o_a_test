import 'dart:math';

import 'package:dead_or_alive/features/game/application/cpu_strategy.dart';
import 'package:dead_or_alive/features/game/application/game_controller.dart';
import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CPU', () {
    test('CPU対戦では A の確認後すぐ playing（B の確認は省略）', () {
      final engine = GameEngine(random: Random(1));
      var s = engine.setup(Faction.savior, vsCpu: true);
      expect(s.playerB.isCpu, isTrue);
      s = engine.confirmPeek(s); // peekA -> playing
      expect(s.phase, GamePhase.playing);
      expect(s.current, PlayerId.a);
    });

    test('CPUは常に自分の未使用カードと有効な位置を返す', () {
      for (var seed = 0; seed < 30; seed++) {
        final engine = GameEngine(random: Random(seed));
        final cpu = CpuStrategy(random: Random(seed));
        var s = engine.setup(Faction.executioner, vsCpu: true);
        s = engine.confirmPeek(s);
        // B(CPU) の手番になるよう A の1手を適当に進める。
        final aCard = s.currentPlayer.usableCards.first;
        s = engine.applyAction(
          s,
          GameAction(
            player: s.current,
            actionCardId: aCard.id,
            targetPosition: 0,
          ),
        );
        expect(s.current, PlayerId.b);
        final d = cpu.decide(s, PlayerId.b);
        expect(d, isNotNull);
        expect(
          s.playerB.hand.any((c) => c.id == d!.actionCardId && !c.used),
          isTrue,
        );
        expect(d!.targetPosition, inInclusiveRange(0, 8));
      }
    });

    test('対CPUを通しでプレイし finished・得点合計18', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      controller.startGame(Faction.savior, vsCpu: true);
      controller.confirmPeek();

      var guard = 0;
      while (guard < 40) {
        final s = container.read(gameControllerProvider)!;
        if (s.phase == GamePhase.finished) break;
        if (!s.isBusy && !s.currentPlayer.isCpu) {
          // 禁止手を避けて有効な手を選ぶ。
          String? cardId;
          int? pos;
          outer:
          for (final card in s.currentPlayer.usableCards) {
            for (final hu in s.humans) {
              final ok = card.type == ActionType.diagnose
                  ? !s.canSeeFace(s.current, hu.position)
                  : !GameEngine.isNoOpBlocked(card.type, hu);
              if (ok) {
                cardId = card.id;
                pos = hu.position;
                break outer;
              }
            }
          }
          controller.selectActionCard(cardId!);
          controller.selectPosition(pos!);
          await controller.confirm(); // 内部で CPU の手番も回る
        }
        guard++;
      }
      final s = container.read(gameControllerProvider)!;
      expect(s.phase, GamePhase.finished);
      final r = controller.result();
      expect(r!.saviorScore + r.executionerScore, 18);
    });
  });

  group('のぞき見（自分の既知カードをタップで表確認）', () {
    test('アクション未選択なら既知カードのタップで peek がトグルする', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(Faction.savior, vsCpu: true);
      controller.confirmPeek();

      // プレイヤーA の既知は下段（位置6,7,8）。
      controller.selectPosition(6);
      expect(
        container.read(gameControllerProvider)!.peeked.contains(6),
        isTrue,
      );
      controller.selectPosition(6);
      expect(
        container.read(gameControllerProvider)!.peeked.contains(6),
        isFalse,
      );
    });

    test('アクション選択中はタップが対象選択になる（peek しない）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(Faction.savior, vsCpu: true);
      controller.confirmPeek();

      final card = container
          .read(gameControllerProvider)!
          .currentPlayer
          .usableCards
          .first;
      controller.selectActionCard(card.id);
      controller.selectPosition(0);
      final s = container.read(gameControllerProvider)!;
      expect(s.selectedPosition, 0);
      expect(s.peeked.contains(0), isFalse);
    });
  });
}
