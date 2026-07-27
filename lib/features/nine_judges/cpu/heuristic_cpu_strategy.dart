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
    final selected = candidates.first;
    return CpuDecision(
      action: selected.action,
      targetIndex: selected.targetIndex,
      score: selected.score,
    );
  }

  @override
  List<CpuCandidateScore> evaluateActions(CpuGameView view) {
    final bonus = (view.currentBonus ?? 5).toDouble();
    final random = _random;
    return [
      for (final entry in view.legalTargets.entries)
        for (final target in entry.value)
          () {
            var score = CpuEvaluator.actionScore(
              view,
              entry.key,
              view.slots[target],
              profile: profile,
            );
            if (profile.threatWeight > 0) {
              final after = _projectedBoard(view, entry.key, target);
              score -=
                  profile.threatWeight *
                  CpuEvaluator.opponentThreat(after, view.faction, bonus);
            }
            if (random != null && profile.jitter > 0) {
              score += random.nextDouble() * profile.jitter;
            }
            return CpuCandidateScore(
              action: entry.key,
              targetIndex: target,
              score: score,
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
