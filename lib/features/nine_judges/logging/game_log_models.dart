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
    this.actions = const [],
    this.finalBoard = const [],
    this.initialKnowledge = const {},
    this.actionsUsed = const {},
    this.actionsRemaining = const {},
    this.scoreVisible = true,
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
  final List<LoggedPerson> initialBoard;
  final List<GameActionLog> actions;
  final List<LoggedPerson> finalBoard;
  final Map<String, InitialKnowledgeLog> initialKnowledge;
  final Map<String, int> actionsUsed;
  final Map<String, int> actionsRemaining;
  final bool scoreVisible;

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
    List<GameActionLog>? actions,
    List<LoggedPerson>? finalBoard,
    Map<String, InitialKnowledgeLog>? initialKnowledge,
    Map<String, int>? actionsUsed,
    Map<String, int>? actionsRemaining,
    bool? scoreVisible,
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
    initialBoard: initialBoard,
    actions: actions ?? this.actions,
    finalBoard: finalBoard ?? this.finalBoard,
    initialKnowledge: initialKnowledge ?? this.initialKnowledge,
    actionsUsed: actionsUsed ?? this.actionsUsed,
    actionsRemaining: actionsRemaining ?? this.actionsRemaining,
    scoreVisible: scoreVisible ?? this.scoreVisible,
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
    'ratings': {
      'fun': funRating,
      'reading': readingRating,
      'luck': luckRating,
      'tempo': tempoRating,
    },
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
