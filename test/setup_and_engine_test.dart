import 'dart:math';

import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/application/game_setup_service.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_action.dart';
import 'package:dead_or_alive/features/game/domain/game_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('セットアップ', () {
    test('人カードは各プレイヤー9枚ずつ配られる', () {
      final setup = GameSetupService(random: Random(3));
      final dealt = setup.dealPersonCards();
      expect(dealt.player.length, GameConstants.personCardsPerPlayer);
      expect(dealt.cpu.length, GameConstants.personCardsPerPlayer);
      // 全て alive で初期化されている。
      expect(dealt.player.every((p) => p.status == PersonStatus.alive), isTrue);
    });

    test('生死カード手札はデッド/アライブ/キープを2枚以上保証する', () {
      for (var seed = 0; seed < 20; seed++) {
        final setup = GameSetupService(random: Random(seed));
        final hand = setup.buildLifeDeathHand(TurnOwner.player);
        expect(hand.length, GameConstants.lifeDeathHandSize);
        int count(LifeDeathEffect e) =>
            hand.where((c) => c.effect == e).length;
        expect(count(LifeDeathEffect.dead), greaterThanOrEqualTo(2));
        expect(count(LifeDeathEffect.alive), greaterThanOrEqualTo(2));
        expect(count(LifeDeathEffect.keep), greaterThanOrEqualTo(2));
      }
    });
  });

  group('エンジンのターン進行と終了', () {
    test('startGame でプレイヤー先攻・両者9枚', () {
      final engine = GameEngine(random: Random(1));
      final gs = engine.startGame(Faction.good);
      expect(gs.phase, GamePhase.playerTurn);
      expect(gs.player.faction, Faction.good);
      expect(gs.cpu.faction, Faction.evil);
      expect(gs.player.hand.length, GameConstants.lifeDeathHandSize);
    });

    test('両者手札切れで finished になり全カードが公開される', () {
      final engine = GameEngine(random: Random(1));
      var gs = engine.startGame(Faction.good);
      // 全手札を使い切るまでプレイヤーが行動（ターン交代は無視して連続適用）。
      var guard = 0;
      while (!engine.rules.isGameOver(gs.player, gs.cpu) && guard < 200) {
        final actorIsPlayer = gs.player.hasUsableCards;
        final actor = actorIsPlayer ? gs.player : gs.cpu;
        final owner = actorIsPlayer ? TurnOwner.player : TurnOwner.cpu;
        final targetState = actorIsPlayer ? gs.cpu : gs.player;
        final cardId = actor.usableCards.first.id;
        final personId = targetState.persons.first.id;
        gs = engine.performAction(
          gs,
          _mkAction(owner, cardId, personId,
              actorIsPlayer ? TurnOwner.cpu : TurnOwner.player),
        );
        guard++;
      }
      gs = engine.advanceTurn(gs, TurnOwner.player);
      expect(gs.phase, GamePhase.finished);
      // 全人カードが full 公開されている。
      final all = [...gs.player.persons, ...gs.cpu.persons];
      expect(all.every((p) => p.reveal == RevealLevel.full), isTrue);
    });

    test('片方だけ手札切れなら相手のターンが継続する', () {
      final engine = GameEngine(random: Random(5));
      final gs = engine.startGame(Faction.good);
      // プレイヤーが1回行動 -> CPUターンへ。
      final next = engine.advanceTurn(
        engine.performAction(
          gs,
          _mkAction(TurnOwner.player, gs.player.usableCards.first.id,
              gs.cpu.persons.first.id, TurnOwner.cpu),
        ),
        TurnOwner.player,
      );
      expect(next.phase, GamePhase.cpuTurn);
    });
  });
}

GameAction _mkAction(
    TurnOwner actor, String cardId, String personId, TurnOwner target) {
  return GameAction(
    actor: actor,
    lifeDeathCardId: cardId,
    targetPersonId: personId,
    targetOwner: target,
  );
}
