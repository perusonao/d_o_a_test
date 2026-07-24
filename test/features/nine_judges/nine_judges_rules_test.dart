import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

void main() {
  group('9人の審判 ルール', () {
    late NineJudgesController controller;

    setUp(() {
      controller = NineJudgesController(random: Random(7));
    });

    tearDown(() => controller.dispose());

    test('LIFEで死から生になる', () {
      final index = controller.board.indexWhere(
        (slot) => !slot.person.isAlive && !slot.person.isJudged,
      );
      controller.chooseAction(ActionType.life);
      controller.selectSlot(index);
      expect(controller.board[index].person.isAlive, isTrue);
      expect(controller.currentInventory.life, 2);
    });

    test('DEATHで生から死になる', () {
      final index = controller.board.indexWhere(
        (slot) => slot.person.isAlive && !slot.person.isJudged,
      );
      controller.chooseAction(ActionType.death);
      controller.selectSlot(index);
      expect(controller.board[index].person.isAlive, isFalse);
      expect(controller.currentInventory.death, 2);
    });

    test('判決済みにはLIFE・DEATH・JUDGE・SAVEを使用できない', () {
      const judged = PersonCard(
        id: 'good-3',
        attribute: PersonAttribute.good,
        rank: 3,
        isAlive: false,
        isJudged: true,
      );
      for (final action in ActionType.values) {
        expect(
          NineJudgesRules.canUseAction(
            action: action,
            person: judged,
            viewerHasJudged: false,
          ),
          isFalse,
        );
      }
      controller.board[0] = BoardSlot(
        person: judged,
        hiddenNumber: controller.board[0].hiddenNumber,
      );
      controller.phase = TurnPhase.selectingSave;
      expect(controller.canTarget(0), isFalse);
    });

    test('3番カードは死亡時に属性非表示', () {
      const person = PersonCard(
        id: 'evil-3',
        attribute: PersonAttribute.evil,
        rank: 3,
        isAlive: false,
      );
      expect(
        NineJudgesRules.isAttributeVisible(
          person,
          viewerHasJudged: false,
          revealAll: false,
        ),
        isFalse,
      );
    });

    test('JUDGE使用者だけが死亡した3番の属性を確認できる', () {
      final index = controller.board.indexWhere(
        (slot) => slot.person.rank == 3 && !slot.person.isAlive,
      );
      final person = controller.board[index].person;
      controller.chooseAction(ActionType.judge);
      controller.selectSlot(index);

      expect(controller.knowsAttribute(person, Faction.savior), isTrue);
      expect(controller.knowsAttribute(person, Faction.executor), isFalse);
      expect(controller.currentInventory.judge, 1);
    });

    test('数字カードは1から9が重複なく配置される', () {
      final numbers = controller.board.map((slot) => slot.hiddenNumber).toSet();
      expect(numbers, {1, 2, 3, 4, 5, 6, 7, 8, 9});
      expect(controller.board, hasLength(9));
    });

    test('9人目をSAVEするとゲーム終了', () {
      for (var index = 0; index < 8; index++) {
        final slot = controller.board[index];
        controller.board[index] = slot.copyWith(
          person: slot.person.copyWith(isJudged: true),
        );
      }
      controller.phase = TurnPhase.awaitingSave;
      controller.beginSave();
      controller.selectSlot(8);
      expect(controller.judgedCount, 9);
      expect(controller.isFinished, isTrue);
    });

    test('ホットシートで9ターン進めて1ゲーム完了できる', () {
      while (!controller.isFinished) {
        final action = ActionType.values.firstWhere(controller.canSelectAction);
        controller.chooseAction(action);
        final actionTarget = List.generate(
          9,
          (index) => index,
        ).firstWhere(controller.canTarget);
        controller.selectSlot(actionTarget);
        controller.beginSave();
        final saveTarget = List.generate(
          9,
          (index) => index,
        ).firstWhere(controller.canTarget);
        controller.selectSlot(saveTarget);
        if (controller.awaitingHandoff) controller.confirmHandoff();
      }
      expect(controller.judgedCount, 9);
      expect(
        controller.logs.where((log) => log.message.startsWith('SAVE')),
        hasLength(9),
      );
      expect(
        controller.score.savior + controller.score.executor,
        greaterThan(0),
      );
    });

    test('救済者の得点を計算する', () {
      const board = [
        BoardSlot(
          person: PersonCard(
            id: 'good-2',
            attribute: PersonAttribute.good,
            rank: 2,
            isAlive: true,
          ),
          hiddenNumber: 7,
        ),
        BoardSlot(
          person: PersonCard(
            id: 'evil-3',
            attribute: PersonAttribute.evil,
            rank: 3,
            isAlive: false,
          ),
          hiddenNumber: 4,
        ),
      ];
      final score = NineJudgesRules.calculateScore(board);
      expect(score.savior, 16);
      expect(score.executor, 0);
    });

    test('執行者の得点を計算する', () {
      const board = [
        BoardSlot(
          person: PersonCard(
            id: 'good-2',
            attribute: PersonAttribute.good,
            rank: 2,
            isAlive: false,
          ),
          hiddenNumber: 7,
        ),
        BoardSlot(
          person: PersonCard(
            id: 'evil-3',
            attribute: PersonAttribute.evil,
            rank: 3,
            isAlive: true,
          ),
          hiddenNumber: 4,
        ),
      ];
      final score = NineJudgesRules.calculateScore(board);
      expect(score.savior, 0);
      expect(score.executor, 16);
    });
  });
}
