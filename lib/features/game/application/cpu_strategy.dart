import 'dart:math';

import '../domain/cpu_decision.dart';
import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_constants.dart';
import '../domain/game_state.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';

/// CPU の意思決定を担う抽象クラス。
///
/// 将来的に慎重型・強気型・ブラフ型などを追加できるよう、
/// [decide] を実装したサブクラスを差し替えられる設計にしている。
abstract class CpuStrategy {
  /// CPU の行動を決定する。有効な候補が無い場合は null を返す（パス扱い）。
  CpuDecision? decide(GameState state);
}

/// 1つの (生死カード × 対象人カード) の組み合わせを評価するクラス。
class CpuActionEvaluator {
  const CpuActionEvaluator();

  /// スコアを評価する。高いほど CPU にとって望ましい。
  ///
  /// - [cpuFaction]: CPU の陣営。
  /// - [card]: 使用を検討する生死カード。
  /// - [target]: 対象となるプレイヤー側の人カード（公開情報のみ参照）。
  double evaluate({
    required Faction cpuFaction,
    required LifeDeathCard card,
    required PersonCard target,
  }) {
    // CPU から見えている情報のみ使用する。
    final knowsNumber = target.reveal != RevealLevel.none;
    final knowsType = target.reveal == RevealLevel.full;

    // 成功確率の推定。
    final double successProb;
    if (knowsNumber) {
      successProb = card.number >= target.number ? 1.0 : 0.0;
    } else {
      // 数字未知：1..9 のうち card.number 以下の割合。
      successProb = card.number / GameConstants.personNumberMax;
    }

    // 効果による陣営利得の期待値。
    final benefit = _benefit(
      cpuFaction: cpuFaction,
      effect: card.effect,
      target: target,
      knowsType: knowsType,
    );

    // カード温存：高い数字を無駄に使わないよう軽く減点。
    final conservation = card.number * 0.05;

    return benefit * successProb - conservation;
  }

  /// 効果を成功させた場合の陣営利得。
  double _benefit({
    required Faction cpuFaction,
    required LifeDeathEffect effect,
    required PersonCard target,
    required bool knowsType,
  }) {
    // 種類が分からない場合は期待値ベース（善/悪/中立が等確率と仮定）。
    if (!knowsType) {
      switch (effect) {
        case LifeDeathEffect.keep:
          // 未知カードへのキープはほぼ価値が薄い。
          return 0.1;
        case LifeDeathEffect.dead:
        case LifeDeathEffect.alive:
          // 期待利得はほぼ 0。ただし情報公開の価値として僅かに加点。
          return 0.3;
      }
    }

    final favored = cpuFaction == Faction.good ? PersonType.good : PersonType.evil;
    final opposed = cpuFaction == Faction.good ? PersonType.evil : PersonType.good;

    switch (effect) {
      case LifeDeathEffect.dead:
        if (target.type == opposed) {
          // 相手条件のカードを消せる：大きな利得（既に dead なら小さい）。
          return target.isDead ? 0.2 : 3.0;
        }
        if (target.type == favored) {
          // 自陣条件のカードを殺すのは悪手。
          return target.isDead ? -0.5 : -3.0;
        }
        // 中立を dead に。
        if (cpuFaction == Faction.good) {
          // 善人陣営が中立を殺すとペナルティ。
          return -4.0;
        }
        return 0.0; // 悪人陣営が中立を殺してもペナルティなし・利得なし。

      case LifeDeathEffect.alive:
        if (target.type == favored) {
          return target.isAlive ? 0.2 : 3.0; // 自陣カードを復活。
        }
        if (target.type == opposed) {
          return target.isAlive ? -0.5 : -3.0; // 相手カードを復活させるのは悪手。
        }
        // 中立を alive に。
        if (cpuFaction == Faction.evil) {
          return -4.0; // 悪人陣営が中立を生かすとペナルティ。
        }
        return 0.0;

      case LifeDeathEffect.keep:
        // 現在 CPU にとって望ましい状態の重要カードを守る。
        if (target.type == favored && target.isAlive) {
          return 1.5; // 生存中の自陣カードを守る。
        }
        if (target.type == opposed && target.isDead) {
          return 1.0; // 死亡させた相手カードの復活を防ぐ。
        }
        return 0.2;
    }
  }
}

/// 標準的な CPU 戦略。最低限の合理的判断を行う。
class DefaultCpuStrategy implements CpuStrategy {
  DefaultCpuStrategy({Random? random, CpuActionEvaluator? evaluator})
      : _random = random ?? Random(),
        _evaluator = evaluator ?? const CpuActionEvaluator();

  final Random _random;
  final CpuActionEvaluator _evaluator;

  @override
  CpuDecision? decide(GameState state) {
    final cpu = state.cpu;
    final targets = state.player.persons; // CPU はプレイヤーの場を対象にする。
    final usable = cpu.usableCards;
    if (usable.isEmpty || targets.isEmpty) return null;

    CpuDecision? best;
    for (final card in usable) {
      for (final target in targets) {
        final score = _evaluator.evaluate(
          cpuFaction: cpu.faction,
          card: card,
          target: target,
        );
        if (best == null || score > best.score) {
          best = CpuDecision(
            action: GameAction(
              actor: TurnOwner.cpu,
              lifeDeathCardId: card.id,
              targetPersonId: target.id,
              targetOwner: TurnOwner.player,
            ),
            score: score,
            reason: 'score=${score.toStringAsFixed(2)}',
          );
        }
      }
    }

    // 有効な候補（正のスコア）が無ければランダムに選択する。
    if (best == null || best.score <= 0) {
      final card = usable[_random.nextInt(usable.length)];
      final target = targets[_random.nextInt(targets.length)];
      return CpuDecision(
        action: GameAction(
          actor: TurnOwner.cpu,
          lifeDeathCardId: card.id,
          targetPersonId: target.id,
          targetOwner: TurnOwner.player,
        ),
        score: 0,
        reason: 'ランダム選択',
      );
    }
    return best;
  }
}
