import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class SimulationActionRecord {
  const SimulationActionRecord({
    required this.turn,
    required this.faction,
    required this.action,
    required this.targetIndex,
    required this.wasReverseAction,
    required this.actorKnewAttributeBefore,
    required this.stateBefore,
    required this.stateAfter,
    required this.historyBefore,
    required this.historyAfter,
    required this.targetAttribute,
    required this.currentBonusValue,
    required this.currentBonusKnown,
    this.verdictBonus,
    this.scoringFaction,
    this.confirmationOrder,
  });

  final int turn;
  final Faction faction;
  final ActionType action;
  final int targetIndex;
  final bool wasReverseAction;
  final bool actorKnewAttributeBefore;
  final VerdictState stateBefore;
  final VerdictState stateAfter;
  final List<VerdictActionType> historyBefore;
  final List<VerdictActionType> historyAfter;
  final PersonAttribute targetAttribute;
  final int currentBonusValue;
  final bool currentBonusKnown;
  final int? verdictBonus;
  final Faction? scoringFaction;
  final int? confirmationOrder;

  bool get confirmedThisAction =>
      !stateBefore.isConfirmed && stateAfter.isConfirmed;
}

class SimulationResult {
  const SimulationResult({
    required this.gameIndex,
    required this.seed,
    required this.winner,
    required this.firstPlayer,
    required this.saviorScore,
    required this.executorScore,
    required this.totalTurns,
    required this.endReason,
    required this.saviorEyeCount,
    required this.executorEyeCount,
    required this.saviorLifeCount,
    required this.executorLifeCount,
    required this.saviorDeathCount,
    required this.executorDeathCount,
    required this.saviorJudgeUsed,
    required this.executorJudgeUsed,
    required this.saviorReverseUsed,
    required this.executorReverseUsed,
    required this.saviorReverseTurn,
    required this.executorReverseTurn,
    required this.confirmedBySavior,
    required this.confirmedByExecutor,
    required this.contestedPersonCount,
    required this.lifeDeathFlipCount,
    required this.thirdActionConfirmationCount,
    required this.instantJudgeConfirmationCount,
    required this.eyeUniqueTargetsSavior,
    required this.eyeUniqueTargetsExecutor,
    required this.eyeRedundantCountSavior,
    required this.eyeRedundantCountExecutor,
    required this.maxVerdictHistoryLength,
    required this.bonusValuesWonBySavior,
    required this.bonusValuesWonByExecutor,
    required this.highBonusWonBySavior,
    required this.highBonusWonByExecutor,
    required this.judgeBonuses,
    required this.reverseOutcomeChangedCount,
    required this.finalConfirmedCount,
    required this.saviorNaturalConfirmationCount,
    required this.executorNaturalConfirmationCount,
    required this.actions,
  });

  final int gameIndex;
  final int seed;
  final Faction? winner;
  final Faction firstPlayer;
  final int saviorScore;
  final int executorScore;
  final int totalTurns;
  final String endReason;
  final int saviorEyeCount;
  final int executorEyeCount;
  final int saviorLifeCount;
  final int executorLifeCount;
  final int saviorDeathCount;
  final int executorDeathCount;
  final bool saviorJudgeUsed;
  final bool executorJudgeUsed;
  final bool saviorReverseUsed;
  final bool executorReverseUsed;
  final int? saviorReverseTurn;
  final int? executorReverseTurn;
  final int confirmedBySavior;
  final int confirmedByExecutor;
  final int contestedPersonCount;
  final int lifeDeathFlipCount;
  final int thirdActionConfirmationCount;
  final int instantJudgeConfirmationCount;
  final int eyeUniqueTargetsSavior;
  final int eyeUniqueTargetsExecutor;
  final int eyeRedundantCountSavior;
  final int eyeRedundantCountExecutor;
  final int maxVerdictHistoryLength;
  final List<int> bonusValuesWonBySavior;
  final List<int> bonusValuesWonByExecutor;
  final int highBonusWonBySavior;
  final int highBonusWonByExecutor;
  final List<int> judgeBonuses;
  final int reverseOutcomeChangedCount;
  final int finalConfirmedCount;

  /// "SPECIAL VERDICT" (see SimulationRuleFlags) — confirmations sealed by
  /// a normal LIFE/DEATH action rather than JUDGE, attributed to whichever
  /// faction took that confirming action.
  final int saviorNaturalConfirmationCount;
  final int executorNaturalConfirmationCount;
  final List<SimulationActionRecord> actions;

  int get scoreDiff => saviorScore - executorScore;
  int get absoluteScoreDiff => scoreDiff.abs();
  int get totalEyeCount => saviorEyeCount + executorEyeCount;
  int get totalRedundantEyeCount =>
      eyeRedundantCountSavior + eyeRedundantCountExecutor;
  int get totalUsefulEyeCount => totalEyeCount - totalRedundantEyeCount;

  Map<String, Object?> toJson() => {
    'gameIndex': gameIndex,
    'seed': seed,
    'winner': winner?.name ?? 'draw',
    'firstPlayer': firstPlayer.name,
    'saviorScore': saviorScore,
    'executorScore': executorScore,
    'scoreDiff': scoreDiff,
    'totalTurns': totalTurns,
    'endReason': endReason,
    'saviorEyeCount': saviorEyeCount,
    'executorEyeCount': executorEyeCount,
    'saviorLifeCount': saviorLifeCount,
    'executorLifeCount': executorLifeCount,
    'saviorDeathCount': saviorDeathCount,
    'executorDeathCount': executorDeathCount,
    'saviorJudgeUsed': saviorJudgeUsed,
    'executorJudgeUsed': executorJudgeUsed,
    'saviorReverseUsed': saviorReverseUsed,
    'executorReverseUsed': executorReverseUsed,
    'saviorReverseTurn': saviorReverseTurn,
    'executorReverseTurn': executorReverseTurn,
    'confirmedBySavior': confirmedBySavior,
    'confirmedByExecutor': confirmedByExecutor,
    'contestedPersonCount': contestedPersonCount,
    'lifeDeathFlipCount': lifeDeathFlipCount,
    'thirdActionConfirmationCount': thirdActionConfirmationCount,
    'instantJudgeConfirmationCount': instantJudgeConfirmationCount,
    'eyeUniqueTargetsSavior': eyeUniqueTargetsSavior,
    'eyeUniqueTargetsExecutor': eyeUniqueTargetsExecutor,
    'eyeRedundantCountSavior': eyeRedundantCountSavior,
    'eyeRedundantCountExecutor': eyeRedundantCountExecutor,
    'maxVerdictHistoryLength': maxVerdictHistoryLength,
    'bonusValuesWonBySavior': bonusValuesWonBySavior,
    'bonusValuesWonByExecutor': bonusValuesWonByExecutor,
    'highBonusWonBySavior': highBonusWonBySavior,
    'highBonusWonByExecutor': highBonusWonByExecutor,
    'judgeBonuses': judgeBonuses,
    'reverseOutcomeChangedCount': reverseOutcomeChangedCount,
    'finalConfirmedCount': finalConfirmedCount,
    'saviorNaturalConfirmationCount': saviorNaturalConfirmationCount,
    'executorNaturalConfirmationCount': executorNaturalConfirmationCount,
  };
}
