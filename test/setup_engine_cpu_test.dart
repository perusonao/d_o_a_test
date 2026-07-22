import 'dart:math';

import 'package:dead_or_alive/features/game/application/cpu_strategy.dart';
import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/application/game_setup_service.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('セットアップ', () {
    test('人カードは9枚・善悪中立3枚ずつ・数字1〜9が一意', () {
      for (var seed = 0; seed < 20; seed++) {
        final persons = GameSetupService(random: Random(seed)).buildPersons();
        expect(persons.length, 9);
        int t(PersonType x) => persons.where((p) => p.type == x).length;
        expect(t(PersonType.good), 3);
        expect(t(PersonType.evil), 3);
        expect(t(PersonType.neutral), 3);
        final numbers = persons.map((p) => p.number).toSet();
        expect(numbers, {1, 2, 3, 4, 5, 6, 7, 8, 9});
        expect(persons.every((p) => p.status == PersonStatus.alive), isTrue);
      }
    });

    test('秘密情報：各自3枚・重複なし・残り3枚は誰も知らない', () {
      for (var seed = 0; seed < 20; seed++) {
        final persons = GameSetupService(random: Random(seed)).buildPersons();
        final player = persons.where((p) => p.knownBy == Knower.player).length;
        final cpu = persons.where((p) => p.knownBy == Knower.cpu).length;
        final none = persons.where((p) => p.knownBy == Knower.none).length;
        expect(player, GameConstants.secretKnownPerPlayer);
        expect(cpu, GameConstants.secretKnownPerPlayer);
        expect(none, 3);
      }
    });

    test('手札：弱い役7枚・強い役6枚', () {
      final setup = GameSetupService(random: Random(1));
      final weak = setup.buildLifeDeathHand(TurnOwner.player, GameConstants.weakRole);
      final strong = setup.buildLifeDeathHand(
          TurnOwner.cpu,
          GameConstants.weakRole == Role.savior
              ? Role.executioner
              : Role.savior);
      expect(weak.length, 7);
      expect(strong.length, 6);
    });
  });

  group('エンジン', () {
    test('startGame：弱い役が先手・役割は反対', () {
      final engine = GameEngine(random: Random(1));
      final gs = engine.startGame(Role.savior);
      expect(gs.player.role, Role.savior);
      expect(gs.cpu.role, Role.executioner);
      // weakRole=savior のとき先手はプレイヤー。
      final expectPlayerFirst = GameConstants.weakRole == Role.savior;
      expect(gs.phase == GamePhase.playerTurn, expectPlayerFirst);
    });

    test('公開履歴に正体（種類）は含まれない', () {
      final engine = GameEngine(random: Random(2));
      var gs = engine.startGame(Role.executioner);
      // 適当に1手進める（プレイヤー席）。
      final actor = gs.phase == GamePhase.playerTurn
          ? TurnOwner.player
          : TurnOwner.cpu;
      final strat = DefaultCpuStrategy(random: Random(2));
      final d = strat.decide(gs, actor)!;
      gs = engine.performAction(gs, d.action);
      expect(gs.history.length, 1);
      final h = gs.history.first;
      // PublicAction には効果・数字・成否・位置のみ（種類フィールドは存在しない）。
      expect(h.position, d.action.targetPosition);
    });

    test('全手番消化で finished になる', () {
      final engine = GameEngine(random: Random(3));
      final strat = DefaultCpuStrategy(random: Random(3));
      var gs = engine.startGame(Role.savior);
      var guard = 0;
      while (gs.phase != GamePhase.finished && guard < 200) {
        final actor = gs.phase == GamePhase.cpuTurn
            ? TurnOwner.cpu
            : TurnOwner.player;
        final d = strat.decide(gs, actor);
        if (d == null) {
          gs = engine.advanceTurn(gs, actor);
        } else {
          gs = engine.performAction(gs, d.action);
          gs = engine.advanceTurn(gs, actor);
        }
        guard++;
      }
      expect(gs.phase, GamePhase.finished);
      expect(gs.player.hasUsableCards, isFalse);
      expect(gs.cpu.hasUsableCards, isFalse);
    });
  });

  group('CPU', () {
    test('CPUは封印済みを対象にせず、常に有効な手を返す', () {
      for (var seed = 0; seed < 30; seed++) {
        final engine = GameEngine(random: Random(seed));
        final strat = DefaultCpuStrategy(random: Random(seed));
        var gs = engine.startGame(Role.savior);
        var guard = 0;
        while (gs.cpu.hasUsableCards && guard < 100) {
          if (gs.phase == GamePhase.playerTurn) {
            // プレイヤー席も CPU に代行させて進める。
            final d = strat.decide(gs, TurnOwner.player);
            gs = d == null
                ? engine.advanceTurn(gs, TurnOwner.player)
                : engine.advanceTurn(
                    engine.performAction(gs, d.action), TurnOwner.player);
            guard++;
            continue;
          }
          final d = strat.decide(gs, TurnOwner.cpu);
          if (d != null) {
            final target = gs.personAt(d.action.targetPosition);
            expect(target.sealed, isFalse); // 封印済みを狙わない
            expect(
              gs.cpu.hand.any(
                  (c) => c.id == d.action.lifeDeathCardId && !c.isUsed),
              isTrue,
            );
            gs = engine.performAction(gs, d.action);
          }
          gs = engine.advanceTurn(gs, TurnOwner.cpu);
          guard++;
        }
      }
    });
  });
}
