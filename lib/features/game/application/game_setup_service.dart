import 'dart:math';

import '../domain/enums.dart';
import '../domain/game_constants.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';

/// 対戦開始時のセットアップ処理をまとめたサービス。
///
/// 人カードの生成・配布、生死カード手札の生成を担当する。
/// 「5枚シャッフル・スワップ」など将来のルールはこのクラスに追加できるよう独立させている。
class GameSetupService {
  GameSetupService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 27枚の人カード（善人1-9 / 悪人1-9 / 中立1-9）を生成する。
  /// owner は配布時に確定するため、ここでは仮の所有者を入れて後で複製する。
  List<PersonCard> buildAllPersonCards() {
    final cards = <PersonCard>[];
    for (final type in PersonType.values) {
      for (var n = GameConstants.personNumberMin;
          n <= GameConstants.personNumberMax;
          n++) {
        cards.add(
          PersonCard(
            id: 'person_${type.name}_$n',
            type: type,
            number: n,
            status: PersonStatus.alive, // 初期状態は alive
            reveal: RevealLevel.none,
            owner: TurnOwner.player, // 仮。dealPersonCards で確定させる。
          ),
        );
      }
    }
    return cards;
  }

  /// 人カード27枚をシャッフルし、プレイヤーとCPUに9枚ずつ配る。
  /// 残り9枚はこのゲームでは使用しない。
  ///
  /// 戻り値は (playerPersons, cpuPersons)。
  ({List<PersonCard> player, List<PersonCard> cpu}) dealPersonCards() {
    final all = buildAllPersonCards()..shuffle(_random);
    final playerRaw = all.sublist(0, GameConstants.personCardsPerPlayer);
    final cpuRaw = all.sublist(
      GameConstants.personCardsPerPlayer,
      GameConstants.personCardsPerPlayer * 2,
    );

    final player = <PersonCard>[];
    for (var i = 0; i < playerRaw.length; i++) {
      player.add(_reassign(playerRaw[i], TurnOwner.player, i));
    }
    final cpu = <PersonCard>[];
    for (var i = 0; i < cpuRaw.length; i++) {
      cpu.add(_reassign(cpuRaw[i], TurnOwner.cpu, i));
    }
    return (player: player, cpu: cpu);
  }

  PersonCard _reassign(PersonCard c, TurnOwner owner, int index) {
    return PersonCard(
      id: 'person_${owner.name}_$index',
      type: c.type,
      number: c.number,
      status: PersonStatus.alive,
      reveal: RevealLevel.none,
      owner: owner,
    );
  }

  /// 生死カードの手札を生成する。
  ///
  /// デッド・アライブ・キープを最低2枚ずつ保証し、残りはランダム。
  /// 将来的な正式デッキ構成へ差し替えやすいよう独立関数にしている。
  List<LifeDeathCard> buildLifeDeathHand(TurnOwner owner) {
    final effects = <LifeDeathEffect>[];

    void addGuaranteed(LifeDeathEffect effect, int count) {
      for (var i = 0; i < count; i++) {
        effects.add(effect);
      }
    }

    addGuaranteed(LifeDeathEffect.dead, GameConstants.minDeadCards);
    addGuaranteed(LifeDeathEffect.alive, GameConstants.minAliveCards);
    addGuaranteed(LifeDeathEffect.keep, GameConstants.minKeepCards);

    final remaining = GameConstants.lifeDeathHandSize - effects.length;
    for (var i = 0; i < remaining; i++) {
      effects.add(
        LifeDeathEffect.values[_random.nextInt(LifeDeathEffect.values.length)],
      );
    }

    effects.shuffle(_random);

    final hand = <LifeDeathCard>[];
    for (var i = 0; i < effects.length; i++) {
      final number = GameConstants.lifeDeathNumberMin +
          _random.nextInt(GameConstants.lifeDeathNumberMax -
              GameConstants.lifeDeathNumberMin +
              1);
      hand.add(
        LifeDeathCard(
          id: 'ld_${owner.name}_$i',
          effect: effects[i],
          number: number,
          isUsed: false,
        ),
      );
    }
    return hand;
  }
}
