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
  });

  final Faction faction;
  final List<CpuSlotView> slots;
  final Map<ActionType, List<int>> legalTargets;
  final int? currentBonus;
  final bool specialVerdictAvailable;
  final bool reverseActionAvailable;
}

class CpuDecision {
  const CpuDecision({
    required this.action,
    required this.targetIndex,
    required this.score,
  });
  final ActionType action;
  final int targetIndex;
  final double score;
}

class CpuCandidateScore {
  const CpuCandidateScore({
    required this.action,
    required this.targetIndex,
    required this.score,
  });
  final ActionType action;
  final int targetIndex;
  final double score;
}

abstract interface class CpuStrategy {
  CpuDecision decideAction(CpuGameView view);
  List<CpuCandidateScore> evaluateActions(CpuGameView view);
}
