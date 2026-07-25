import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class CpuSlotView {
  const CpuSlotView({
    required this.index,
    required this.person,
    required this.knownNumber,
    this.knownAttribute,
    this.eyeOptions = const [],
  });

  final int index;
  final PersonCard person;
  final int? knownNumber;
  final PersonAttribute? knownAttribute;
  final List<EyeInformation> eyeOptions;
}

class CpuGameView {
  const CpuGameView({
    required this.faction,
    required this.slots,
    required this.inventory,
    required this.unknownNumberCandidates,
    required this.legalTargets,
  });

  final Faction faction;
  final List<CpuSlotView> slots;
  final ActionInventory inventory;
  final Set<int> unknownNumberCandidates;
  final Map<ActionType, List<int>> legalTargets;
}

class CpuDecision {
  const CpuDecision({
    required this.action,
    required this.targetIndex,
    required this.score,
    this.eyeInformation,
  });

  final ActionType action;
  final int targetIndex;
  final double score;
  final EyeInformation? eyeInformation;
}

class CpuCandidateScore {
  const CpuCandidateScore({
    required this.action,
    required this.targetIndex,
    required this.score,
    this.eyeInformation,
  });

  final ActionType action;
  final int targetIndex;
  final double score;
  final EyeInformation? eyeInformation;
}

abstract interface class CpuStrategy {
  CpuDecision decideAction(CpuGameView view);
  List<CpuCandidateScore> evaluateActions(CpuGameView view);
}
