import 'dart:math';

import '../domain/cpu_decision.dart';
import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_constants.dart';
import '../domain/game_state.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';

/// CPU の意思決定を担う抽象クラス（Ver.0.3）。
/// 将来的に性格違いを追加できるようサブクラスで差し替え可能にする。
abstract class CpuStrategy {
  /// CPU（[owner]）の行動を決定する。有効な候補が無ければ null。
  CpuDecision? decide(GameState state, TurnOwner owner);
}

/// 各カードについて CPU が推定する数字の範囲。
class _NumberBound {
  _NumberBound(this.lo, this.hi);
  int lo;
  int hi;
  int get size => hi - lo + 1;
}

/// 標準 CPU 戦略。自分の既知カードと公開履歴からの推理を用いる。
class DefaultCpuStrategy implements CpuStrategy {
  DefaultCpuStrategy({Random? random, this.useSecretKnowledge = true})
      : _random = random ?? Random();

  final Random _random;

  /// 自分の秘密情報（既知カード）を判断に使うか。
  /// false にすると全カードを「未知」として扱う（情報の効果を測る比較用）。
  final bool useSecretKnowledge;

  /// 役割ごとの「望ましい最終状態」。
  PersonStatus _desired(PersonType type, Role role) {
    if (role == Role.savior) {
      // 善人は生存、悪人・中立は死亡させたい。
      return type == PersonType.good ? PersonStatus.alive : PersonStatus.dead;
    } else {
      // 執行者：善人は死亡、悪人・中立は生存させたい。
      return type == PersonType.good ? PersonStatus.dead : PersonStatus.alive;
    }
  }

  int _weight(PersonType type) => type == PersonType.good
      ? GameConstants.scoreGood
      : GameConstants.scoreSideEvil;

  /// 公開履歴と既知情報から、各位置の数字範囲を推定する。
  Map<int, _NumberBound> _bounds(GameState state, TurnOwner owner) {
    final bounds = <int, _NumberBound>{};
    for (final p in state.persons) {
      bounds[p.position] = _NumberBound(
          GameConstants.personNumberMin, GameConstants.personNumberMax);
    }
    // 履歴から絞り込み：成功(power P)→ number<=P、失敗(power P)→ number>=P+1。
    for (final a in state.history) {
      final b = bounds[a.position]!;
      if (a.targetSealed) continue;
      if (a.success) {
        if (a.number < b.hi) b.hi = a.number;
      } else {
        if (a.number + 1 > b.lo) b.lo = a.number + 1;
      }
    }
    // 自分が知るカードは確定（秘密情報を使う設定のときのみ）。
    if (useSecretKnowledge) {
      final self = owner == TurnOwner.player ? Knower.player : Knower.cpu;
      for (final p in state.persons) {
        if (p.knownBy == self) {
          bounds[p.position] = _NumberBound(p.number, p.number);
        }
      }
    }
    return bounds;
  }

  double _successProb(int cardNumber, _NumberBound b) {
    final ok = (cardNumber.clamp(b.lo, b.hi)) - b.lo + 1;
    if (cardNumber < b.lo) return 0;
    return ok / b.size;
  }

  @override
  CpuDecision? decide(GameState state, TurnOwner owner) {
    final self = state.stateOf(owner);
    final role = self.role;
    final usable = self.usableCards;
    if (usable.isEmpty) return null;
    final knower = owner == TurnOwner.player ? Knower.player : Knower.cpu;
    final bounds = _bounds(state, owner);

    CpuDecision? best;
    void consider(LifeDeathCard card, PersonCard person, double score,
        String reason) {
      if (best == null || score > best!.score) {
        best = CpuDecision(
          action: GameAction(
            actor: owner,
            lifeDeathCardId: card.id,
            targetPosition: person.position,
          ),
          score: score,
          reason: reason,
        );
      }
    }

    for (final card in usable) {
      for (final person in state.persons) {
        if (person.sealed) continue; // 封印済みは触れない。
        final b = bounds[person.position]!;
        final prob = _successProb(card.number, b);
        if (prob <= 0) continue;
        final conservation = card.number * 0.03;

        if (useSecretKnowledge && person.knownBy == knower) {
          // 既知カード：正体に基づき最適に動く。
          final desired = _desired(person.type, role);
          final w = _weight(person.type).toDouble();
          if (person.status != desired) {
            // 望ましい状態へ変える効果か？
            final need = desired == PersonStatus.dead
                ? LifeDeathEffect.dead
                : LifeDeathEffect.alive;
            if (card.effect == need) {
              consider(card, person, w * prob - conservation, '既知を是正');
            }
          } else {
            // 既に望ましい状態。シールで恒久固定（高価値カードほど有効）。
            if (card.effect == LifeDeathEffect.seal) {
              consider(card, person, w * 0.6 * prob - conservation, '既知を封印固定');
            }
          }
        } else {
          // 未知カード：期待値はほぼ中立。ごく小さな探索値のみ（成功しやすい対象を優先）。
          if (card.effect != LifeDeathEffect.seal) {
            consider(card, person, 0.02 * prob - conservation * 0.1, '未知を探索');
          }
        }
      }
    }

    if (best != null && best!.score > 0) return best;

    // 有効な候補が無ければ、成功可能な対象へフォールバック（ランダム性を少し混ぜる）。
    final candidates = <({LifeDeathCard c, PersonCard p, double prob})>[];
    for (final card in usable) {
      for (final person in state.persons) {
        if (person.sealed) continue;
        final prob = _successProb(card.number, bounds[person.position]!);
        if (prob > 0) candidates.add((c: card, p: person, prob: prob));
      }
    }
    if (candidates.isEmpty) {
      // どれも成功しない見込み。最小の数字カードを適当な未封印へ。
      final card = usable.reduce((a, b) => a.number <= b.number ? a : b);
      final targets = state.persons.where((p) => !p.sealed).toList();
      if (targets.isEmpty) return null;
      final t = targets[_random.nextInt(targets.length)];
      return CpuDecision(
        action: GameAction(
            actor: owner, lifeDeathCardId: card.id, targetPosition: t.position),
        score: 0,
        reason: 'フォールバック',
      );
    }
    candidates.sort((a, b) => b.prob.compareTo(a.prob));
    final pick = candidates[_random.nextInt(min(3, candidates.length))];
    return CpuDecision(
      action: GameAction(
          actor: owner,
          lifeDeathCardId: pick.c.id,
          targetPosition: pick.p.position),
      score: 0,
      reason: 'フォールバック(成功可能)',
    );
  }
}
