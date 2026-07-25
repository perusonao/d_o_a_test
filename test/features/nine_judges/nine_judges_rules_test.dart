import 'dart:convert';
import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('9人の審判 Ver.0.3', () {
    late MemoryGameLogRepository repository;
    late NineJudgesController game;

    setUp(() {
      repository = MemoryGameLogRepository();
      game = NineJudgesController(
        random: Random(7),
        seed: 7,
        logRepository: repository,
      );
    });
    tearDown(() => game.dispose());

    void act(ActionType action, int index) {
      game.chooseAction(action);
      game.selectSlot(index);
      if (action == ActionType.eye) {
        game.revealEyeInformation(EyeInformation.attribute);
      }
    }

    int legal(ActionType action) => List.generate(9, (i) => i).firstWhere((i) {
      game.chooseAction(action);
      final result = game.canTarget(i);
      game.selectedAction = null;
      game.phase = TurnPhase.selectingAction;
      return result;
    });

    test('数字要素は無効で得点は人物ランクのみ', () {
      expect(NineJudgesConfig.numberCardsEnabled, isFalse);
      expect(game.knowsNumber(0, Faction.savior), isFalse);
      final score = NineJudgesRules.calculateScore([
        const BoardSlot(
          hiddenNumber: 9,
          person: PersonCard(
            id: 'good-2',
            attribute: PersonAttribute.good,
            rank: 2,
            isAlive: true,
          ),
        ),
      ]);
      expect(score.savior, 2);
    });

    test('初期手札はLIFE2 DEATH2 EYE2 JUDGE3で相手分も参照可能', () {
      for (final faction in Faction.values) {
        final hand = game.inventoryFor(faction);
        expect([hand.life, hand.death, hand.eye, hand.judge], [2, 2, 2, 3]);
      }
    });

    test('LIFEとDEATHは2枚、JUDGEは3枚を超えて使用できない', () {
      for (final entry in {
        ActionType.life: 2,
        ActionType.death: 2,
        ActionType.judge: 3,
      }.entries) {
        game.reset();
        final faction = game.currentPlayer;
        for (var i = 0; i < entry.value; i++) {
          game.currentPlayer = faction;
          game.phase = TurnPhase.selectingAction;
          act(entry.key, legal(entry.key));
        }
        game.currentPlayer = faction;
        game.phase = TurnPhase.selectingAction;
        expect(game.inventoryFor(faction).remaining(entry.key), 0);
        expect(game.canSelectAction(entry.key), isFalse);
      }
    });

    test('EYEは死状態の未確認人物3だけが対象で使用者のみ知る', () {
      final user = game.currentPlayer;
      final deadThree = game.board.indexWhere(
        (s) => s.person.rank == 3 && !s.person.isAlive,
      );
      final rankTwo = game.board.indexWhere((s) => s.person.rank == 2);
      game.chooseAction(ActionType.eye);
      expect(game.canTarget(deadThree), isTrue);
      expect(game.canTarget(rankTwo), isFalse);
      game.selectSlot(deadThree);
      game.revealEyeInformation(EyeInformation.attribute);
      expect(game.knowsAttribute(game.board[deadThree].person, user), isTrue);
      expect(
        game.knowsAttribute(game.board[deadThree].person, user.opponent),
        isFalse,
      );
      expect(game.inventoryFor(user).eye, 1);
    });

    test('EYEは2枚を超えて使用できない', () {
      final user = game.currentPlayer;
      final targets = [
        for (var i = 0; i < game.board.length; i++)
          if (game.board[i].person.rank == 3) i,
      ];
      for (final index in targets.take(2)) {
        game.currentPlayer = user;
        game.phase = TurnPhase.selectingAction;
        act(ActionType.eye, index);
      }
      game.currentPlayer = user;
      game.phase = TurnPhase.selectingAction;
      expect(game.inventoryFor(user).eye, 0);
      expect(game.canSelectAction(ActionType.eye), isFalse);
    });

    test('死へのDEATHは即判決、JUDGEも現在状態で判決する', () {
      final dead = game.board.indexWhere((s) => !s.person.isAlive);
      act(ActionType.death, dead);
      expect(game.board[dead].person.isJudged, isTrue);
      final alive = game.board.indexWhere(
        (s) => s.person.isAlive && !s.person.isJudged,
      );
      act(ActionType.judge, alive);
      expect(game.board[alive].person.isJudged, isTrue);
    });

    test('全手札消費で未判決を残して終了し得点対象になる', () async {
      game.inventories[Faction.savior] = const ActionInventory(
        life: 0,
        death: 0,
        eye: 0,
        judge: 1,
      );
      game.inventories[Faction.executor] = const ActionInventory(
        life: 0,
        death: 0,
        eye: 0,
        judge: 0,
      );
      act(ActionType.judge, 0);
      await Future<void>.delayed(Duration.zero);
      expect(game.isFinished, isTrue);
      expect(game.endReason, 'allHandsEmpty');
      expect(game.judgedCount, 1);
      expect(game.score.savior + game.score.executor, 18);
    });

    test('終了時にrulesVersion付きログを保存・再読込・削除・JSON出力', () async {
      game.inventories[Faction.savior] = const ActionInventory(
        life: 0,
        death: 0,
        eye: 0,
        judge: 1,
      );
      game.inventories[Faction.executor] = const ActionInventory(
        life: 0,
        death: 0,
        eye: 0,
        judge: 0,
      );
      act(ActionType.judge, 0);
      await Future<void>.delayed(Duration.zero);
      final saved = await repository.loadGame(game.session.gameId);
      expect(saved, isNotNull);
      expect(saved!.rulesVersion, '0.3');
      expect(saved.initialBoard, hasLength(9));
      expect(saved.finalBoard, hasLength(9));
      expect(saved.actions.single.actorHandBefore['judge'], 1);
      final exported =
          jsonDecode(await repository.exportGame(saved.gameId))
              as Map<String, dynamic>;
      expect(exported['rulesVersion'], '0.3');
      await repository.deleteGame(saved.gameId);
      expect(await repository.loadGame(saved.gameId), isNull);
    });
  });
}
