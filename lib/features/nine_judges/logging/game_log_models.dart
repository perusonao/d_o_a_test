import 'dart:convert';

class LoggedPerson {
  const LoggedPerson({
    required this.personId,
    required this.attribute,
    required this.rank,
    required this.initialAlive,
    required this.positionIndex,
    this.finalAlive,
    this.judged,
    this.judgedBy,
    this.judgedTurn,
    this.lifeShieldRemaining,
    this.scoringFaction,
    this.scoreValue,
    this.eyeSeenBySavior = false,
    this.eyeSeenByExecutor = false,
    this.verdictState,
    this.verdictActionCount = 0,
    this.awardedBonus,
    this.verdictHistory = const [],
  });

  final String personId;
  final String attribute;
  final int rank;
  final bool initialAlive;
  final int positionIndex;
  final bool? finalAlive;
  final bool? judged;
  final String? judgedBy;
  final int? judgedTurn;
  final bool? lifeShieldRemaining;
  final String? scoringFaction;
  final int? scoreValue;
  final bool eyeSeenBySavior;
  final bool eyeSeenByExecutor;
  final String? verdictState;
  final int verdictActionCount;
  final int? awardedBonus;
  final List<String> verdictHistory;

  Map<String, dynamic> toJson() => {
    'personId': personId,
    'attribute': attribute,
    'rank': rank,
    'initialAlive': initialAlive,
    'positionIndex': positionIndex,
    'finalAlive': finalAlive,
    'judged': judged,
    'judgedBy': judgedBy,
    'judgedTurn': judgedTurn,
    'lifeShieldRemaining': lifeShieldRemaining,
    'scoringFaction': scoringFaction,
    'scoreValue': scoreValue,
    'eyeSeenBySavior': eyeSeenBySavior,
    'eyeSeenByExecutor': eyeSeenByExecutor,
    'verdictState': verdictState,
    'verdictActionCount': verdictActionCount,
    'awardedBonus': awardedBonus,
    'verdictHistory': verdictHistory,
  };

  factory LoggedPerson.fromJson(Map<String, dynamic> json) => LoggedPerson(
    personId: json['personId'] as String,
    attribute: json['attribute'] as String,
    rank: json['rank'] as int,
    initialAlive: json['initialAlive'] as bool,
    positionIndex: json['positionIndex'] as int,
    finalAlive: json['finalAlive'] as bool?,
    judged: json['judged'] as bool?,
    judgedBy: json['judgedBy'] as String?,
    judgedTurn: json['judgedTurn'] as int?,
    lifeShieldRemaining: json['lifeShieldRemaining'] as bool?,
    scoringFaction: json['scoringFaction'] as String?,
    scoreValue: json['scoreValue'] as int?,
    eyeSeenBySavior: json['eyeSeenBySavior'] as bool? ?? false,
    eyeSeenByExecutor: json['eyeSeenByExecutor'] as bool? ?? false,
    verdictState: json['verdictState'] as String?,
    verdictActionCount: json['verdictActionCount'] as int? ?? 0,
    awardedBonus: json['awardedBonus'] as int?,
    verdictHistory:
        (json['verdictHistory'] as List?)?.cast<String>() ?? const [],
  );
}

class GameActionLog {
  const GameActionLog({
    required this.actionIndex,
    required this.turnNumber,
    required this.actingPlayer,
    required this.faction,
    required this.actionType,
    required this.targetPersonId,
    required this.targetRank,
    required this.visibleTargetAttributeAtTime,
    required this.actualTargetAttribute,
    required this.stateBefore,
    required this.stateAfter,
    required this.lifeShieldBefore,
    required this.lifeShieldAfter,
    required this.judgedBefore,
    required this.judgedAfter,
    required this.actorHandBefore,
    required this.actorHandAfter,
    required this.opponentHandBefore,
    required this.opponentHandAfter,
    required this.timestamp,
    this.eyeResult,
    this.cpuEvaluationScore,
    this.cpuDecisionReason,
    this.underReviewBefore = false,
    this.underReviewAfter = false,
    this.remainingActionsBefore = 0,
    this.remainingActionsAfter = 0,
    this.knowledgeSource = 'none',
    this.scoreVisible = true,
    this.judgeWasAvailable = false,
    this.judgeAvailableFromTurn = 0,
    this.verdictActionCountBefore = 0,
    this.verdictActionCountAfter = 0,
    this.confirmedBy,
    this.scoringFaction,
    this.verdictBonus,
    this.nextBonusViewer,
    this.verdictHistoryBefore = const [],
    this.verdictHistoryAfter = const [],
    this.bonusViewerState,
    this.bonusOrder,
    this.nextBonusValue,
    this.nextBonusKnownByPlayer,
    this.nextBonusKnownByCpu,
    this.bonusRevealTriggered = false,
    this.bonusViewer,
    this.revealedBonus,
    this.wasReverseAction = false,
    this.eyeUsesRemainingBefore,
    this.eyeUsesRemainingAfter,
    this.eyeEligibleAtTime,
    this.eyeAlreadyUsedOnTargetByActor,
    this.targetZone,
    this.ruleVersion,
    this.turnDecisionTimeMs,
    this.eyeCandidateCount,
  });

