import '../domain/enums.dart';
import '../domain/game_constants.dart';
import '../domain/game_result.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';

/// 人カードへの効果適用結果（純粋計算の戻り値）。
class PersonResolution {
  const PersonResolution({
    required this.updatedCard,
    required this.success,
    required this.changed,
    required this.wasSealed,
  });

  final PersonCard updatedCard;
  final bool success;
  final bool changed;
  final bool wasSealed;
}

/// ゲームルールの純粋ロジック（Ver.0.3）。
///
/// パワー判定・効果適用・得点集計を提供する。Widget からは呼ばずエンジン経由で使う。
class GameRuleService {
  const GameRuleService();

  /// パワー判定。生死カードの数字が人カードの数字以上なら成功。
  bool judgePower(int lifeDeathNumber, int personNumber) {
    return lifeDeathNumber >= personNumber;
  }

  /// 生死カードを人カードに適用した結果を返す（純粋計算）。
  ///
  /// - 封印されたカードは、パワー成功でも状態を変更できない（changed=false）。
  /// - デッド/アライブは同状態なら変化なし（success は true でも changed=false）。
  /// - シールは成功で封印を付与（恒久固定）。
  PersonResolution applyEffect(PersonCard target, LifeDeathCard card) {
    final success = judgePower(card.number, target.number);
    final wasSealed = target.sealed;

    if (!success) {
      return PersonResolution(
        updatedCard: target,
        success: false,
        changed: false,
        wasSealed: wasSealed,
      );
    }

    // 封印済みは状態変更不可。
    if (wasSealed) {
      return PersonResolution(
        updatedCard: target,
        success: true,
        changed: false,
        wasSealed: true,
      );
    }

    switch (card.effect) {
      case LifeDeathEffect.dead:
        if (target.isDead) {
          return PersonResolution(
              updatedCard: target,
              success: true,
              changed: false,
              wasSealed: false);
        }
        return PersonResolution(
          updatedCard: target.copyWith(status: PersonStatus.dead),
          success: true,
          changed: true,
          wasSealed: false,
        );

      case LifeDeathEffect.alive:
        if (target.isAlive) {
          return PersonResolution(
              updatedCard: target,
              success: true,
              changed: false,
              wasSealed: false);
        }
        return PersonResolution(
          updatedCard: target.copyWith(status: PersonStatus.alive),
          success: true,
          changed: true,
          wasSealed: false,
        );

      case LifeDeathEffect.seal:
        return PersonResolution(
          updatedCard: target.copyWith(sealed: true),
          success: true,
          changed: true,
          wasSealed: false,
        );
    }
  }

  /// ゲーム終了判定：両者とも使用可能な生死カードが無い。
  bool isGameOver(bool playerHasCards, bool cpuHasCards) =>
      !playerHasCards && !cpuHasCards;

  /// 得点を集計して結果を返す（§11）。
  GameResult score(List<PersonCard> persons, Role playerRole) {
    int count(PersonType type, PersonStatus status) => persons
        .where((p) => p.type == type && p.status == status)
        .length;

    final aliveGood = count(PersonType.good, PersonStatus.alive);
    final aliveEvil = count(PersonType.evil, PersonStatus.alive);
    final aliveNeutral = count(PersonType.neutral, PersonStatus.alive);
    final deadGood = count(PersonType.good, PersonStatus.dead);
    final deadEvil = count(PersonType.evil, PersonStatus.dead);
    final deadNeutral = count(PersonType.neutral, PersonStatus.dead);

    final saviorScore = aliveGood * GameConstants.scoreGood +
        deadEvil * GameConstants.scoreSideEvil +
        deadNeutral * GameConstants.scoreSideNeutral;
    final executionerScore = deadGood * GameConstants.scoreGood +
        aliveEvil * GameConstants.scoreSideEvil +
        aliveNeutral * GameConstants.scoreSideNeutral;

    final Role? winnerRole = saviorScore > executionerScore
        ? Role.savior
        : executionerScore > saviorScore
            ? Role.executioner
            : null; // 同点は引き分け

    final playerScore =
        playerRole == Role.savior ? saviorScore : executionerScore;
    final cpuScore =
        playerRole == Role.savior ? executionerScore : saviorScore;

    return GameResult(
      saviorScore: saviorScore,
      executionerScore: executionerScore,
      winnerRole: winnerRole,
      playerRole: playerRole,
      playerScore: playerScore,
      cpuScore: cpuScore,
      aliveGood: aliveGood,
      aliveEvil: aliveEvil,
      aliveNeutral: aliveNeutral,
      deadGood: deadGood,
      deadEvil: deadEvil,
      deadNeutral: deadNeutral,
    );
  }
}
