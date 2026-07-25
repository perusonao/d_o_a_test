import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/basic_cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_evaluator.dart';
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

    test('既知数字と判決済み人物はEYE候補にならない', () {
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
      for (final index in controller.knownNumberSlots[Faction.executor]!) {
        if (eyeTargets.contains(index)) {
          expect(
            controller
                .availableEyeInformation(index, Faction.executor)
                .contains(EyeInformation.attribute),
            isTrue,
          );
        }
      }
      expect(eyeTargets, isNot(contains(4)));
    });

    test('CPUビューは未知の秘密数字を渡さず期待値を使う', () {
      final controller = NineJudgesController(
        random: Random(3),
        settings: cpuSettings,
      );
      addTearDown(controller.dispose);
      controller.currentPlayer = Faction.executor;
      const unknownIndex = 4;
      final firstView = controller.cpuView();
      expect(firstView.slots[unknownIndex].knownNumber, isNull);
      final firstEstimate = CpuEvaluator.estimatedNumberValue(
        firstView,
        firstView.slots[unknownIndex],
      );
      controller.board[unknownIndex] = BoardSlot(
        person: controller.board[unknownIndex].person,
        hiddenNumber: controller.board[unknownIndex].hiddenNumber == 9 ? 1 : 9,
      );
      final secondView = controller.cpuView();
      expect(secondView.slots[unknownIndex].knownNumber, isNull);
      expect(
        CpuEvaluator.estimatedNumberValue(
          secondView,
          secondView.slots[unknownIndex],
        ),
        firstEstimate,
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
            knownNumber: 5,
          ),
          CpuSlotView(
            index: 1,
            person: PersonCard(
              id: 'evil-2',
              attribute: PersonAttribute.evil,
              rank: 2,
              isAlive: true,
            ),
            knownNumber: 5,
          ),
        ],
        inventory: ActionInventory(life: 3, death: 3, eye: 2),
        unknownNumberCandidates: {1, 2, 3, 4, 6, 7, 8, 9},
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
            knownNumber: 1,
          ),
          CpuSlotView(
            index: 1,
            person: PersonCard(
              id: 'good-3',
              attribute: PersonAttribute.good,
              rank: 3,
              isAlive: true,
            ),
            knownNumber: 9,
          ),
        ],
        inventory: ActionInventory(life: 3, death: 3, eye: 2),
        unknownNumberCandidates: {2, 3, 4, 5, 6, 7, 8},
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
      expect(controller.judgedCount, 9);
    });
  });
}