  final int actionIndex;
  final int turnNumber;
  final String actingPlayer;
  final String faction;
  final String actionType;
  final String targetPersonId;
  final int targetRank;
  final String? visibleTargetAttributeAtTime;
  final String actualTargetAttribute;
  final String stateBefore;
  final String stateAfter;
  final bool lifeShieldBefore;
  final bool lifeShieldAfter;
  final bool judgedBefore;
  final bool judgedAfter;
  final String? eyeResult;
  final Map<String, int> actorHandBefore;
  final Map<String, int> actorHandAfter;
  final Map<String, int> opponentHandBefore;
  final Map<String, int> opponentHandAfter;
  final DateTime timestamp;
  final double? cpuEvaluationScore;
  final String? cpuDecisionReason;
  final bool underReviewBefore;
  final bool underReviewAfter;
  final int remainingActionsBefore;
  final int remainingActionsAfter;
  final String knowledgeSource;
  final bool scoreVisible;
  final bool judgeWasAvailable;
  final int judgeAvailableFromTurn;
  final int verdictActionCountBefore;
  final int verdictActionCountAfter;
  final String? confirmedBy;
  final String? scoringFaction;
  final int? verdictBonus;
  final String? nextBonusViewer;
  final List<String> verdictHistoryBefore;
  final List<String> verdictHistoryAfter;
  final String? bonusViewerState;
  final int? bonusOrder;
  final int? nextBonusValue;
  final bool? nextBonusKnownByPlayer;
  final bool? nextBonusKnownByCpu;
  final bool bonusRevealTriggered;
  final String? bonusViewer;
  final int? revealedBonus;
  final bool wasReverseAction;

  /// rulesVersion 1.2 EYE bookkeeping. Null on rulesVersion 1.1 games (no
  /// cap) and on older logs recorded before these fields existed.
  final int? eyeUsesRemainingBefore;
  final int? eyeUsesRemainingAfter;
  final bool? eyeEligibleAtTime;
  final bool? eyeAlreadyUsedOnTargetByActor;

  /// 'self' / 'center' / 'opponent', relative to the acting player.
  final String? targetZone;
  final String? ruleVersion;

  /// Wall-clock time from this turn becoming actionable to this action being
  /// confirmed. Null for CPU-decided turns and for logs recorded before this
  /// field existed.
  final int? turnDecisionTimeMs;

  /// For EYE actions only: how many center-row targets were legal for the
  /// actor at this moment (1..3). Lets analysis tell a real choice (2-3
  /// candidates) from a forced one (1 candidate). Null for non-EYE actions.
  final int? eyeCandidateCount;

