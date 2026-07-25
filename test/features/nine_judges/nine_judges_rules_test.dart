import 'dart:convert';
import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('9人の審判 Ver.0.4', () {
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

    test('数字なし、初期手札は2/2/1/2で合計7枚', () {
      expect(NineJudgesConfig.numberCardsEnabled, isFalse);
      for (final faction in Faction.values) {
        final hand = game.inventoryFor(faction);
        expect([hand.life, hand.death, hand.eye, hand.judge], [2, 2, 1, 2]);
        expect(hand.total, 7);
        expect(game.actionsRemainingFor(faction), 6);
      }
      expect(
        NineJudgesRules.calculateScore(game.board).savior +
            NineJudgesRules.calculateScore(game.board).executor,
        18,
      );
    });

    test('両陣営に別々の人物3初期秘密情報が付与され相手には漏れない', () {
      final savior = game.initialKnowledgeSlots[Faction.savior]!.single;
      final executor = game.initialKnowledgeSlots[Faction.executor]!.single;
      expect(savior, isNot(executor));
      expect(game.board[savior].person.rank, 3);
      expect(
        game.knowsAttribute(game.board[savior].person, Faction.savior),
        isTrue,
      );
      expect(
        game.knowsAttribute(game.board[savior].person, Faction.executor),
        isFalse,
      );
    });

    test('EYEは未知の死人物3だけに1回使え、審議中になる', () {
      final actor = game.currentPlayer;
      final target = List.generate(game.board.length, (i) => i).firstWhere(
        (i) =>
            game.board[i].person.rank == 3 &&
            !game.knowsAttribute(game.board[i].person, actor),
      );
      act(ActionType.eye, target);
      expect(game.inventoryFor(actor).eye, 0);
      expect(game.eyeKnowsAttribute(target, actor), isTrue);
      expect(game.board[target].person.isUnderReview, isTrue);
      expect(
        game.knowsAttribute(game.board[target].person, actor.opponent),
        isFalse,
      );
      game.currentPlayer = actor;
      game.phase = TurnPhase.selectingAction;
      expect(game.canSelectAction(ActionType.eye), isFalse);
    });

    test('既知2属性から残る人物3を消去法で推論できる', () {
      final viewer = Faction.savior;
      final rankThree = [
        for (var i = 0; i < game.board.length; i++)
          if (game.board[i].person.rank == 3) i,
      ];
      game.knownAttributeSlots[viewer]!
        ..clear()
        ..addAll(rankThree.take(2));
      final inferred = game.inferredAttribute(rankThree.last, viewer);
      expect(inferred, game.board[rankThree.last].person.attribute);
      expect(game.availableEyeInformation(rankThree.last, viewer), isEmpty);
    });

    test('未審議へJUDGE不可、LIFE後の審議中人物へJUDGE可能', () {
      final target = game.board.indexWhere((slot) => slot.person.isAlive);
      game.chooseAction(ActionType.judge);
      expect(game.canTarget(target), isFalse);
      game.selectedAction = null;
      game.phase = TurnPhase.selectingAction;
      act(ActionType.life, target);
      expect(game.board[target].person.isUnderReview, isTrue);
      game.currentPlayer = game.currentPlayer.opponent;
      game.phase = TurnPhase.selectingAction;
      act(ActionType.judge, target);
      expect(game.board[target].person.isJudged, isTrue);
    });

    test('DEATHとEYEでも審議中になり、死へのDEATHは未審議でも即判決', () {
      final alive = game.board.indexWhere((slot) => slot.person.isAlive);
      act(ActionType.death, alive);
      expect(game.board[alive].person.isUnderReview, isTrue);

      game.reset();
      final dead = game.board.indexWhere((slot) => !slot.person.isAlive);
      expect(game.board[dead].person.isUnderReview, isFalse);
      act(ActionType.death, dead);
      expect(game.board[dead].person.isJudged, isTrue);
    });

    test('各プレイヤー最大6行動で手札を残してturnLimit終了', () async {
      game.actionsUsed[Faction.savior] = 5;
      game.actionsUsed[Faction.executor] = 6;
      game.currentPlayer = Faction.savior;
      final alive = game.board.indexWhere((slot) => slot.person.isAlive);
      act(ActionType.life, alive);
      await game.ensureLogSaved();
      expect(game.isFinished, isTrue);
      expect(game.endReason, 'turnLimit');
      expect(game.inventoryFor(Faction.savior).total, greaterThan(0));
      expect(game.session.actionsRemaining['savior'], 0);
    });

    test('Ver.0.4ログへ審議・残り行動・初期知識を保存', () async {
      game.actionsUsed[Faction.savior] = 5;
      game.actionsUsed[Faction.executor] = 6;
      game.currentPlayer = Faction.savior;
      final target = game.board.indexWhere((slot) => slot.person.isAlive);
      act(ActionType.life, target);
      await game.ensureLogSaved();
      final saved = await repository.loadGame(game.session.gameId);
      expect(saved!.rulesVersion, '0.4');
      expect(saved.initialKnowledge.keys, containsAll(['savior', 'executor']));
      expect(saved.actions.single.underReviewAfter, isTrue);
      expect(saved.actions.single.remainingActionsAfter, 0);
      final exported =
          jsonDecode(await repository.exportGame(saved.gameId))
              as Map<String, dynamic>;
      expect(exported['rulesVersion'], '0.4');
    });

    test('Ver.0.3 JSONは新項目なしでも読み込める', () {
      final json = game.session.toJson()
        ..['rulesVersion'] = '0.3'
        ..remove('initialKnowledge')
        ..remove('actionsUsed')
        ..remove('actionsRemaining');
      final action =
          GameActionLog(
              actionIndex: 1,
              turnNumber: 1,
              actingPlayer: 'player',
              faction: 'savior',
              actionType: 'life',
              targetPersonId: 'good-1',
              targetRank: 1,
              visibleTargetAttributeAtTime: 'good',
              actualTargetAttribute: 'good',
              stateBefore: 'alive',
              stateAfter: 'alive',
              lifeShieldBefore: false,
              lifeShieldAfter: true,
              judgedBefore: false,
              judgedAfter: false,
              actorHandBefore: const {},
              actorHandAfter: const {},
              opponentHandBefore: const {},
              opponentHandAfter: const {},
              timestamp: DateTime(2026),
            ).toJson()
            ..remove('underReviewBefore')
            ..remove('underReviewAfter')
            ..remove('remainingActionsBefore')
            ..remove('remainingActionsAfter')
            ..remove('knowledgeSource');
      json['actions'] = [action];
      final restored = GameSession.fromJson(json);
      expect(restored.rulesVersion, '0.3');
      expect(restored.initialKnowledge, isEmpty);
      expect(restored.actions.single.underReviewAfter, isFalse);
    });
  });
}
