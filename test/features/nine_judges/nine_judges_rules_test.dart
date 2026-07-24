import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('9人の審判 最新ルール', () {
    late NineJudgesController controller;

    setUp(() => controller = NineJudgesController(random: Random(7)));
    tearDown(() => controller.dispose());

    int find({required bool alive}) => controller.board.indexWhere(
      (slot) => slot.person.isAlive == alive && !slot.person.isJudged,
    );

    void act(ActionType action, int index) {
      controller.chooseAction(action);
      controller.selectSlot(index);
    }

    test('死へのLIFEは蘇生、生へのLIFEは防護を付与する', () {
      final dead = find(alive: false);
      act(ActionType.life, dead);
      expect(controller.board[dead].person.isAlive, isTrue);

      controller.reset();
      final alive = find(alive: true);
      act(ActionType.life, alive);
      expect(controller.board[alive].person.hasLifeShield, isTrue);
      expect(controller.board[alive].person.isAlive, isTrue);
    });

    test('LIFE防護はDEATHを吸収し、防護なしなら死亡する', () {
      final shielded = find(alive: true);
      controller.board[shielded] = controller.board[shielded].copyWith(
        person: controller.board[shielded].person.copyWith(hasLifeShield: true),
      );
      act(ActionType.death, shielded);
      expect(controller.board[shielded].person.isAlive, isTrue);
      expect(controller.board[shielded].person.hasLifeShield, isFalse);

      controller.reset();
      final alive = find(alive: true);
      act(ActionType.death, alive);
      expect(controller.board[alive].person.isAlive, isFalse);
    });

    test('死亡DEATHは即判決となり追加JUDGEなしで引き渡す', () {
      final dead = find(alive: false);
      act(ActionType.death, dead);
      expect(controller.board[dead].person.isJudged, isTrue);
      expect(controller.awaitingHandoff, isTrue);
      expect(controller.currentPlayer, Faction.executor);
    });

    test('EYE結果は使用者だけが知り、既知数字と判決済みには使えない', () {
      const unknown = 4;
      act(ActionType.eye, unknown);
      expect(controller.knowsNumber(unknown, Faction.savior), isTrue);
      expect(controller.knowsNumber(unknown, Faction.executor), isFalse);
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.eye,
          person: controller.board[unknown].person,
          viewerKnowsNumber: true,
        ),
        isFalse,
      );
      final judged = controller.board[unknown].person.copyWith(isJudged: true);
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.eye,
          person: judged,
          viewerKnowsNumber: false,
        ),
        isFalse,
      );
    });

    test('JUDGEは現在の生死を確定し判決済みは全操作不可', () {
      for (final alive in [true, false]) {
        controller.reset();
        final index = find(alive: alive);
        controller.chooseAction(ActionType.eye);
        final eyeTarget = List.generate(
          9,
          (i) => i,
        ).firstWhere(controller.canTarget);
        controller.selectSlot(eyeTarget);
        controller.beginJudge();
        controller.selectSlot(index);
        expect(controller.board[index].person.isJudged, isTrue);
      }

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
            viewerKnowsNumber: false,
          ),
          isFalse,
        );
      }
    });

    test('通常JUDGEと死亡DEATHのどちらでも9人目で終了する', () {
      for (var i = 0; i < 8; i++) {
        controller.board[i] = controller.board[i].copyWith(
          person: controller.board[i].person.copyWith(isJudged: true),
        );
      }
      controller.phase = TurnPhase.awaitingJudge;
      controller.beginJudge();
      controller.selectSlot(8);
      expect(controller.isFinished, isTrue);

      controller.reset();
      for (var i = 0; i < 8; i++) {
        controller.board[i] = controller.board[i].copyWith(
          person: controller.board[i].person.copyWith(isJudged: true),
        );
      }
      controller.board[8] = controller.board[8].copyWith(
        person: controller.board[8].person.copyWith(isAlive: false),
      );
      act(ActionType.death, 8);
      expect(controller.isFinished, isTrue);
    });

    test('死亡中の3は属性非公開で、蘇生すると公開される', () {
      final index = controller.board.indexWhere(
        (slot) => slot.person.rank == 3,
      );
      expect(
        controller.knowsAttribute(
          controller.board[index].person,
          Faction.savior,
        ),
        isFalse,
      );
      act(ActionType.life, index);
      expect(
        controller.knowsAttribute(
          controller.board[index].person,
          Faction.savior,
        ),
        isTrue,
      );
    });

    test('数字は1〜9で、得点は人物ランクと数字の合計', () {
      expect(controller.board.map((s) => s.hiddenNumber).toSet(), {
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
      });
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
            isAlive: true,
          ),
          hiddenNumber: 4,
        ),
      ];
      final score = NineJudgesRules.calculateScore(board);
      expect(score.savior, 9);
      expect(score.executor, 7);
    });
  });
}