  Map<String, dynamic> toJson() => {
    'actionIndex': actionIndex,
    'turnNumber': turnNumber,
    'actingPlayer': actingPlayer,
    'faction': faction,
    'actionType': actionType,
    'targetPersonId': targetPersonId,
    'targetRank': targetRank,
    'visibleTargetAttributeAtTime': visibleTargetAttributeAtTime,
    'actualTargetAttribute': actualTargetAttribute,
    'stateBefore': stateBefore,
    'stateAfter': stateAfter,
    'lifeShieldBefore': lifeShieldBefore,
    'lifeShieldAfter': lifeShieldAfter,
    'judgedBefore': judgedBefore,
    'judgedAfter': judgedAfter,
    'eyeResult': eyeResult,
    'actorHandBefore': actorHandBefore,
    'actorHandAfter': actorHandAfter,
    'opponentHandBefore': opponentHandBefore,
    'opponentHandAfter': opponentHandAfter,
    'timestamp': timestamp.toIso8601String(),
    'cpuEvaluationScore': cpuEvaluationScore,
    'cpuDecisionReason': cpuDecisionReason,
    'underReviewBefore': underReviewBefore,
    'underReviewAfter': underReviewAfter,
    'remainingActionsBefore': remainingActionsBefore,
    'remainingActionsAfter': remainingActionsAfter,
    'knowledgeSource': knowledgeSource,
    'scoreVisible': scoreVisible,
    'judgeWasAvailable': judgeWasAvailable,
    'judgeAvailableFromTurn': judgeAvailableFromTurn,
    'verdictActionCountBefore': verdictActionCountBefore,
    'verdictActionCountAfter': verdictActionCountAfter,
    'confirmedBy': confirmedBy,
    'scoringFaction': scoringFaction,
    'verdictBonus': verdictBonus,
    'nextBonusViewer': nextBonusViewer,
    'verdictHistoryBefore': verdictHistoryBefore,
    'verdictHistoryAfter': verdictHistoryAfter,
    'bonusViewerState': bonusViewerState,
    'bonusOrder': bonusOrder,
    'nextBonusValue': nextBonusValue,
    'nextBonusKnownByPlayer': nextBonusKnownByPlayer,
    'nextBonusKnownByCpu': nextBonusKnownByCpu,
    'bonusRevealTriggered': bonusRevealTriggered,
    'bonusViewer': bonusViewer,
    'revealedBonus': revealedBonus,
    'wasReverseAction': wasReverseAction,
    'eyeUsesRemainingBefore': eyeUsesRemainingBefore,
    'eyeUsesRemainingAfter': eyeUsesRemainingAfter,
    'eyeEligibleAtTime': eyeEligibleAtTime,
    'eyeAlreadyUsedOnTargetByActor': eyeAlreadyUsedOnTargetByActor,
    'targetZone': targetZone,
    'ruleVersion': ruleVersion,
    'turnDecisionTimeMs': turnDecisionTimeMs,
    'eyeCandidateCount': eyeCandidateCount,
  };

