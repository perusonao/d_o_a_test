import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_evaluator.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

/// Weight-driven CPU. A single evaluation core produces every personality by
/// swapping the [CpuProfile]. When [CpuProfile.threatWeight] is positive it
/// also runs a one-ply lookahead that discounts moves leaving the opponent an
/// immediate point ("expert" pattern).
class HeuristicCpuStrategy implements CpuStrategy {
  const HeuristicCpuStrategy(this.profile, [this._random]);

  final CpuProfile profile;
  final Random? _random;

  @override
  CpuDecision decideAction(CpuGameView view) {
    final candidates = evaluateActions(view)
      ..sort((a, b) => b.score.compareTo(a.score));
    final selected = _select(candidates);
    return CpuDecision(
      action: selected.action,
      targetIndex: selected.targetIndex,
      score: selected.score,
      reasons: selected.reasons,
    );
  }

  /// Section 14/15: rather than always taking the literal best move, sample
  /// among the top-ranked candidates according to [CpuProfile.selectionWeights]
  /// — the same shared, seeded [Random] every other CPU decision uses, so a
  /// fixed seed still reproduces the exact same sequence of choices. Falls
  /// back to the single best candidate whenever no [_random] was supplied
  /// (e.g. simulation/test call sites that construct a strategy without one).
  CpuCandidateScore _select(List<CpuCandidateScore> candidates) {
    final random = _random;
    final weights = profile.selectionWeights;
    if (random == null || weights.length <= 1 || candidates.length <= 1) {
      return candidates.first;
    }
    final roll = random.nextDouble();
    var cumulative = 0.0;
    for (var i = 0; i < weights.length && i < candidates.length; i++) {
      cumulative += weights[i];
      if (roll < cumulative) return candidates[i];
    }
    return candidates.first;
  }

  @override
  List<CpuCandidateScore> evaluateActions(CpuGameView view) {
    final bonus = (view.currentBonus ?? 5).toDouble();
    final random = _random;
    return [
      for (final entry in view.legalTargets.entries)
        for (final target in entry.value)
          () {
            final scored = CpuEvaluator.actionScoreDetailed(
              view,
              entry.key,
              view.slots[target],
              profile: profile,
            );
            var score = scored.score;
            final reasons = [...scored.reasons];
            if (profile.threatWeight > 0) {
              final after = _projectedBoard(view, entry.key, target);
              final threat = CpuEvaluator.opponentThreat(after, view.faction, bonus);
              if (threat > 0) {
                final threatAdjustment = -profile.threatWeight * threat;
                score += threatAdjustment;
                reasons.add(CpuScoreReason('opponentThreat', threatAdjustment));
              }
            }
            if (random != null && profile.jitter > 0) {
              final jitterValue = random.nextDouble() * profile.jitter;
              score += jitterValue;
              reasons.add(CpuScoreReason('jitter', jitterValue));
            }
            return CpuCandidateScore(
              action: entry.key,
              targetIndex: target,
              score: score,
              reasons: reasons,
            );
          }(),
    ];
  }

  /// The board as it would look right after the CPU plays [action] on [target],
  /// used only to reason about the opponent's reply. EYE does not change any
  /// person's state, so the board is returned unchanged for it.
  List<CpuSlotView> _projectedBoard(
    CpuGameView view,
    ActionType action,
    int target,
  ) {
    if (action == ActionType.eye) return view.slots;
    final slot = view.slots[target];
    final after = switch (action) {
      ActionType.specialVerdict => NineJudgesRules.applySpecialVerdict(
        person: slot.person,
        actor: view.faction,
      ),
      _ => NineJudgesRules.applyVerdictAction(
        person: slot.person,
        action: action,
        actor: view.faction,
      ),
    };
    return [
      for (final s in view.slots)
        if (s.index == target)
          CpuSlotView(
            index: s.index,
            person: after,
            knownAttribute: s.knownAttribute,
          )
        else
          s,
    ];
  }
}
