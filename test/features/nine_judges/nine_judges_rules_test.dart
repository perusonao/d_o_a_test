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
  group('9人の審判 Ver.0.5', () {
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

    test('数字なし、初期手札は2/2/1/1で合計6枚', () {
      expect(NineJudgesConfig.numberCardsEnabled, isFalse);
      for (final faction in Faction.values) {
        final hand = game.inventoryFor(faction);
        expect([hand.life, hand.death, hand.eye, hand.judge], [2, 2, 1, 1]);
        expect(hand.total, 6);
        expect(game.actionsRemainingFor(faction), 6);
      }
      expect(
        NineJudgesRules.calculateScore(game.board).savior +
            NineJudgesRules.calculateScore(game.board).executor,
        18,
      );
    });

    test('左・中央・右列はrank 1・2・3で各属性を1枚ずつ含む', () {
      for (var column = 0; column < 3; column++) {
        final people = [
          for (var row = 0; row < 3; row++) game.board[row * 3 + column].person,
        ];
        expect(people.map((person) => person.rank).toSet(), {column + 1});
        expect(
          people.map((person) => person.attribute).toSet(),
          PersonAttribute.values.toSet(),
        );
      }
    });

    test('同じseedなら同じ規則配置と初期秘密情報を再現する', () {
      final first = NineJudgesController(seed: 441);
      final second = NineJudgesController(seed: 441);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      expect(
        first.board.map((slot) => slot.person.id),
        second.board.map((slot) => slot.person.id),
      );
      expect(
        first.session.initialKnowledge['savior']!.personId,
        second.session.initialKnowledge['savior']!.personId,
      );
    });

    test('scoreVisible=falseはrankを隠しランダム配置にする', () {
      final hidden = NineJudgesController(
        seed: 331,
        settings: const NineJudgesGameSettings(scoreVisible: false),
      );
      addTearDown(hidden.dispose);
      expect(hidden.settings.scoreVisible, isFalse);
      expect(
        List.generate(
          9,
          (i) => hidden.knowsRank(i, Faction.savior),
        ).where((known) => known),
        hasLength(1),
      );
      expect(
        List.generate(3, (row) => hidden.board[row * 3].person.rank).toSet(),
        isNot({1}),
      );
      expect(hidden.session.scoreVisible, isFalse);
      final cpuView = NineJudgesController(
        seed: 332,
        settings: const NineJudgesGameSettings(
          mode: GameMode.cpu,
          scoreVisible: false,
          factionSelection: FactionSelection.savior,
        ),
      );
      addTearDown(cpuView.dispose);
      final view = cpuView.cpuView();
      final unknown = view.slots.firstWhere((slot) => slot.knownRank == null);
      expect(unknown.person.rank, 2, reason: 'CPUへ真の非公開rankを渡さない');
      expect(unknown.person.id, startsWith('unknown-slot-'));
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

    test('EYEは任意の未知情報を1回だけ属性＋rank確認し使用者だけが知る', () {
      final actor = game.currentPlayer;
      final target = List.generate(
        game.board.length,
        (i) => i,
      ).firstWhere((i) => game.availableEyeInformation(i, actor).isNotEmpty);
      act(ActionType.eye, target);
      expect(game.inventoryFor(actor).eye, 0);
      expect(game.eyeKnowsAttribute(target, actor), isTrue);
      expect(game.knowsRank(target, actor), isTrue);
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
      expect(game.board[target].person.judgeAvailableFromTurn, game.turn + 1);
      game.currentPlayer = game.currentPlayer.opponent;
      expect(game.canSelectAction(ActionType.judge), isFalse);
      game.currentPlayer = game.currentPlayer.opponent;
      final other = game.board.indexWhere(
        (slot) =>
            slot.person.id != game.board[target].person.id &&
            slot.person.isAlive,
      );
      act(ActionType.death, other);
      expect(game.currentPlayer, game.board[target].person.lastStateChangedBy);
      act(ActionType.judge, target);
      expect(game.board[target].person.isJudged, isTrue);
      expect(game.board[target].person.isUnderReview, isFalse);
      expect(game.session.actions.last.underReviewBefore, isTrue);
      expect(game.session.actions.last.underReviewAfter, isFalse);
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
      expect(game.board[dead].person.isUnderReview, isFalse);
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

    test('Ver.0.5ログへ審議・JUDGE待機・scoreVisibleを保存', () async {
      game.actionsUsed[Faction.savior] = 5;
      game.actionsUsed[Faction.executor] = 6;
      game.currentPlayer = Faction.savior;
      final target = game.board.indexWhere((slot) => slot.person.isAlive);
      act(ActionType.life, target);
      await game.ensureLogSaved();
      final saved = await repository.loadGame(game.session.gameId);
      expect(saved!.rulesVersion, '0.5');
      expect(saved.initialKnowledge.keys, containsAll(['savior', 'executor']));
      expect(saved.actions.single.underReviewAfter, isTrue);
      expect(saved.actions.single.remainingActionsAfter, 0);
      expect(saved.actions.single.scoreVisible, isTrue);
      expect(saved.actions.single.judgeAvailableFromTurn, greaterThan(0));
      final exported =
          jsonDecode(await repository.exportGame(saved.gameId))
              as Map<String, dynamic>;
      expect(exported['rulesVersion'], '0.5');
      expect(await repository.exportGameText(saved.gameId), contains('Turn 1'));
    });

    test('対象確定前ならアクション選択をキャンセル・切替できる', () {
      game.chooseAction(ActionType.life);
      expect(game.phase, TurnPhase.selectingActionTarget);
      expect(game.canSwitchAction(ActionType.death), isTrue);
      game.chooseAction(ActionType.death);
      expect(game.selectedAction, ActionType.death);
      game.cancelActionSelection();
      expect(game.phase, TurnPhase.selectingAction);
      expect(game.selectedAction, isNull);
      expect(game.inventoryFor(game.currentPlayer).death, 2);
    });

    test('CPUのEYE結果メッセージは秘密属性を含まない', () {
      final cpu = NineJudgesController(
        seed: 81,
        settings: const NineJudgesGameSettings(
          mode: GameMode.cpu,
          cpuFaction: Faction.savior,
          firstPlayer: Faction.savior,
          factionSelection: FactionSelection.executor,
          firstPlayerSelection: FirstPlayerSelection.cpu,
          skipCpuDelays: true,
        ),
      );
      addTearDown(cpu.dispose);
      cpu.inventories[cpu.settings.cpuFaction] = const ActionInventory(
        life: 0,
        death: 0,
        eye: 1,
        judge: 0,
      );
      cpu.performCpuAction();
      expect(cpu.lastCpuActionType, ActionType.eye);
      expect(cpu.lastCpuActionMessage, '対象の情報を確認しました');
      expect(
        PersonAttribute.values.any(
          (attribute) => cpu.lastCpuActionMessage!.contains(attribute.label),
        ),
        isFalse,
      );
    });

    test('CPU LIFE・DEATH・JUDGEは対象と結果を構造化して保持する', () {
      NineJudgesController cpuFor(ActionType action) {
        final cpu = NineJudgesController(
          seed: 93,
          settings: const NineJudgesGameSettings(
            mode: GameMode.cpu,
            factionSelection: FactionSelection.executor,
            firstPlayerSelection: FirstPlayerSelection.cpu,
            skipCpuDelays: true,
          ),
        );
        cpu.inventories[cpu.settings.cpuFaction] = ActionInventory(
          life: action == ActionType.life ? 1 : 0,
          death: action == ActionType.death ? 1 : 0,
          eye: 0,
          judge: action == ActionType.judge ? 1 : 0,
        );
        if (action == ActionType.judge) {
          final target = cpu.board.indexWhere((slot) => slot.person.isAlive);
          cpu.board[target] = cpu.board[target].copyWith(
            person: cpu.board[target].person.copyWith(isUnderReview: true),
          );
        }
        return cpu;
      }

      for (final action in [
        ActionType.life,
        ActionType.death,
        ActionType.judge,
      ]) {
        final cpu = cpuFor(action);
        addTearDown(cpu.dispose);
        cpu.performCpuAction();
        expect(cpu.lastCpuActionType, action);
        expect(cpu.lastCpuTargetIndex, isNotNull);
        expect(cpu.lastCpuActionMessage, isNotEmpty);
        if (action == ActionType.judge) {
          expect(cpu.lastCpuWasJudgment, isTrue);
        }
      }
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
