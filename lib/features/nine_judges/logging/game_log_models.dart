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
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

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
    );
  }
}

Map<String, int> _intMap(dynamic value) =>
    (value as Map).map((key, value) => MapEntry('$key', value as int));

Iterable<Map<String, dynamic>> _maps(dynamic value) =>
    (value as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>());
