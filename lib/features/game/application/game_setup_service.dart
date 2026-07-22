import 'dart:math';

import '../domain/enums.dart';
import '../domain/game_constants.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';

/// 対戦開始時のセットアップ処理（Ver.0.3）。
///
/// 中央9枚の生成・配置・秘密情報の割り当て、生死カード手札の生成を担当する。
class GameSetupService {
  GameSetupService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 中央の人カード9枚を生成し、秘密情報を割り当てる。
  ///
  /// 種類は善人3・悪人3・中立3、数字は 1〜9 を一意にランダム割り当て。
  /// プレイヤーと CPU に重複しない3枚ずつを既知として与え、残り3枚は誰も知らない。
  List<PersonCard> buildPersons() {
    final types = <PersonType>[
      for (var i = 0; i < GameConstants.perTypeCount; i++) PersonType.good,
      for (var i = 0; i < GameConstants.perTypeCount; i++) PersonType.evil,
      for (var i = 0; i < GameConstants.perTypeCount; i++) PersonType.neutral,
    ]..shuffle(_random);

    final numbers = List<int>.generate(
      GameConstants.personNumberMax - GameConstants.personNumberMin + 1,
      (i) => GameConstants.personNumberMin + i,
    )..shuffle(_random);

    // 秘密情報の割り当て：位置 0..8 をシャッフルし、前半をプレイヤー、次を CPU に。
    final positions =
        List<int>.generate(GameConstants.personCardCount, (i) => i)
          ..shuffle(_random);
    final playerKnown =
        positions.take(GameConstants.secretKnownPerPlayer).toSet();
    final cpuKnown = positions
        .skip(GameConstants.secretKnownPerPlayer)
        .take(GameConstants.secretKnownPerPlayer)
        .toSet();

    final persons = <PersonCard>[];
    for (var pos = 0; pos < GameConstants.personCardCount; pos++) {
      final knownBy = playerKnown.contains(pos)
          ? Knower.player
          : cpuKnown.contains(pos)
              ? Knower.cpu
              : Knower.none;
      persons.add(
        PersonCard(
          id: 'person_$pos',
          position: pos,
          type: types[pos],
          number: numbers[pos],
          status: PersonStatus.alive,
          sealed: false,
          knownBy: knownBy,
        ),
      );
    }
    return persons;
  }

  /// 役割に応じた生死カード手札を生成する（両者同一の固定配分・§12）。
  /// 弱い役は7枚、強い役は6枚（先手・最終手番・+1アクションで補正）。
  List<LifeDeathCard> buildLifeDeathHand(TurnOwner owner, Role role) {
    final template =
        role == GameConstants.weakRole ? GameConstants.weakHand : GameConstants.strongHand;
    final hand = <LifeDeathCard>[];
    for (var i = 0; i < template.length; i++) {
      hand.add(
        LifeDeathCard(
          id: 'ld_${owner.name}_$i',
          effect: template[i].effect,
          number: template[i].number,
          owner: owner,
          isUsed: false,
        ),
      );
    }
    return hand;
  }
}