  factory GameActionLog.fromJson(Map<String, dynamic> json) => GameActionLog(
    actionIndex: json['actionIndex'] as int,
    turnNumber: json['turnNumber'] as int,
    actingPlayer: json['actingPlayer'] as String,
    faction: json['faction'] as String,
    actionType: json['actionType'] as String,
    targetPersonId: json['targetPersonId'] as String,
    targetRank: json['targetRank'] as int,
    visibleTargetAttributeAtTime:
        json['visibleTargetAttributeAtTime'] as String?,
    actualTargetAttribute: json['actualTargetAttribute'] as String,
    stateBefore: json['stateBefore'] as String,
    stateAfter: json['stateAfter'] as String,
    lifeShieldBefore: json['lifeShieldBefore'] as bool,
    lifeShieldAfter: json['lifeShieldAfter'] as bool,
    judgedBefore: json['judgedBefore'] as bool,
    judgedAfter: json['judgedAfter'] as bool,
    eyeResult: json['eyeResult'] as String?,
    actorHandBefore: _intMap(json['actorHandBefore']),
    actorHandAfter: _intMap(json['actorHandAfter']),
    opponentHandBefore: _intMap(json['opponentHandBefore']),
    opponentHandAfter: _intMap(json['opponentHandAfter']),
    timestamp: DateTime.parse(json['timestamp'] as String),
    cpuEvaluationScore: (json['cpuEvaluationScore'] as num?)?.toDouble(),
    cpuDecisionReason: json['cpuDecisionReason'] as String?,
    underReviewBefore: json['underReviewBefore'] as bool? ?? false,
    underReviewAfter: json['underReviewAfter'] as bool? ?? false,
    remainingActionsBefore: json['remainingActionsBefore'] as int? ?? 0,
    remainingActionsAfter: json['remainingActionsAfter'] as int? ?? 0,
    knowledgeSource: json['knowledgeSource'] as String? ?? 'none',
    scoreVisible: json['scoreVisible'] as bool? ?? true,
    judgeWasAvailable: json['judgeWasAvailable'] as bool? ?? false,
    judgeAvailableFromTurn: json['judgeAvailableFromTurn'] as int? ?? 0,
    verdictActionCountBefore: json['verdictActionCountBefore'] as int? ?? 0,
    verdictActionCountAfter: json['verdictActionCountAfter'] as int? ?? 0,
    confirmedBy: json['confirmedBy'] as String?,
    scoringFaction: json['scoringFaction'] as String?,
    verdictBonus: json['verdictBonus'] as int?,
    nextBonusViewer: json['nextBonusViewer'] as String?,
    verdictHistoryBefore:
        (json['verdictHistoryBefore'] as List?)?.cast<String>() ?? const [],
    verdictHistoryAfter:
        (json['verdictHistoryAfter'] as List?)?.cast<String>() ?? const [],
    bonusViewerState: json['bonusViewerState'] as String?,
    bonusOrder: json['bonusOrder'] as int?,
    nextBonusValue: json['nextBonusValue'] as int?,
    nextBonusKnownByPlayer: json['nextBonusKnownByPlayer'] as bool?,
    nextBonusKnownByCpu: json['nextBonusKnownByCpu'] as bool?,
    bonusRevealTriggered: json['bonusRevealTriggered'] as bool? ?? false,
    bonusViewer: json['bonusViewer'] as String?,
    revealedBonus: json['revealedBonus'] as int?,
    wasReverseAction: json['wasReverseAction'] as bool? ?? false,
    eyeUsesRemainingBefore: json['eyeUsesRemainingBefore'] as int?,
    eyeUsesRemainingAfter: json['eyeUsesRemainingAfter'] as int?,
    eyeEligibleAtTime: json['eyeEligibleAtTime'] as bool?,
    eyeAlreadyUsedOnTargetByActor:
        json['eyeAlreadyUsedOnTargetByActor'] as bool?,
    targetZone: json['targetZone'] as String?,
    ruleVersion: json['ruleVersion'] as String?,
    turnDecisionTimeMs: json['turnDecisionTimeMs'] as int?,
    eyeCandidateCount: json['eyeCandidateCount'] as int?,
  );
}

class InitialKnowledgeLog {
  const InitialKnowledgeLog({required this.personId, required this.attribute});

  final String personId;
  final String attribute;

  Map<String, dynamic> toJson() => {
    'personId': personId,
    'attribute': attribute,
  };

  factory InitialKnowledgeLog.fromJson(Map<String, dynamic> json) =>
      InitialKnowledgeLog(
        personId: json['personId'] as String,
        attribute: json['attribute'] as String,
      );
}

class GameSession {
  const GameSession({
    required this.gameId,
    required this.startedAt,
    required this.gameVersion,
    required this.rulesVersion,
    required this.mode,
    required this.playerFaction,
    required this.cpuFaction,
    required this.firstPlayer,
    required this.cpuDifficulty,
    required this.seed,
    required this.initialBoard,
    this.finishedAt,
    this.winner,
    this.saviorScore,
    this.executorScore,
    this.totalTurns = 0,
    this.endReason,
    this.notes = '',
    this.funRating,
    this.readingRating,
    this.luckRating,
    this.tempoRating,
    this.eyeChoiceRating,
    this.actions = const [],
    this.finalBoard = const [],
    this.initialKnowledge = const {},
    this.actionsUsed = const {},
    this.actionsRemaining = const {},
    this.scoreVisible = true,
    this.initialKnownPositionsBySavior = const [],
    this.initialKnownPositionsByExecutor = const [],
    this.experimentalRevokeMode,
    this.ruleUnderstandingRating,
    this.judgeUsefulnessRating,
    this.eyeTensionRating,
    this.strategicDepthRating,
    this.replayIntentRating,
    this.feedbackComment,
    this.buildCommitHash,
    this.testCohort,
    this.sessionId,
    this.testerId,
    this.playNumber,
    this.isFirstGame,
    this.completedTutorial,
    this.tutorialSkipped,
    this.judgeOpportunityCountSavior,
    this.judgeOpportunityCountExecutor,
    this.maxVisibleBonusWhileJudgeAvailableSavior,
    this.maxVisibleBonusWhileJudgeAvailableExecutor,
    this.saviorSpecialVerdictUsed,
    this.executorSpecialVerdictUsed,
    this.saviorReverseActionUsed,
    this.executorReverseActionUsed,
    this.gameAbandoned,
  });

