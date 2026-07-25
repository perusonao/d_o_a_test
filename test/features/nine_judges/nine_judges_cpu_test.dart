import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/basic_cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/random_cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cpuSettings = NineJudgesGameSettings(
    mode: GameMode.cpu,
    cpuFaction: Faction.executor,
    cpuLevel: CpuLevel.basic,
    skipCpuDelays: true,
  );

  group('Nine Judges CPU', () {
    test('RANDOM CPUは合法なアクションと対象だけを選ぶ', () {
      final controller = NineJudgesController(
        random: Random(1),
        settings: cpuSettings.copyWith(cpuLevel: CpuLevel.random),
      );
      addTearDown(controller.dispose);
      controller.currentPlayer = Faction.executor;
      final view = controller.cpuView();
      final strategy = RandomCpuStrategy(Random(3));
      for (var i = 0; i < 50; i++) {
        final decision = strategy.decideAction(view);
        expect(
          view.legalTargets[decision.action],
          contains(decision.targetIndex),
        );
        expect(view.slots[decision.targetIndex].person.isJudged, isFalse);
      }
    });

    test('EYE候補は未判決の死状態人物3だけ', () {
      final controller = NineJudgesController(
        random: Random(2),
        settings: cpuSettings,
      );
      addTearDown(controller.dispose);
      controller.currentPlayer = Faction.executor;
      controller.board[4] = controller.board[4].copyWith(
        person: controller.board[4].person.copyWith(isJudged: true),
      );
      final view = controller.cpuView();
      final eyeTargets = view.legalTargets[ActionType.eye]!;
      for (final index in eyeTargets) {
        expect(controller.board[index].person.rank, 3);
        expect(controller.board[index].person.isAlive, isFalse);
        expect(controller.board[index].person.isJudged, isFalse);
      }
      expect(eyeTargets, isNot(contains(4)));
    });

    test('CPUビューは未確認人物3の属性と属性を含むIDを渡さない', () {
      final controller = NineJudgesController(
        random: Random(12),
        settings: cpuSettings,
      );
      addTearDown(controller.dispose);
      final index = controller.board.indexWhere(
        (slot) => slot.person.rank == 3 && !slot.person.isAlive,
      );
      final slot = controller.cpuView().slots[index];
      expect(slot.knownAttribute, isNull);
      expect(slot.person.id, 'unknown-slot-$index');
      expect(
        slot.person.id,
        isNot(contains(controller.board[index].person.attribute.name)),
      );
    });

    test('BASIC CPUは自陣営に有利な変更を優先する', () {
      const view = CpuGameView(
        faction: Faction.executor,
        slots: [
          CpuSlotView(
            index: 0,
            person: PersonCard(
              id: 'good-2',
              attribute: PersonAttribute.good,
              rank: 2,
              isAlive: true,
            ),
          ),
          CpuSlotView(
            index: 1,
            person: PersonCard(
              id: 'evil-2',
              attribute: PersonAttribute.evil,
              rank: 2,
              isAlive: true,
            ),
          ),
        ],
        inventory: ActionInventory(life: 3, death: 3, eye: 2),
        legalTargets: {
          ActionType.death: [0, 1],
        },
      );
      expect(const BasicCpuStrategy().decideAction(view).targetIndex, 0);
    });

    test('BASIC CPUは同条件なら高価値人物を優先する', () {
      const view = CpuGameView(
        faction: Faction.executor,
        slots: [
          CpuSlotView(
            index: 0,
            person: PersonCard(
              id: 'good-1',
              attribute: PersonAttribute.good,
              rank: 1,
              isAlive: true,
            ),
          ),
          CpuSlotView(
            index: 1,
            person: PersonCard(
              id: 'good-3',
              attribute: PersonAttribute.good,
              rank: 3,
              isAlive: true,
            ),
          ),
        ],
        inventory: ActionInventory(life: 3, death: 3, eye: 2),
        legalTargets: {
          ActionType.death: [0, 1],
        },
      );
      expect(const BasicCpuStrategy().decideAction(view).targetIndex, 1);
    });

    test('死へのDEATHは即判決となり追加JUDGEを要求しない', () {
      final controller = NineJudgesController(
        random: Random(4),
        settings: cpuSettings,
      );
      addTearDown(controller.dispose);
      controller.currentPlayer = Faction.executor;
      final dead = controller.board.indexWhere((slot) => !slot.person.isAlive);
      controller.cpuActing = true;
      controller.chooseAction(ActionType.death);
      controller.selectSlot(dead);
      controller.cpuActing = false;
      expect(controller.board[dead].person.isJudged, isTrue);
      expect(controller.phase, TurnPhase.selectingAction);
      expect(controller.currentPlayer, Faction.savior);
    });

    test('CPUターンを実行するとプレイヤーへ正常に戻る', () {
      final controller = NineJudgesController(
        random: Random(5),
        settings: cpuSettings,
      );
      addTearDown(controller.dispose);
      controller.currentPlayer = Faction.executor;
      final decision = controller.performCpuAction();
      expect(decision, isNotNull);
      expect(controller.currentPlayer, Faction.savior);
      expect(controller.awaitingHandoff, isFalse);
    });

    test('CPU対戦を9人判決までUIなしで完走できる', () {
      final controller = NineJudgesController(
        random: Random(6),
        settings: cpuSettings,
      );
      addTearDown(controller.dispose);
      var guard = 0;
      while (!controller.isFinished && guard++ < 20) {
        if (controller.isCpuTurn) {
          controller.performCpuAction();
        } else {
          final action = controller.canSelectAction(ActionType.judge)
              ? ActionType.judge
              : ActionType.values.firstWhere(controller.canSelectAction);
          controller.chooseAction(action);
          final target = List.generate(
            9,
            (i) => i,
          ).firstWhere(controller.canTarget);
          controller.selectSlot(target);
          if (controller.phase == TurnPhase.selectingEyeInformation) {
            controller.revealEyeInformation(
              controller
                  .availableEyeInformation(target, controller.currentPlayer)
                  .first,
            );
          }
        }
      }
      expect(controller.isFinished, isTrue);
      expect(controller.judgedCount, lessThanOrEqualTo(9));
      expect(controller.endReason, isNotNull);
    });
  });
}
