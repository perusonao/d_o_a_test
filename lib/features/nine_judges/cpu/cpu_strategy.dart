import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class CpuSlotView {
  const CpuSlotView({
    required this.index,
    required this.person,
    this.knownAttribute,
  });

  final int index;
  final PersonCard person;
  final PersonAttribute? knownAttribute;
}

class CpuGameView {
  const CpuGameView({
    required this.faction,
    required this.slots,
    required this.legalTargets,
    required this.currentBonus,
    required this.specialVerdictAvailable,
    this.reverseActionAvailable = true,
    this.eyeUsesRemaining,
  });

  final Faction faction;
  final List<CpuSlotView> slots;
  final Map<ActionType, List<int>> legalTargets;
  final int? currentBonus;
  final bool specialVerdictAvailable;
  final bool reverseActionAvailable;

  /// EYE uses this faction has left this game, or `null` when the ruleset
  /// has no cap (rulesVersion 1.1).
  final int? eyeUsesRemaining;
}

/// One labelled contribution to a candidate's total score (e.g.
/// `('lockBonus', 8.5)`) — kept alongside the score itself so the CPU's
/// reasoning can be logged/inspected (debug dialog, `GameActionLog`)
/// without re-deriving it from scratch. Never influences gameplay; purely
/// explanatory.
class CpuScoreReason {
  const CpuScoreReason(this.key, this.value);
  final String key;
  final double value;
}

class CpuDecision {
  const CpuDecision({
    required this.action,
    required this.targetIndex,
    required this.score,
    this.reasons = const [],
  });
  final ActionType action;
  final int targetIndex;
  final double score;
  final List<CpuScoreReason> reasons;
}

class CpuCandidateScore {
  const CpuCandidateScore({
    required this.action,
    required this.targetIndex,
    required this.score,
    this.reasons = const [],
  });
  final ActionType action;
  final int targetIndex;
  final double score;
  final List<CpuScoreReason> reasons;
}

abstract interface class CpuStrategy {
  CpuDecision decideAction(CpuGameView view);
  List<CpuCandidateScore> evaluateActions(CpuGameView view);
}