  final String gameId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String gameVersion;
  final String rulesVersion;
  final String mode;
  final String playerFaction;
  final String cpuFaction;
  final String firstPlayer;
  final String cpuDifficulty;
  final String? winner;
  final int? saviorScore;
  final int? executorScore;
  final int totalTurns;
  final String? endReason;
  final int seed;
  final String notes;
  final int? funRating;
  final int? readingRating;
  final int? luckRating;
  final int? tempoRating;
  final int? eyeChoiceRating;
  final List<LoggedPerson> initialBoard;
  final List<GameActionLog> actions;
  final List<LoggedPerson> finalBoard;
  final Map<String, InitialKnowledgeLog> initialKnowledge;
  final Map<String, int> actionsUsed;
  final Map<String, int> actionsRemaining;
  final bool scoreVisible;

  /// rulesVersion 1.2 board-zone bookkeeping: which positionIndex values
  /// each faction knew from the start (see [NineJudgesController.reset]).
  /// Empty on logs recorded before these fields existed.
  final List<int> initialKnownPositionsBySavior;
  final List<int> initialKnownPositionsByExecutor;

  /// The simulation-only REVOKE experiment setting this game ran under, if
  /// any. Always null/'disabled' for real games — REVOKE is not part of any
  /// shipped ruleset.
  final String? experimentalRevokeMode;

  /// External-test-beta survey additions (see [updatePlaytestFeedback]),
  /// each 1-5, alongside the existing fun/reading/luck/tempo/eyeChoice.
  final int? ruleUnderstandingRating;
  final int? judgeUsefulnessRating;
  final int? eyeTensionRating;
  final int? strategicDepthRating;
  final int? replayIntentRating;

  /// Optional free-text feedback, capped client-side at ~500 characters.
  final String? feedbackComment;

  /// External-test-beta identification (see
  /// lib/features/nine_judges/services/external_test_profile.dart). All
  /// null on logs recorded before these fields existed, and on games not
  /// run through the real app (e.g. simulations).
  final String? buildCommitHash;
  final String? testCohort;
  final String? sessionId;
  final String? testerId;
  final int? playNumber;
  final bool? isFirstGame;

  /// Whether this device had completed/skipped the tutorial at the time
  /// this game started (from local storage, not this game's own actions).
  final bool? completedTutorial;
  final bool? tutorialSkipped;

  /// How many of this faction's turns began with JUDGE unused and legally
  /// usable (whether or not they actually used it that turn).
  final int? judgeOpportunityCountSavior;
  final int? judgeOpportunityCountExecutor;

  /// The highest verdict bonus this faction is known to have seen while
  /// JUDGE was still available and unused (null if they never knew the
  /// bonus at such a moment).
  final int? maxVisibleBonusWhileJudgeAvailableSavior;
  final int? maxVisibleBonusWhileJudgeAvailableExecutor;

  final bool? saviorSpecialVerdictUsed;
  final bool? executorSpecialVerdictUsed;
  final bool? saviorReverseActionUsed;
  final bool? executorReverseActionUsed;

  /// True if the player left before the game reached its normal end (e.g.
  /// via the in-game home button). Best-effort — not every abandonment
  /// path (browser kill, crash) can be detected.
  final bool? gameAbandoned;

  bool get isFinished => finishedAt != null;

