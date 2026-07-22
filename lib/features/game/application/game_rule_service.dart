import '../domain/enums.dart';
import '../domain/game_result.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';
import '../domain/player_state.dart';

/// 人カードへの効果適用結果（純粋計算の戻り値）。
class PersonResolution {
  const PersonResolution({
    required this.updatedCard,
    required this.success,
    required this.guardBlocked,
    required this.becameDead,
    required this.becameAlive,
  });

  /// 効果適用後の人カード。
  final PersonCard updatedCard;

  /// パワー判定に成功したか。
  final bool success;

  /// キープ防御で dead/alive が無効化されたか。
  final bool guardBlocked;

  /// この効果で dead 状態に変化したか（中立ペナルティ判定に使用）。
  final bool becameDead;

  /// この効果で alive 状態に変化したか（中立ペナルティ判定に使用）。
  final bool becameAlive;
}

/// ゲームルールの純粋ロジックを担うサービス。
///
/// パワー判定・効果適用・情報公開・ペナルティ判定・勝敗判定を提供する。
/// Widget からは呼ばず、エンジン経由で使用する。
class GameRuleService {
  const GameRuleService();

  /// パワー判定。生死カードの数字が人カードの数字以上なら成功。
  bool judgePower(int lifeDeathNumber, int personNumber) {
    return lifeDeathNumber >= personNumber;
  }

  /// 生死カードを人カードに適用した結果を返す（純粋計算）。
  PersonResolution applyEffect(PersonCard target, LifeDeathCard card) {
    final success = judgePower(card.number, target.number);

    // 情報公開レベルの決定：成功なら種類+数字、失敗なら数字のみ。
    final revealLevel = success ? RevealLevel.full : RevealLevel.numberOnly;

    if (!success) {
      // 失敗：状態は変化しない。数字のみ公開。
      return PersonResolution(
        updatedCard: target.revealAtLeast(revealLevel),
        success: false,
        guardBlocked: false,
        becameDead: false,
        becameAlive: false,
      );
    }

    // 成功時：種類+数字を公開。
    var revealed = target.revealAtLeast(revealLevel);

    switch (card.effect) {
      case LifeDeathEffect.keep:
        // キープ成功：防御を付与（更新）。中立ペナルティは発生しない。
        return PersonResolution(
          updatedCard: revealed.copyWith(isGuarded: true),
          success: true,
          guardBlocked: false,
          becameDead: false,
          becameAlive: false,
        );

      case LifeDeathEffect.dead:
        if (revealed.isGuarded) {
          // 防御中：効果を無効化し防御解除。
          return PersonResolution(
            updatedCard: revealed.copyWith(isGuarded: false),
            success: true,
            guardBlocked: true,
            becameDead: false,
            becameAlive: false,
          );
        }
        final wasDead = revealed.isDead;
        return PersonResolution(
          updatedCard: revealed.copyWith(status: PersonStatus.dead),
          success: true,
          guardBlocked: false,
          becameDead: !wasDead,
          becameAlive: false,
        );

      case LifeDeathEffect.alive:
        if (revealed.isGuarded) {
          return PersonResolution(
            updatedCard: revealed.copyWith(isGuarded: false),
            success: true,
            guardBlocked: true,
            becameDead: false,
            becameAlive: false,
          );
        }
        final wasAlive = revealed.isAlive;
        return PersonResolution(
          updatedCard: revealed.copyWith(status: PersonStatus.alive),
          success: true,
          guardBlocked: false,
          becameDead: false,
          becameAlive: !wasAlive,
        );
    }
  }

  /// 中立ペナルティが発生するか判定する。
  ///
  /// 善人陣営が中立を dead に、悪人陣営が中立を alive にした場合に発生。
  /// キープでは発生しない（becameDead/becameAlive が false のため）。
  bool isNeutralPenalty({
    required Faction actorFaction,
    required PersonCard target,
    required bool becameDead,
    required bool becameAlive,
  }) {
    if (target.type != PersonType.neutral) return false;
    if (actorFaction == Faction.good && becameDead) return true;
    if (actorFaction == Faction.evil && becameAlive) return true;
    return false;
  }

  /// ゲーム終了判定：両者とも使用可能な生死カードが無い。
  bool isGameOver(PlayerState player, PlayerState cpu) {
    return !player.hasUsableCards && !cpu.hasUsableCards;
  }

  /// 全人カードの情報を種類+数字まで公開する（ゲーム終了時に使用）。
  List<PersonCard> revealAll(List<PersonCard> persons) {
    return persons
        .map((p) => p.revealAtLeast(RevealLevel.full))
        .toList(growable: false);
  }

  /// 勝敗を判定し集計結果を返す。
  ///
  /// 善人陣営: alive の善人 > alive の悪人 で勝利。
  /// 悪人陣営: alive の悪人 >= alive の善人 で勝利。
  /// 中立は勝敗人数に含めない。引き分けは悪人陣営の勝利。
  GameResult judgeResult(PlayerState player, PlayerState cpu) {
    final all = [...player.persons, ...cpu.persons];

    int count(PersonType type, PersonStatus status) => all
        .where((p) => p.type == type && p.status == status)
        .length;

    final aliveGood = count(PersonType.good, PersonStatus.alive);
    final aliveEvil = count(PersonType.evil, PersonStatus.alive);
    final aliveNeutral = count(PersonType.neutral, PersonStatus.alive);
    final deadGood = count(PersonType.good, PersonStatus.dead);
    final deadEvil = count(PersonType.evil, PersonStatus.dead);
    final deadNeutral = count(PersonType.neutral, PersonStatus.dead);

    // 善人陣営の勝利条件。引き分け（同数）は悪人勝利なので > を使う。
    final goodWins = aliveGood > aliveEvil;
    final winner = goodWins ? Faction.good : Faction.evil;
    final playerWon = winner == player.faction;

    return GameResult(
      winner: winner,
      playerFaction: player.faction,
      aliveGood: aliveGood,
      aliveEvil: aliveEvil,
      aliveNeutral: aliveNeutral,
      deadGood: deadGood,
      deadEvil: deadEvil,
      deadNeutral: deadNeutral,
      usedCardsTotal: player.usedCount + cpu.usedCount,
      discardedTotal: player.discardedCount + cpu.discardedCount,
      playerWon: playerWon,
    );
  }
}
