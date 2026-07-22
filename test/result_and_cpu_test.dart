import 'dart:math';

import 'package:dead_or_alive/features/game/application/cpu_strategy.dart';
import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/application/game_rule_service.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_action.dart';
import 'package:dead_or_alive/features/game/domain/game_log_entry.dart';
import 'package:dead_or_alive/features/game/domain/game_state.dart';
import 'package:dead_or_alive/features/game/domain/life_death_card.dart';
import 'package:dead_or_alive/features/game/domain/person_card.dart';
import 'package:dead_or_alive/features/game/domain/player_state.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _wrap(PlayerState player, PlayerState cpu) => GameState(
      player: player,
      cpu: cpu,
      phase: GamePhase.playerTurn,
      logs: const [GameLogEntry(message: 'test', actor: null)],
    );

GameAction _action(String cardId, String personId) => GameAction(
      actor: TurnOwner.player,
      lifeDeathCardId: cardId,
      targetPersonId: personId,
      targetOwner: TurnOwner.cpu,
    );

PersonCard p(String id, PersonType type, PersonStatus status) => PersonCard(
      id: id,
      type: type,
      number: 5,
      status: status,
      owner: TurnOwner.player,
    );

LifeDeathCard c(int i, {bool used = false}) => LifeDeathCard(
      id: 'c$i',
      effect: LifeDeathEffect.dead,
      number: 5,
      isUsed: used,
    );

PlayerState state({
  required TurnOwner owner,
  required Faction faction,
  required List<PersonCard> persons,
  List<LifeDeathCard> hand = const [],
}) =>
    PlayerState(owner: owner, faction: faction, persons: persons, hand: hand);

void main() {
  const rules = GameRuleService();

  group('勝敗判定', () {
    test('善人陣営: alive善人 > alive悪人 で勝利', () {
      final player = state(
        owner: TurnOwner.player,
        faction: Faction.good,
        persons: [
          p('g1', PersonType.good, PersonStatus.alive),
          p('g2', PersonType.good, PersonStatus.alive),
          p('e1', PersonType.evil, PersonStatus.alive),
        ],
      );
      final cpu = state(
        owner: TurnOwner.cpu,
        faction: Faction.evil,
        persons: const [],
      );
      final r = rules.judgeResult(player, cpu);
      expect(r.winner, Faction.good);
      expect(r.playerWon, isTrue);
    });

    test('悪人陣営: alive悪人 >= alive善人 で勝利', () {
      final player = state(
        owner: TurnOwner.player,
        faction: Faction.evil,
        persons: [
          p('e1', PersonType.evil, PersonStatus.alive),
          p('e2', PersonType.evil, PersonStatus.alive),
          p('g1', PersonType.good, PersonStatus.alive),
        ],
      );
      final cpu = state(
        owner: TurnOwner.cpu,
        faction: Faction.good,
        persons: const [],
      );
      final r = rules.judgeResult(player, cpu);
      expect(r.winner, Faction.evil);
      expect(r.playerWon, isTrue);
    });

    test('引き分け（同数）は悪人陣営の勝利', () {
      final player = state(
        owner: TurnOwner.player,
        faction: Faction.good,
        persons: [
          p('g1', PersonType.good, PersonStatus.alive),
          p('e1', PersonType.evil, PersonStatus.alive),
        ],
      );
      final cpu = state(
        owner: TurnOwner.cpu,
        faction: Faction.evil,
        persons: const [],
      );
      final r = rules.judgeResult(player, cpu);
      expect(r.winner, Faction.evil);
      expect(r.playerWon, isFalse); // プレイヤーは善人陣営なので敗北。
    });

    test('中立は勝敗人数に含めない', () {
      final player = state(
        owner: TurnOwner.player,
        faction: Faction.good,
        persons: [
          p('g1', PersonType.good, PersonStatus.alive),
          p('n1', PersonType.neutral, PersonStatus.alive),
          p('n2', PersonType.neutral, PersonStatus.alive),
        ],
      );
      final cpu = state(
        owner: TurnOwner.cpu,
        faction: Faction.evil,
        persons: const [],
      );
      final r = rules.judgeResult(player, cpu);
      // 善人1 > 悪人0 なので善人勝利。中立は無関係。
      expect(r.winner, Faction.good);
      expect(r.aliveNeutral, 2);
    });
  });

  group('手札3枚未満のペナルティ', () {
    test('残り2枚なら2枚とも破棄される', () {
      final engine = GameEngine(random: Random(1));
      // 悪人が中立を殺してもペナルティにならないので、善人陣営でテスト。
      // プレイヤー(善)が CPU側の中立を dead にする -> ペナルティ。
      final neutral = PersonCard(
        id: 'n',
        type: PersonType.neutral,
        number: 1,
        status: PersonStatus.alive,
        owner: TurnOwner.cpu,
      );
      final player = PlayerState(
        owner: TurnOwner.player,
        faction: Faction.good,
        persons: const [],
        hand: [
          LifeDeathCard(id: 'use', effect: LifeDeathEffect.dead, number: 9),
          LifeDeathCard(id: 'a', effect: LifeDeathEffect.alive, number: 5),
          LifeDeathCard(id: 'b', effect: LifeDeathEffect.keep, number: 5),
        ],
      );
      final cpu = PlayerState(
        owner: TurnOwner.cpu,
        faction: Faction.evil,
        persons: [neutral],
        hand: const [],
      );
      var gs = _wrap(player, cpu);
      gs = engine.performAction(
        gs,
        _action('use', 'n'),
      );
      // 使用した1枚 + ペナルティで残り2枚破棄 = 全3枚 used。
      final usable = gs.player.hand.where((h) => !h.isUsed).length;
      expect(usable, 0);
      expect(gs.player.discardedCount, 2); // 使用分を除く残り2枚
      expect(gs.lastOutcome!.neutralPenalty, isTrue);
    });
  });

  group('CPUが不正な対象を選ばないこと', () {
    test('CPUは常にプレイヤーの人カードと未使用の生死カードを選ぶ', () {
      final strategy = DefaultCpuStrategy(random: Random(42));
      for (var seed = 0; seed < 30; seed++) {
        final engine = GameEngine(random: Random(seed));
        final gs = engine.startGame(Faction.good); // CPUは悪人
        final decision = strategy.decide(gs);
        expect(decision, isNotNull);
        final a = decision!.action;
        // 対象はプレイヤーの人カードでなければならない。
        expect(gs.player.persons.any((x) => x.id == a.targetPersonId), isTrue);
        expect(a.targetOwner, TurnOwner.player);
        // 使用カードは CPU の未使用手札でなければならない。
        expect(
          gs.cpu.hand.any((x) => x.id == a.lifeDeathCardId && !x.isUsed),
          isTrue,
        );
      }
    });

    test('CPUは終了判定に達するまで有効な行動を返し続ける', () {
      final engine = GameEngine(random: Random(7));
      final strategy = DefaultCpuStrategy(random: Random(7));
      var gs = engine.startGame(Faction.evil); // CPUは善人
      var guard = 0;
      while (gs.cpu.hasUsableCards && guard < 100) {
        final d = strategy.decide(gs);
        expect(d, isNotNull);
        expect(
          gs.cpu.hand.any((x) => x.id == d!.action.lifeDeathCardId && !x.isUsed),
          isTrue,
        );
        gs = engine.performAction(gs, d!.action);
        guard++;
      }
      expect(gs.cpu.hasUsableCards, isFalse);
    });
  });
}