  GameSession copyWith({
    DateTime? finishedAt,
    String? winner,
    int? saviorScore,
    int? executorScore,
    int? totalTurns,
    String? endReason,
    String? notes,
    int? funRating,
    int? readingRating,
    int? luckRating,
    int? tempoRating,
    int? eyeChoiceRating,
    List<GameActionLog>? actions,
    List<LoggedPerson>? finalBoard,
    Map<String, InitialKnowledgeLog>? initialKnowledge,
    Map<String, int>? actionsUsed,
    Map<String, int>? actionsRemaining,
    bool? scoreVisible,
    int? ruleUnderstandingRating,
    int? judgeUsefulnessRating,
    int? eyeTensionRating,
    int? strategicDepthRating,
    int? replayIntentRating,
    String? feedbackComment,
    String? buildCommitHash,
    String? testCohort,
    String? sessionId,
    String? testerId,
    int? playNumber,
    bool? isFirstGame,
    bool? completedTutorial,
    bool? tutorialSkipped,
    int? judgeOpportunityCountSavior,
    int? judgeOpportunityCountExecutor,
    int? maxVisibleBonusWhileJudgeAvailableSavior,
    int? maxVisibleBonusWhileJudgeAvailableExecutor,
    bool? saviorSpecialVerdictUsed,
    bool? executorSpecialVerdictUsed,
    bool? saviorReverseActionUsed,
    bool? executorReverseActionUsed,
    bool? gameAbandoned,
  }) => GameSession(
    gameId: gameId,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    gameVersion: gameVersion,
    rulesVersion: rulesVersion,
    mode: mode,
    playerFaction: playerFaction,
    cpuFaction: cpuFaction,
    firstPlayer: firstPlayer,
    cpuDifficulty: cpuDifficulty,
    winner: winner ?? this.winner,
    saviorScore: saviorScore ?? this.saviorScore,
    executorScore: executorScore ?? this.executorScore,
    totalTurns: totalTurns ?? this.totalTurns,
    endReason: endReason ?? this.endReason,
    seed: seed,
    notes: notes ?? this.notes,
    funRating: funRating ?? this.funRating,
    readingRating: readingRating ?? this.readingRating,
    luckRating: luckRating ?? this.luckRating,
    tempoRating: tempoRating ?? this.tempoRating,
    eyeChoiceRating: eyeChoiceRating ?? this.eyeChoiceRating,
    initialBoard: initialBoard,
    actions: actions ?? this.actions,
    finalBoard: finalBoard ?? this.finalBoard,
    initialKnowledge: initialKnowledge ?? this.initialKnowledge,
    actionsUsed: actionsUsed ?? this.actionsUsed,
    actionsRemaining: actionsRemaining ?? this.actionsRemaining,
    scoreVisible: scoreVisible ?? this.scoreVisible,
    initialKnownPositionsBySavior: initialKnownPositionsBySavior,
    initialKnownPositionsByExecutor: initialKnownPositionsByExecutor,
    experimentalRevokeMode: experimentalRevokeMode,
    ruleUnderstandingRating:
        ruleUnderstandingRating ?? this.ruleUnderstandingRating,
    judgeUsefulnessRating: judgeUsefulnessRating ?? this.judgeUsefulnessRating,
    eyeTensionRating: eyeTensionRating ?? this.eyeTensionRating,
    strategicDepthRating: strategicDepthRating ?? this.strategicDepthRating,
    replayIntentRating: replayIntentRating ?? this.replayIntentRating,
    feedbackComment: feedbackComment ?? this.feedbackComment,
    buildCommitHash: buildCommitHash ?? this.buildCommitHash,
    testCohort: testCohort ?? this.testCohort,
    sessionId: sessionId ?? this.sessionId,
    testerId: testerId ?? this.testerId,
    playNumber: playNumber ?? this.playNumber,
    isFirstGame: isFirstGame ?? this.isFirstGame,
    completedTutorial: completedTutorial ?? this.completedTutorial,
    tutorialSkipped: tutorialSkipped ?? this.tutorialSkipped,
    judgeOpportunityCountSavior:
        judgeOpportunityCountSavior ?? this.judgeOpportunityCountSavior,
    judgeOpportunityCountExecutor:
        judgeOpportunityCountExecutor ?? this.judgeOpportunityCountExecutor,
    maxVisibleBonusWhileJudgeAvailableSavior:
        maxVisibleBonusWhileJudgeAvailableSavior ??
        this.maxVisibleBonusWhileJudgeAvailableSavior,
    maxVisibleBonusWhileJudgeAvailableExecutor:
        maxVisibleBonusWhileJudgeAvailableExecutor ??
        this.maxVisibleBonusWhileJudgeAvailableExecutor,
    saviorSpecialVerdictUsed:
        saviorSpecialVerdictUsed ?? this.saviorSpecialVerdictUsed,
    executorSpecialVerdictUsed:
        executorSpecialVerdictUsed ?? this.executorSpecialVerdictUsed,
    saviorReverseActionUsed:
        saviorReverseActionUsed ?? this.saviorReverseActionUsed,
    executorReverseActionUsed:
        executorReverseActionUsed ?? this.executorReverseActionUsed,
    gameAbandoned: gameAbandoned ?? this.gameAbandoned,
  );

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'gameVersion': gameVersion,
    'rulesVersion': rulesVersion,
    'mode': mode,
    'playerFaction': playerFaction,
    'cpuFaction': cpuFaction,
    'firstPlayer': firstPlayer,
    'cpuDifficulty': cpuDifficulty,
    'winner': winner,
    'saviorScore': saviorScore,
    'executorScore': executorScore,
    'totalTurns': totalTurns,
    'endReason': endReason,
    'seed': seed,
    'notes': notes,
    'initialKnownPositionsBySavior': initialKnownPositionsBySavior,
    'initialKnownPositionsByExecutor': initialKnownPositionsByExecutor,
    'experimentalRevokeMode': experimentalRevokeMode,
    'ratings': {
      'fun': funRating,
      'reading': readingRating,
      'luck': luckRating,
      'tempo': tempoRating,
      'eyeChoice': eyeChoiceRating,
      'ruleUnderstanding': ruleUnderstandingRating,
      'judgeUsefulness': judgeUsefulnessRating,
      'eyeTension': eyeTensionRating,
      'strategicDepth': strategicDepthRating,
      'replayIntent': replayIntentRating,
    },
    'feedbackComment': feedbackComment,
    'buildCommitHash': buildCommitHash,
    'testCohort': testCohort,
    'sessionId': sessionId,
    'testerId': testerId,
    'playNumber': playNumber,
    'isFirstGame': isFirstGame,
    'completedTutorial': completedTutorial,
    'tutorialSkipped': tutorialSkipped,
    'judgeOpportunityCountSavior': judgeOpportunityCountSavior,
    'judgeOpportunityCountExecutor': judgeOpportunityCountExecutor,
    'maxVisibleBonusWhileJudgeAvailableSavior':
        maxVisibleBonusWhileJudgeAvailableSavior,
    'maxVisibleBonusWhileJudgeAvailableExecutor':
        maxVisibleBonusWhileJudgeAvailableExecutor,
    'saviorSpecialVerdictUsed': saviorSpecialVerdictUsed,
    'executorSpecialVerdictUsed': executorSpecialVerdictUsed,
    'saviorReverseActionUsed': saviorReverseActionUsed,
    'executorReverseActionUsed': executorReverseActionUsed,
    'gameAbandoned': gameAbandoned,
    'initialBoard': initialBoard.map((e) => e.toJson()).toList(),
    'actions': actions.map((e) => e.toJson()).toList(),
    'finalBoard': finalBoard.map((e) => e.toJson()).toList(),
    'initialKnowledge': initialKnowledge.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'actionsUsed': actionsUsed,
    'actionsRemaining': actionsRemaining,
    'scoreVisible': scoreVisible,
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String toReadableText() {
    final buffer = StringBuffer()
      ..writeln('9人の審判 $gameVersion / rules $rulesVersion')
      ..writeln('Game: $gameId')
      ..writeln('First: $firstPlayer  Winner: ${winner ?? '-'}')
      ..writeln('Score: ${saviorScore ?? '-'} - ${executorScore ?? '-'}')
      ..writeln('Turns: $totalTurns  End: ${endReason ?? '-'}')
      ..writeln('Score visible: $scoreVisible')
      ..writeln();
    for (final action in actions) {
      buffer.writeln(
        'Turn ${action.turnNumber} ${action.faction} '
        '${action.actionType.toUpperCase()} -> ${action.targetPersonId} '
        '[${action.stateBefore} -> ${action.stateAfter}]',
      );
    }
    return buffer.toString();
  }

