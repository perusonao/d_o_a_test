import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('9人の審判 1ターン1アクション', () {
    late NineJudgesController game;
    setUp(() => game = NineJudgesController(random: Random(7)));
    tearDown(() => game.dispose());

    int target(bool alive) => game.board.indexWhere(
      (s) => s.person.isAlive == alive && !s.person.isJudged,
    );
    void act(ActionType action, int index) {
      game.chooseAction(action);
      game.selectSlot(index);
    }

    test('LIFE使用後に即ターン終了し同一ターンJUDGE不可', () {
      final before = game.currentPlayer;
      final index = target(false);
      act(ActionType.life, index);
      expect(game.board[index].person.isAlive, isTrue);
      expect(game.currentPlayer, before.opponent);
      expect(game.turn, 2);
      expect(game.selectedAction, isNull);
    });

    test('DEATH使用後に即ターン終了し同一ターンJUDGE不可', () {
      final before = game.currentPlayer;
      act(ActionType.death, target(true));
      expect(game.currentPlayer, before.opponent);
      expect(game.turn, 2);
    });

    test('EYE数字確認は使用者だけが知り即ターン終了する', () {
      const index = 4;
      final user = game.currentPlayer;
      game.chooseAction(ActionType.eye);
      game.selectSlot(index);
      game.revealEyeInformation(EyeInformation.number);
      expect(game.knowsNumber(index, user), isTrue);
      expect(game.knowsNumber(index, user.opponent), isFalse);
      expect(game.currentPlayer, user.opponent);
    });

    test('EYE秘密属性確認は使用者だけが知る', () {
      final index = game.board.indexWhere((s) => s.person.rank == 3);
      final user = game.currentPlayer;
      expect(game.knowsAttribute(game.board[index].person, user), isFalse);
      game.chooseAction(ActionType.eye);
      game.selectSlot(index);
      game.revealEyeInformation(EyeInformation.attribute);
      expect(game.knowsAttribute(game.board[index].person, user), isTrue);
      expect(
        game.knowsAttribute(game.board[index].person, user.opponent),
        isFalse,
      );
    });

    test('JUDGEだけで現在状態を確定して1ターン消費する', () {
      final index = target(true);
      final before = game.currentPlayer;
      act(ActionType.judge, index);
      expect(game.board[index].person.isJudged, isTrue);
      expect(game.currentPlayer, before.opponent);
      expect(game.turn, 2);
    });

    test('死へのDEATHは死で即判決してターン終了する', () {
      final index = target(false);
      final before = game.currentPlayer;
      act(ActionType.death, index);
      expect(game.board[index].person.isJudged, isTrue);
      expect(game.currentPlayer, before.opponent);
    });

    test('LIFE防護は最大1枚でDEATHが除去する', () {
      final index = target(true);
      act(ActionType.life, index);
      expect(game.board[index].person.hasLifeShield, isTrue);
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.life,
          person: game.board[index].person,
          viewerKnowsNumber: false,
        ),
        isFalse,
      );
      act(ActionType.death, index);
      expect(game.board[index].person.isAlive, isTrue);
      expect(game.board[index].person.hasLifeShield, isFalse);
    });

    test('判決済み人物は全アクション対象外', () {
      final index = target(true);
      act(ActionType.judge, index);
      for (final action in ActionType.values) {
        expect(
          NineJudgesRules.canUseAction(
            action: action,
            person: game.board[index].person,
            viewerKnowsNumber: false,
          ),
          isFalse,
        );
      }
    });

    test('JUDGEと死へのDEATHのどちらでも9人目で即終了', () {
      for (var i = 0; i < 8; i++) {
        game.board[i] = game.board[i].copyWith(
          person: game.board[i].person.copyWith(isJudged: true),
        );
      }
      act(ActionType.judge, 8);
      expect(game.isFinished, isTrue);

      game.reset();
      for (var i = 0; i < 8; i++) {
        game.board[i] = game.board[i].copyWith(
          person: game.board[i].person.copyWith(isJudged: true),
        );
      }
      game.board[8] = game.board[8].copyWith(
        person: game.board[8].person.copyWith(isAlive: false),
      );
      act(ActionType.death, 8);
      expect(game.isFinished, isTrue);
    });

    test('CPU対戦は両陣営・両先攻を設定できる', () {
      for (final faction in [
        FactionSelection.savior,
        FactionSelection.executor,
      ]) {
        for (final first in [
          FirstPlayerSelection.human,
          FirstPlayerSelection.cpu,
        ]) {
          final configured = NineJudgesController(
            random: Random(1),
            settings: NineJudgesGameSettings(
              mode: GameMode.cpu,
              factionSelection: faction,
              firstPlayerSelection: first,
            ),
          );
          addTearDown(configured.dispose);
          final expectedHuman = faction == FactionSelection.savior
              ? Faction.savior
              : Faction.executor;
          expect(configured.humanFaction, expectedHuman);
          expect(
            configured.currentPlayer,
            first == FirstPlayerSelection.human
                ? expectedHuman
                : expectedHuman.opponent,
          );
        }
      }
    });

    test('ランダム陣営・ランダム先攻は有効な組み合わせへ解決される', () {
      final randomGame = NineJudgesController(
        random: Random(9),
        settings: const NineJudgesGameSettings(
          mode: GameMode.cpu,
          factionSelection: FactionSelection.random,
          firstPlayerSelection: FirstPlayerSelection.random,
        ),
      );
      addTearDown(randomGame.dispose);
      expect(Faction.values, contains(randomGame.humanFaction));
      expect(Faction.values, contains(randomGame.currentPlayer));
      expect(randomGame.humanFaction, randomGame.settings.cpuFaction.opponent);
    });
  });
}