  factory GameSession.fromJson(Map<String, dynamic> json) {
    final ratings = (json['ratings'] as Map?)?.cast<String, dynamic>() ?? {};
    return GameSession(
      gameId: json['gameId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
      gameVersion: json['gameVersion'] as String,
      rulesVersion: json['rulesVersion'] as String,
      mode: json['mode'] as String,
      playerFaction: json['playerFaction'] as String,
      cpuFaction: json['cpuFaction'] as String,
      firstPlayer: json['firstPlayer'] as String,
      cpuDifficulty: json['cpuDifficulty'] as String,
      winner: json['winner'] as String?,
      saviorScore: json['saviorScore'] as int?,
      executorScore: json['executorScore'] as int?,
      totalTurns: json['totalTurns'] as int? ?? 0,
      endReason: json['endReason'] as String?,
      seed: json['seed'] as int,
      notes: json['notes'] as String? ?? '',
      funRating: ratings['fun'] as int?,
      readingRating: ratings['reading'] as int?,
      luckRating: ratings['luck'] as int?,
      tempoRating: ratings['tempo'] as int?,
      eyeChoiceRating: ratings['eyeChoice'] as int?,
      ruleUnderstandingRating: ratings['ruleUnderstanding'] as int?,
      judgeUsefulnessRating: ratings['judgeUsefulness'] as int?,
      eyeTensionRating: ratings['eyeTension'] as int?,
      strategicDepthRating: ratings['strategicDepth'] as int?,
      replayIntentRating: ratings['replayIntent'] as int?,
      feedbackComment: json['feedbackComment'] as String?,
      buildCommitHash: json['buildCommitHash'] as String?,
      testCohort: json['testCohort'] as String?,
      sessionId: json['sessionId'] as String?,
      testerId: json['testerId'] as String?,
      playNumber: json['playNumber'] as int?,
      isFirstGame: json['isFirstGame'] as bool?,
      completedTutorial: json['completedTutorial'] as bool?,
      tutorialSkipped: json['tutorialSkipped'] as bool?,
      judgeOpportunityCountSavior: json['judgeOpportunityCountSavior'] as int?,
      judgeOpportunityCountExecutor:
          json['judgeOpportunityCountExecutor'] as int?,
      maxVisibleBonusWhileJudgeAvailableSavior:
          json['maxVisibleBonusWhileJudgeAvailableSavior'] as int?,
      maxVisibleBonusWhileJudgeAvailableExecutor:
          json['maxVisibleBonusWhileJudgeAvailableExecutor'] as int?,
      saviorSpecialVerdictUsed: json['saviorSpecialVerdictUsed'] as bool?,
      executorSpecialVerdictUsed: json['executorSpecialVerdictUsed'] as bool?,
      saviorReverseActionUsed: json['saviorReverseActionUsed'] as bool?,
      executorReverseActionUsed: json['executorReverseActionUsed'] as bool?,
      gameAbandoned: json['gameAbandoned'] as bool?,
      initialBoard: _maps(
        json['initialBoard'],
      ).map(LoggedPerson.fromJson).toList(),
      actions: _maps(json['actions']).map(GameActionLog.fromJson).toList(),
      finalBoard: _maps(json['finalBoard']).map(LoggedPerson.fromJson).toList(),
      initialKnowledge: ((json['initialKnowledge'] as Map?) ?? const {}).map(
        (key, value) => MapEntry(
          '$key',
          InitialKnowledgeLog.fromJson((value as Map).cast<String, dynamic>()),
        ),
      ),
      actionsUsed: _optionalIntMap(json['actionsUsed']),
      actionsRemaining: _optionalIntMap(json['actionsRemaining']),
      scoreVisible: json['scoreVisible'] as bool? ?? true,
      initialKnownPositionsBySavior:
          (json['initialKnownPositionsBySavior'] as List?)?.cast<int>() ??
          const [],
      initialKnownPositionsByExecutor:
          (json['initialKnownPositionsByExecutor'] as List?)?.cast<int>() ??
          const [],
      experimentalRevokeMode: json['experimentalRevokeMode'] as String?,
    );
  }
}

Map<String, int> _intMap(dynamic value) =>
    (value as Map).map((key, value) => MapEntry('$key', value as int));

Map<String, int> _optionalIntMap(dynamic value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value as int))
    : const {};

Iterable<Map<String, dynamic>> _maps(dynamic value) =>
    (value as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>());
