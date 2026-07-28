import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_filter.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_finding.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_report.dart';
import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_overview_stats.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/eye_judge_reverse_analysis.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:dead_or_alive/features/nine_judges/analysis/external_test_report.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_record.dart';

/// Pure aggregation for the admin "分析レポート" tab (section 5 of the
/// AI-analysis-report task). Reuses the exact same definitions as
/// tool/run_external_test_analysis.dart / the rest of the admin dashboard
/// (see admin_overview_stats.dart, eye_judge_reverse_analysis.dart,
/// external_test_report.dart) wherever a metric already has one — section
/// 13's "no disagreement with the CLI" requirement extends to this report.
///
/// Takes an already-resolved, already-filtered [pool] (network/Firestore
/// decisions live in the screen layer — see admin_analysis_screen.dart) so
/// this stays a synchronous, easily-unit-tested function.
AnalysisReport buildAnalysisReport({
  required List<PlaytestRecord> pool,
  required AnalysisFilter filter,
  required String projectId,
  required TesterAnonymizer anonymizer,
  int failedActionGameCount = 0,
  List<String> failedGameIds = const [],
}) {
  final games = pool.map((r) => r.session).toList();
  return AnalysisReport(
    generatedAt: DateTime.now(),
    reportInfo: _buildReportInfo(
      pool: pool,
      games: games,
      projectId: projectId,
      mode: filter.mode,
    ),
    filters: _buildFiltersJson(filter, pool.length),
    summary: _buildSummary(games),
    balance: _buildBalance(games),
    ratings: _buildRatings(games),
    eyeAnalysis: _buildEyeAnalysis(pool),
    judgeAnalysis: _buildJudgeAnalysis(pool),
    reverseAnalysis: _buildReverseAnalysis(pool),
    firstGameComparison: _buildFirstGameComparison(games),
    cpuDifficultyAnalysis: attachEyeUsageToCpuDifficultyAnalysis(
      _buildCpuDifficultyAnalysis(games),
      pool,
    ),
    kpis: _buildKpis(games),
    findings: buildFindings(games: games, pool: pool),
    feedback: _buildFeedback(pool, anonymizer),
    metadata: {
      'failedActionGameCount': failedActionGameCount,
      'failedGameIds': failedGameIds,
    },
  );
}

// ---------------------------------------------------------------------------
// Shared numeric helpers
// ---------------------------------------------------------------------------

double? _avg(Iterable<num?> values) {
  final present = values.whereType<num>().toList();
  return present.isEmpty
      ? null
      : present.reduce((a, b) => a + b) / present.length;
}

double? _median(Iterable<num?> values) {
  final present = values.whereType<num>().map((v) => v.toDouble()).toList()
    ..sort();
  if (present.isEmpty) return null;
  final mid = present.length ~/ 2;
  if (present.length.isOdd) return present[mid];
  return (present[mid - 1] + present[mid]) / 2.0;
}

double? _rate(int value, int denominator) =>
    denominator == 0 ? null : value / denominator;

Map<String, List<GameSession>> _groupBy(
  List<GameSession> games,
  String? Function(GameSession) keyFn,
) {
  final map = <String, List<GameSession>>{};
  for (final g in games) {
    final key = keyFn(g);
    if (key == null) continue;
    map.putIfAbsent(key, () => []).add(g);
  }
  return map;
}

/// Player-win-rate (winner == playerFaction), grouped by [keyFn] — used for
/// every "OO別勝率" breakdown in section C (playerFaction/cpuDifficulty/
/// rulesVersion/gameVersion), since the task doesn't specify a different
/// win definition per dimension.
Map<String, double?> _groupedPlayerWinRate(
  List<GameSession> games,
  String? Function(GameSession) keyFn,
) {
  final grouped = _groupBy(games, keyFn);
  return {
    for (final entry in grouped.entries)
      entry.key: _rate(
        entry.value.where((g) => g.winner == g.playerFaction).length,
        entry.value.length,
      ),
  };
}

RatingDistribution _ratingDistribution(Iterable<int?> values) {
  final counts = <String, int>{'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
  var nullCount = 0;
  final present = <int>[];
  for (final v in values) {
    if (v == null) {
      nullCount++;
      continue;
    }
    present.add(v);
    final key = '$v';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  counts['null'] = nullCount;
  return RatingDistribution(
    average: present.isEmpty
        ? null
        : present.reduce((a, b) => a + b) / present.length,
    median: _median(present),
    n: present.length,
    counts: counts,
  );
}

Map<String, Object?> _ratingsBlock(Iterable<GameSession> pool) {
  final games = pool.toList();
  return {
    for (final key in AdminOverviewStats.ratingKeys)
      key: _ratingDistribution(
        games.map((s) => AdminOverviewStats.ratingValue(s, key)),
      ).toJson(),
  };
}

// ---------------------------------------------------------------------------
// A. Report basic info
// ---------------------------------------------------------------------------

Map<String, Object?> _buildReportInfo({
  required List<PlaytestRecord> pool,
  required List<GameSession> games,
  required String projectId,
  required AnalysisMode mode,
}) {
  final testerIds = games.map((g) => g.testerId).whereType<String>().toSet();
  final finishedDates = games.map((g) => g.finishedAt).whereType<DateTime>().toList()
    ..sort();
  final rulesVersions = games.map((g) => g.rulesVersion).toSet().toList()
    ..sort();
  final gameVersions = games.map((g) => g.gameVersion).toSet().toList()..sort();
  final testCohorts = games.map((g) => g.testCohort).whereType<String>().toSet().toList()
    ..sort();
  final actionsLoaded = pool.where((r) => r.actions != null).length;
  // "欠損データ件数": games missing the fields needed to classify them
  // reliably (finishedAt for ordering/duration, testerId for anonymization/
  // repeat-play detection) — never guessed, just counted.
  final missingDataCount = games
      .where((g) => g.finishedAt == null || g.testerId == null)
      .length;

  return {
    'projectId': projectId,
    'gameCount': games.length,
    'uniqueTesterCount': testerIds.length,
    'periodStart': finishedDates.isEmpty ? null : finishedDates.first.toIso8601String(),
    'periodEnd': finishedDates.isEmpty ? null : finishedDates.last.toIso8601String(),
    'rulesVersions': rulesVersions,
    'gameVersions': gameVersions,
    'testCohorts': testCohorts,
    'analysisMode': mode.name,
    'actionsLoadedGameCount': actionsLoaded,
    'missingDataCount': missingDataCount,
  };
}

Map<String, Object?> _buildFiltersJson(AnalysisFilter filter, int poolSize) => {
  'source': filter.source.name,
  'mode': filter.mode.name,
  'from': filter.from?.toIso8601String(),
  'to': filter.to?.toIso8601String(),
  'rulesVersion': filter.rulesVersion,
  'gameVersion': filter.gameVersion,
  'playerFaction': filter.playerFaction,
  'winner': filter.winner,
  'firstPlayer': filter.firstPlayer,
  'cpuDifficulty': filter.cpuDifficulty,
  'isFirstGame': filter.isFirstGame,
  'testCohort': filter.testCohort,
  'ratedOnly': filter.ratedOnly,
  'commentedOnly': filter.commentedOnly,
  'resolvedPoolSize': poolSize,
};

// ---------------------------------------------------------------------------
// B. Overall summary
// ---------------------------------------------------------------------------

Map<String, Object?> _buildSummary(List<GameSession> games) {
  final testerGames = <String, List<GameSession>>{};
  for (final g in games) {
    final id = g.testerId;
    if (id != null) testerGames.putIfAbsent(id, () => []).add(g);
  }
  var firstTimeCount = 0;
  var repeaterCount = 0;
  for (final sessions in testerGames.values) {
    if (sessions.any(AdminOverviewStats.isExperiencedSession)) {
      repeaterCount++;
    } else {
      firstTimeCount++;
    }
  }

  final durations = games
      .where((g) => g.finishedAt != null)
      .map((g) => g.finishedAt!.difference(g.startedAt).inSeconds / 60.0)
      .toList();
  final scoreDiffs = games
      .where((g) => g.saviorScore != null && g.executorScore != null)
      .map((g) => (g.saviorScore! - g.executorScore!).abs())
      .toList();
  final abandonmentTracked = games.where((g) => g.gameAbandoned != null).toList();

  final endReasonCounts = <String, int>{};
  for (final g in games) {
    final key = g.endReason ?? '(不明)';
    endReasonCounts[key] = (endReasonCounts[key] ?? 0) + 1;
  }
  final endReasonTracked = games.where((g) => g.endReason != null).length;

  return {
    'totalGames': games.length,
    'uniqueTesterCount': testerGames.length,
    'firstTimePlayerCount': firstTimeCount,
    'repeaterCount': repeaterCount,
    'avgPlayNumber': _avg(games.map((g) => g.playNumber)),
    'avgGameDurationMinutes': _avg(durations),
    'avgTurns': _avg(games.map((g) => g.totalTurns)),
    'avgScoreDiff': _avg(scoreDiffs),
    'medianScoreDiff': _median(scoreDiffs),
    'maxScoreDiff': scoreDiffs.isEmpty
        ? null
        : scoreDiffs.reduce((a, b) => a > b ? a : b),
    'abandonmentRate': abandonmentTracked.isEmpty
        ? null
        : _rate(
            abandonmentTracked.where((g) => g.gameAbandoned == true).length,
            abandonmentTracked.length,
          ),
    'abandonmentSampleSize': abandonmentTracked.length,
    'allConfirmedRate': endReasonTracked == 0
        ? null
        : _rate(
            games.where((g) => g.endReason == 'allConfirmed').length,
            endReasonTracked,
          ),
    'endReasonCounts': endReasonCounts,
  };
}

// ---------------------------------------------------------------------------
// C. Win rate / balance
// ---------------------------------------------------------------------------

Map<String, Object?> _buildBalance(List<GameSession> games) {
  final decisive = games
      .where((g) => g.winner != null && g.winner != 'draw')
      .toList();
  final firstWins = decisive.where((g) => g.winner == g.firstPlayer).length;
  final scoreDiffs = games
      .where((g) => g.saviorScore != null && g.executorScore != null)
      .map((g) => (g.saviorScore! - g.executorScore!).abs())
      .toList();
  final oneSided = scoreDiffs.where((d) => d >= defaultOneSidedThreshold).length;

  final winnerScores = decisive
      .map((g) => g.winner == 'savior' ? g.saviorScore : g.executorScore)
      .whereType<int>()
      .toList();

  return {
    'saviorWinRate': _rate(games.where((g) => g.winner == 'savior').length, games.length),
    'executorWinRate': _rate(
      games.where((g) => g.winner == 'executor').length,
      games.length,
    ),
    'drawRate': _rate(games.where((g) => g.winner == 'draw').length, games.length),
    'firstPlayerWinRate': _rate(firstWins, decisive.length),
    'secondPlayerWinRate': _rate(decisive.length - firstWins, decisive.length),
    'playerWinRate': _rate(
      games.where((g) => g.winner == g.playerFaction).length,
      games.length,
    ),
    'cpuWinRate': _rate(
      games.where((g) => g.winner == g.cpuFaction).length,
      games.length,
    ),
    'winRateByPlayerFaction': _groupedPlayerWinRate(games, (g) => g.playerFaction),
    'winRateByCpuDifficulty': _groupedPlayerWinRate(games, (g) => g.cpuDifficulty),
    'winRateByRulesVersion': _groupedPlayerWinRate(games, (g) => g.rulesVersion),
    'winRateByGameVersion': _groupedPlayerWinRate(games, (g) => g.gameVersion),
    'winRateByFirstTimeVsExperienced': {
      'firstTime': _rate(
        games
            .where(AdminOverviewStats.isFirstTimeSession)
            .where((g) => g.winner == g.playerFaction)
            .length,
        games.where(AdminOverviewStats.isFirstTimeSession).length,
      ),
      'experienced': _rate(
        games
            .where(AdminOverviewStats.isExperiencedSession)
            .where((g) => g.winner == g.playerFaction)
            .length,
        games.where(AdminOverviewStats.isExperiencedSession).length,
      ),
    },
    'avgWinnerScore': _avg(winnerScores),
    'avgSaviorScore': _avg(games.map((g) => g.saviorScore)),
    'avgExecutorScore': _avg(games.map((g) => g.executorScore)),
    'oneSidedRate': scoreDiffs.isEmpty ? null : _rate(oneSided, scoreDiffs.length),
    'oneSidedThreshold': defaultOneSidedThreshold,
  };
}

// ---------------------------------------------------------------------------
// D. Ratings
// ---------------------------------------------------------------------------

Map<String, Object?> _buildRatings(List<GameSession> games) {
  Map<String, Object?> byGroup(String? Function(GameSession) keyFn) {
    final grouped = _groupBy(games, keyFn);
    return {for (final e in grouped.entries) e.key: _ratingsBlock(e.value)};
  }

  return {
    'overall': _ratingsBlock(games),
    'byFirstTime': _ratingsBlock(games.where(AdminOverviewStats.isFirstTimeSession)),
    'byExperienced': _ratingsBlock(games.where(AdminOverviewStats.isExperiencedSession)),
    'byPlayerWin': _ratingsBlock(games.where((g) => g.winner == g.playerFaction)),
    'byPlayerLoss': _ratingsBlock(games.where((g) => g.winner == g.cpuFaction)),
    'byPlayerFaction': byGroup((g) => g.playerFaction),
    'byCpuDifficulty': byGroup((g) => g.cpuDifficulty),
    'byRulesVersion': byGroup((g) => g.rulesVersion),
    'byGameVersion': byGroup((g) => g.gameVersion),
  };
}

// ---------------------------------------------------------------------------
// E. EYE analysis
// ---------------------------------------------------------------------------

Map<String, Object?> _buildEyeAnalysis(List<PlaytestRecord> pool) {
  final base = EyeAnalysis.compute(pool);
  final withActions = pool.where((r) => r.actions != null).toList();
  final eyeActions = withActions
      .expand((r) => r.actions!.where((a) => a.actionType == 'eye'))
      .toList();

  final candidateCounts = <String, int>{};
  for (final a in eyeActions) {
    if (a.eyeCandidateCount == null) continue;
    final key = '${a.eyeCandidateCount}';
    candidateCounts[key] = (candidateCounts[key] ?? 0) + 1;
  }

  final turns = eyeActions.map((a) => a.turnNumber).toList();

  bool usedEye(PlaytestRecord r) =>
      r.actions?.any((a) => a.actionType == 'eye') ?? false;
  final tracked = withActions;
  final eyeUserWins = tracked
      .where(usedEye)
      .where((r) => r.session.winner == r.session.playerFaction)
      .length;
  final eyeUserCount = tracked.where(usedEye).length;

  final rulesVersionGroups = <String, List<PlaytestRecord>>{};
  for (final r in pool) {
    rulesVersionGroups.putIfAbsent(r.session.rulesVersion, () => []).add(r);
  }

  return {
    ...base.toJson(),
    'eyeCandidateCountCounts': candidateCounts,
    'avgUseTurn': _avg(turns),
    'eyeUserWinRate': eyeUserCount == 0 ? null : _rate(eyeUserWins, eyeUserCount),
    'eyeUsedUpUserWinRate': _eyeUsedUpToCapWinRate(withActions),
    'byRulesVersion': {
      for (final e in rulesVersionGroups.entries)
        e.key: EyeAnalysis.compute(e.value).toJson(),
    },
  };
}

double? _eyeUsedUpToCapWinRate(List<PlaytestRecord> withActions) {
  final usedUpRecords = <PlaytestRecord>[];
  for (final r in withActions) {
    final cap = switch (r.session.rulesVersion) {
      '1.2' => 2,
      _ => null,
    };
    if (cap == null) continue;
    final byFaction = <String, int>{};
    for (final a in r.actions!.where((a) => a.actionType == 'eye')) {
      byFaction[a.faction] = (byFaction[a.faction] ?? 0) + 1;
    }
    if ((byFaction[r.session.playerFaction] ?? 0) >= cap) {
      usedUpRecords.add(r);
    }
  }
  if (usedUpRecords.isEmpty) return null;
  final wins = usedUpRecords
      .where((r) => r.session.winner == r.session.playerFaction)
      .length;
  return _rate(wins, usedUpRecords.length);
}

// ---------------------------------------------------------------------------
// F. JUDGE analysis
// ---------------------------------------------------------------------------

Map<String, Object?> _buildJudgeAnalysis(List<PlaytestRecord> pool) {
  final base = JudgeAnalysis.compute(pool);
  final games = pool.map((r) => r.session).toList();

  bool? judgeUsedForPlayer(GameSession s) => s.playerFaction == 'savior'
      ? s.saviorSpecialVerdictUsed
      : s.executorSpecialVerdictUsed;
  bool? judgeUsedForCpu(GameSession s) => s.cpuFaction == 'savior'
      ? s.saviorSpecialVerdictUsed
      : s.executorSpecialVerdictUsed;

  final playerTracked = games.where((g) => judgeUsedForPlayer(g) != null).toList();
  final cpuTracked = games.where((g) => judgeUsedForCpu(g) != null).toList();

  // "JUDGE未使用者のjudgeOpportunityCount平均" — same pattern as the CLI's
  // ExternalTestReport (judgeUnusedOpportunities): only count a faction's
  // opportunity count when that faction did NOT use JUDGE.
  final unusedOpportunities = <int>[
    for (final g in games) ...[
      if (g.saviorSpecialVerdictUsed == false) ?g.judgeOpportunityCountSavior,
      if (g.executorSpecialVerdictUsed == false)
        ?g.judgeOpportunityCountExecutor,
    ],
  ];

  var highBonusUnused = 0;
  for (final g in games) {
    if (g.saviorSpecialVerdictUsed == false &&
        (g.maxVisibleBonusWhileJudgeAvailableSavior ?? 0) >=
            JudgeAnalysis.highBonusThreshold) {
      highBonusUnused++;
    }
    if (g.executorSpecialVerdictUsed == false &&
        (g.maxVisibleBonusWhileJudgeAvailableExecutor ?? 0) >=
            JudgeAnalysis.highBonusThreshold) {
      highBonusUnused++;
    }
  }

  final judgeUsedGames = games
      .where(
        (g) =>
            g.saviorSpecialVerdictUsed == true ||
            g.executorSpecialVerdictUsed == true,
      )
      .toList();
  final scoreDiffsForJudgeGames = judgeUsedGames
      .where((g) => g.saviorScore != null && g.executorScore != null)
      .map((g) => (g.saviorScore! - g.executorScore!).abs())
      .toList();

  final rulesVersionGroups = <String, List<PlaytestRecord>>{};
  for (final r in pool) {
    rulesVersionGroups.putIfAbsent(r.session.rulesVersion, () => []).add(r);
  }

  return {
    ...base.toJson(),
    'playerUsageRate': _rate(
      playerTracked.where((g) => judgeUsedForPlayer(g) == true).length,
      playerTracked.length,
    ),
    'cpuUsageRate': _rate(
      cpuTracked.where((g) => judgeUsedForCpu(g) == true).length,
      cpuTracked.length,
    ),
    'avgOpportunityCountWhenUnused': _avg(unusedOpportunities),
    'highBonusUnusedCount': highBonusUnused,
    'judgeUserWinRate': _rate(
      playerTracked
          .where((g) => judgeUsedForPlayer(g) == true)
          .where((g) => g.winner == g.playerFaction)
          .length,
      playerTracked.where((g) => judgeUsedForPlayer(g) == true).length,
    ),
    'judgeNonUserWinRate': _rate(
      playerTracked
          .where((g) => judgeUsedForPlayer(g) == false)
          .where((g) => g.winner == g.playerFaction)
          .length,
      playerTracked.where((g) => judgeUsedForPlayer(g) == false).length,
    ),
    'avgScoreDiffInJudgeGames': _avg(scoreDiffsForJudgeGames),
    'byRulesVersion': {
      for (final e in rulesVersionGroups.entries)
        e.key: JudgeAnalysis.compute(e.value).toJson(),
    },
  };
}

// ---------------------------------------------------------------------------
// G. Reverse-action analysis
// ---------------------------------------------------------------------------

Map<String, Object?> _buildReverseAnalysis(List<PlaytestRecord> pool) {
  final base = ReverseAnalysis.compute(pool);
  final games = pool.map((r) => r.session).toList();

  bool? reverseUsedForPlayer(GameSession s) => s.playerFaction == 'savior'
      ? s.saviorReverseActionUsed
      : s.executorReverseActionUsed;
  bool? reverseUsedForCpu(GameSession s) => s.cpuFaction == 'savior'
      ? s.saviorReverseActionUsed
      : s.executorReverseActionUsed;

  final playerTracked = games.where((g) => reverseUsedForPlayer(g) != null).toList();
  final cpuTracked = games.where((g) => reverseUsedForCpu(g) != null).toList();

  final rulesVersionGroups = <String, List<PlaytestRecord>>{};
  for (final r in pool) {
    rulesVersionGroups.putIfAbsent(r.session.rulesVersion, () => []).add(r);
  }

  return {
    ...base.toJson(),
    'playerUsageRate': _rate(
      playerTracked.where((g) => reverseUsedForPlayer(g) == true).length,
      playerTracked.length,
    ),
    'cpuUsageRate': _rate(
      cpuTracked.where((g) => reverseUsedForCpu(g) == true).length,
      cpuTracked.length,
    ),
    'userWinRate': _rate(
      playerTracked
          .where((g) => reverseUsedForPlayer(g) == true)
          .where((g) => g.winner == g.playerFaction)
          .length,
      playerTracked.where((g) => reverseUsedForPlayer(g) == true).length,
    ),
    'byRulesVersion': {
      for (final e in rulesVersionGroups.entries)
        e.key: ReverseAnalysis.compute(e.value).toJson(),
    },
  };
}

// ---------------------------------------------------------------------------
// H. First-time vs experienced
// ---------------------------------------------------------------------------

Map<String, Object?> _buildFirstGameComparison(List<GameSession> games) {
  Map<String, Object?> statsFor(Iterable<GameSession> pool) {
    final list = pool.toList();
    final durations = list
        .where((g) => g.finishedAt != null)
        .map((g) => g.finishedAt!.difference(g.startedAt).inSeconds / 60.0)
        .toList();
    final scoreDiffs = list
        .where((g) => g.saviorScore != null && g.executorScore != null)
        .map((g) => (g.saviorScore! - g.executorScore!).abs())
        .toList();
    final abandonmentTracked = list.where((g) => g.gameAbandoned != null).toList();
    return {
      'sampleSize': list.length,
      'playerWinRate': _rate(
        list.where((g) => g.winner == g.playerFaction).length,
        list.length,
      ),
      'avgTurns': _avg(list.map((g) => g.totalTurns)),
      'avgGameDurationMinutes': _avg(durations),
      'avgScoreDiff': _avg(scoreDiffs),
      'fun': _ratingDistribution(
        list.map((s) => AdminOverviewStats.ratingValue(s, 'fun')),
      ).toJson(),
      'ruleUnderstanding': _ratingDistribution(
        list.map((s) => AdminOverviewStats.ratingValue(s, 'ruleUnderstanding')),
      ).toJson(),
      'eyeTension': _ratingDistribution(
        list.map((s) => AdminOverviewStats.ratingValue(s, 'eyeTension')),
      ).toJson(),
      'strategicDepth': _ratingDistribution(
        list.map((s) => AdminOverviewStats.ratingValue(s, 'strategicDepth')),
      ).toJson(),
      'replayIntent': _ratingDistribution(
        list.map((s) => AdminOverviewStats.ratingValue(s, 'replayIntent')),
      ).toJson(),
      'abandonmentRate': abandonmentTracked.isEmpty
          ? null
          : _rate(
              abandonmentTracked.where((g) => g.gameAbandoned == true).length,
              abandonmentTracked.length,
            ),
      'abandonmentSampleSize': abandonmentTracked.length,
    };
  }

  return {
    'firstTime': statsFor(games.where(AdminOverviewStats.isFirstTimeSession)),
    'experienced': statsFor(games.where(AdminOverviewStats.isExperiencedSession)),
  };
}

// ---------------------------------------------------------------------------
// I. CPU difficulty breakdown
// ---------------------------------------------------------------------------

Map<String, Object?> _buildCpuDifficultyAnalysis(List<GameSession> games) {
  final grouped = _groupBy(games, (g) => g.cpuDifficulty);
  return {
    for (final entry in grouped.entries)
      entry.key: () {
        final list = entry.value;
        final decisive = list.where((g) => g.winner != null && g.winner != 'draw').toList();
        final firstWins = decisive.where((g) => g.winner == g.firstPlayer).length;
        final scoreDiffs = list
            .where((g) => g.saviorScore != null && g.executorScore != null)
            .map((g) => (g.saviorScore! - g.executorScore!).abs())
            .toList();
        return {
          'gameCount': list.length,
          'playerWinRate': _rate(
            list.where((g) => g.winner == g.playerFaction).length,
            list.length,
          ),
          'saviorWinRate': _rate(
            list.where((g) => g.winner == 'savior').length,
            list.length,
          ),
          'firstPlayerWinRate': _rate(firstWins, decisive.length),
          'avgTurns': _avg(list.map((g) => g.totalTurns)),
          'avgScoreDiff': _avg(scoreDiffs),
          'fun': _ratingDistribution(
            list.map((s) => AdminOverviewStats.ratingValue(s, 'fun')),
          ).toJson(),
          'ruleUnderstanding': _ratingDistribution(
            list.map((s) => AdminOverviewStats.ratingValue(s, 'ruleUnderstanding')),
          ).toJson(),
          'strategicDepth': _ratingDistribution(
            list.map((s) => AdminOverviewStats.ratingValue(s, 'strategicDepth')),
          ).toJson(),
          'replayIntent': _ratingDistribution(
            list.map((s) => AdminOverviewStats.ratingValue(s, 'replayIntent')),
          ).toJson(),
          'avgEyeUsesPerGame': null,
          'judgeUsageRate': _rate(
            list
                .where(
                  (g) =>
                      (g.playerFaction == 'savior'
                          ? g.saviorSpecialVerdictUsed
                          : g.executorSpecialVerdictUsed) ==
                      true,
                )
                .length,
            list
                .where(
                  (g) =>
                      (g.playerFaction == 'savior'
                          ? g.saviorSpecialVerdictUsed
                          : g.executorSpecialVerdictUsed) !=
                      null,
                )
                .length,
          ),
        };
      }(),
  };
}

/// Section I's "EYE平均使用回数" needs `actions`, which isn't available from
/// [GameSession] lists alone (only from [PlaytestRecord]s with actions
/// loaded) — this overload fills that field in properly when actions are
/// available; see [buildAnalysisReport] which calls this after the
/// GameSession-only version above.
Map<String, Object?> attachEyeUsageToCpuDifficultyAnalysis(
  Map<String, Object?> cpuDifficultyAnalysis,
  List<PlaytestRecord> pool,
) {
  final grouped = <String, List<PlaytestRecord>>{};
  for (final r in pool) {
    grouped.putIfAbsent(r.session.cpuDifficulty, () => []).add(r);
  }
  final result = <String, Object?>{};
  cpuDifficultyAnalysis.forEach((key, value) {
    final entry = Map<String, Object?>.from(value! as Map);
    final withActions = (grouped[key] ?? const []).where((r) => r.actions != null);
    final counts = withActions
        .map((r) => r.actions!.where((a) => a.actionType == 'eye').length)
        .toList();
    entry['avgEyeUsesPerGame'] = counts.isEmpty ? null : _avg(counts);
    result[key] = entry;
  });
  return result;
}

// ---------------------------------------------------------------------------
// K. KPI (reuses ExternalTestReport verbatim)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _buildKpis(List<GameSession> games) {
  final report = ExternalTestReport.build(
    sessions: games,
    tutorialEvents: const <TutorialEventRecord>[],
    oneSidedThreshold: defaultOneSidedThreshold,
  );

  int sampleSizeFor(String name) => switch (name) {
    'ruleUnderstanding' =>
      games.map((g) => g.ruleUnderstandingRating).whereType<int>().length,
    'fun' => games.map((g) => g.funRating).whereType<int>().length,
    'replayIntent' =>
      games.map((g) => g.replayIntentRating).whereType<int>().length,
    'strategicDepth' =>
      games.map((g) => g.strategicDepthRating).whereType<int>().length,
    'tutorialCompletionRate' => 0,
    'averageTurns' => games.length,
    'firstPlayerWinRate' =>
      games.where((g) => g.winner != null && g.winner != 'draw').length,
    'saviorWinRate' => games.length,
    'oneSidedRate' => games
        .where((g) => g.saviorScore != null && g.executorScore != null)
        .length,
    _ => games.length,
  };

  return [
    for (final kpi in report.kpis)
      {
        'metric': kpi.name,
        'value': kpi.value,
        'sampleSize': kpi.name.startsWith('eye')
            ? games.map((g) => g.eyeChoiceRating).whereType<int>().length
            : sampleSizeFor(kpi.name),
        'target': kpi.target,
        'status': kpi.verdict == KpiVerdict.noData
            ? 'DATA_INSUFFICIENT'
            : kpi.verdict.label,
        // Section 18: tutorial telemetry never reaches Firestore — never
        // fabricate a value for it.
        'reason': kpi.name == 'tutorialCompletionRate'
            ? 'チュートリアルデータはFirestoreへ送信されていません'
            : null,
      },
  ];
}

// ---------------------------------------------------------------------------
// J. Feedback (anonymized)
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _buildFeedback(
  List<PlaytestRecord> pool,
  TesterAnonymizer anonymizer,
) {
  final result = <Map<String, Object?>>[];
  for (final record in pool) {
    final s = record.session;
    final comment = (s.feedbackComment ?? '').trim().isNotEmpty
        ? s.feedbackComment!.trim()
        : s.notes.trim();
    if (comment.isEmpty) continue;
    result.add({
      'anonymousPlayerLabel': anonymizer.label(s.testerId),
      'playNumber': s.playNumber,
      'isFirstGame': s.isFirstGame,
      'gameId': s.gameId,
      'finishedAt': s.finishedAt?.toIso8601String(),
      'playerFaction': s.playerFaction,
      'winner': s.winner,
      'fun': s.funRating,
      'ruleUnderstanding': s.ruleUnderstandingRating,
      'strategicDepth': s.strategicDepthRating,
      'replayIntent': s.replayIntentRating,
      'feedbackComment': (s.feedbackComment ?? '').trim().isNotEmpty
          ? s.feedbackComment!.trim()
          : null,
      'notes': s.notes.trim().isNotEmpty ? s.notes.trim() : null,
    });
  }
  return result;
}

// ---------------------------------------------------------------------------
// L. Automatically-detected findings
// ---------------------------------------------------------------------------

List<AnalysisFinding> buildFindings({
  required List<GameSession> games,
  required List<PlaytestRecord> pool,
}) {
  final findings = <AnalysisFinding>[];
  if (games.isEmpty) return findings;

  final decisive = games.where((g) => g.winner != null && g.winner != 'draw').toList();
  final firstWinRate = _rate(
    decisive.where((g) => g.winner == g.firstPlayer).length,
    decisive.length,
  );
  final saviorWinRate = _rate(
    games.where((g) => g.winner == 'savior').length,
    games.length,
  );
  final scoreDiffs = games
      .where((g) => g.saviorScore != null && g.executorScore != null)
      .map((g) => (g.saviorScore! - g.executorScore!).abs())
      .toList();
  final oneSidedRate = scoreDiffs.isEmpty
      ? null
      : _rate(
          scoreDiffs.where((d) => d >= defaultOneSidedThreshold).length,
          scoreDiffs.length,
        );
  final avgTurns = _avg(games.map((g) => g.totalTurns));
  final fun = _avg(games.map((g) => g.funRating));
  final ruleUnderstanding = _avg(games.map((g) => g.ruleUnderstandingRating));
  final replayIntent = _avg(games.map((g) => g.replayIntentRating));
  final strategicDepth = _avg(games.map((g) => g.strategicDepthRating));
  final abandonmentTracked = games.where((g) => g.gameAbandoned != null).toList();
  final abandonmentRate = abandonmentTracked.isEmpty
      ? null
      : _rate(
          abandonmentTracked.where((g) => g.gameAbandoned == true).length,
          abandonmentTracked.length,
        );

  // Sample size is small enough that any finding should read as a
  // provisional tendency, not a firm conclusion (section L's own
  // instruction, and mirrors ExternalTestReport.sampleSizeCaveat's bands).
  final uniqueTesters = games.map((g) => g.testerId).whereType<String>().toSet().length;
  final hedge = uniqueTesters < 10;
  String tone(String text) => hedge ? '$text(暫定傾向、サンプル数が少ないため断定不可)' : text;

  void addRate(
    double? value,
    int sampleSize, {
    required double threshold,
    required bool above,
    required String category,
    required String title,
    required String metric,
    required String comparison,
    FindingSeverity severity = FindingSeverity.watch,
  }) {
    if (value == null) return;
    final triggered = above ? value >= threshold : value <= threshold;
    if (!triggered) return;
    findings.add(
      AnalysisFinding(
        severity: hedge && severity != FindingSeverity.critical
            ? FindingSeverity.info
            : severity,
        category: category,
        title: title,
        description: tone(
          '$title (${(value * 100).toStringAsFixed(1)}%, n=$sampleSize)',
        ),
        metric: metric,
        value: value,
        comparison: comparison,
        sampleSize: sampleSize,
      ),
    );
  }

  addRate(
    firstWinRate,
    decisive.length,
    threshold: 0.55,
    above: true,
    category: 'balance',
    title: '先手勝率が55%を超えている',
    metric: 'firstPlayerWinRate',
    comparison: '目安45-55%',
  );
  addRate(
    firstWinRate,
    decisive.length,
    threshold: 0.45,
    above: false,
    category: 'balance',
    title: '先手勝率が45%未満',
    metric: 'firstPlayerWinRate',
    comparison: '目安45-55%',
  );
  addRate(
    saviorWinRate,
    games.length,
    threshold: 0.55,
    above: true,
    category: 'balance',
    title: '救済者勝率が55%を超えている',
    metric: 'saviorWinRate',
    comparison: '目安45-55%',
  );
  addRate(
    saviorWinRate,
    games.length,
    threshold: 0.45,
    above: false,
    category: 'balance',
    title: '救済者勝率が45%未満',
    metric: 'saviorWinRate',
    comparison: '目安45-55%',
  );
  addRate(
    oneSidedRate,
    scoreDiffs.length,
    threshold: 0.25,
    above: true,
    category: 'balance',
    title: 'ワンサイド率が25%超',
    metric: 'oneSidedRate',
    comparison: '目安25%以下',
    severity: FindingSeverity.warning,
  );
  addRate(
    abandonmentRate,
    abandonmentTracked.length,
    threshold: 0.10,
    above: true,
    category: 'retention',
    title: 'abandonment率が10%以上',
    metric: 'abandonmentRate',
    comparison: '目安10%未満',
    severity: FindingSeverity.warning,
  );

  void addAverage(
    double? value,
    int sampleSize, {
    required double threshold,
    required bool below,
    required String title,
    required String metric,
    required String comparison,
  }) {
    if (value == null) return;
    final triggered = below ? value < threshold : value > threshold;
    if (!triggered) return;
    findings.add(
      AnalysisFinding(
        severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
        category: 'ratings',
        title: title,
        description: tone('$title (${value.toStringAsFixed(2)}, n=$sampleSize)'),
        metric: metric,
        value: value,
        comparison: comparison,
        sampleSize: sampleSize,
      ),
    );
  }

  final funN = games.map((g) => g.funRating).whereType<int>().length;
  final ruleN = games.map((g) => g.ruleUnderstandingRating).whereType<int>().length;
  final replayN = games.map((g) => g.replayIntentRating).whereType<int>().length;
  final depthN = games.map((g) => g.strategicDepthRating).whereType<int>().length;

  addAverage(
    fun,
    funN,
    threshold: 3.5,
    below: true,
    title: 'fun平均が3.5未満',
    metric: 'fun',
    comparison: '目安3.5以上',
  );
  addAverage(
    ruleUnderstanding,
    ruleN,
    threshold: 4.0,
    below: true,
    title: 'ruleUnderstanding平均が4.0未満',
    metric: 'ruleUnderstanding',
    comparison: '目安4.0以上',
  );
  addAverage(
    replayIntent,
    replayN,
    threshold: 3.5,
    below: true,
    title: 'replayIntent平均が3.5未満',
    metric: 'replayIntent',
    comparison: '目安3.5以上',
  );
  addAverage(
    strategicDepth,
    depthN,
    threshold: 3.5,
    below: true,
    title: 'strategicDepth平均が3.5未満',
    metric: 'strategicDepth',
    comparison: '目安3.5以上',
  );

  if (avgTurns != null) {
    if (avgTurns < 18) {
      findings.add(
        AnalysisFinding(
          severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
          category: 'tempo',
          title: '平均ターン数が18未満',
          description: tone('平均ターン数が18未満 (${avgTurns.toStringAsFixed(1)})'),
          metric: 'averageTurns',
          value: avgTurns,
          comparison: '目安18-26',
          sampleSize: games.length,
        ),
      );
    } else if (avgTurns > 26) {
      findings.add(
        AnalysisFinding(
          severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
          category: 'tempo',
          title: '平均ターン数が26超',
          description: tone('平均ターン数が26超 (${avgTurns.toStringAsFixed(1)})'),
          metric: 'averageTurns',
          value: avgTurns,
          comparison: '目安18-26',
          sampleSize: games.length,
        ),
      );
    }
  }

  // JUDGE未使用率が80%以上
  final judgeTracked = games
      .where(
        (g) =>
            g.saviorSpecialVerdictUsed != null &&
            g.executorSpecialVerdictUsed != null,
      )
      .toList();
  if (judgeTracked.isNotEmpty) {
    final unusedRate = _rate(
      judgeTracked
          .where(
            (g) =>
                g.saviorSpecialVerdictUsed == false &&
                g.executorSpecialVerdictUsed == false,
          )
          .length,
      judgeTracked.length,
    );
    if (unusedRate != null && unusedRate >= 0.8) {
      findings.add(
        AnalysisFinding(
          severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
          category: 'judge',
          title: 'JUDGE未使用率が80%以上',
          description: tone(
            'JUDGE未使用率が80%以上 (${(unusedRate * 100).toStringAsFixed(1)}%, n=${judgeTracked.length})',
          ),
          metric: 'judgeBothUnusedRate',
          value: unusedRate,
          comparison: '目安80%未満',
          sampleSize: judgeTracked.length,
        ),
      );
    }
  }

  // EYEを上限まで使い切る率が90%以上 (actions-loaded subset only).
  final eyeAnalysis = EyeAnalysis.compute(pool);
  if (eyeAnalysis.usedUpToCapRate != null && eyeAnalysis.usedUpToCapRate! >= 0.9) {
    findings.add(
      AnalysisFinding(
        severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
        category: 'eye',
        title: 'EYEを上限まで使い切る率が90%以上',
        description: tone(
          'EYEを上限まで使い切る率が90%以上 '
          '(${(eyeAnalysis.usedUpToCapRate! * 100).toStringAsFixed(1)}%, n=${eyeAnalysis.sampleSize})',
        ),
        metric: 'eyeUsedUpToCapRate',
        value: eyeAnalysis.usedUpToCapRate,
        comparison: '目安90%未満',
        sampleSize: eyeAnalysis.sampleSize,
      ),
    );
  }

  // 初回プレイヤーのruleUnderstandingが経験者より1.0以上低い
  final firstTimeRule = _avg(
    games.where(AdminOverviewStats.isFirstTimeSession).map((g) => g.ruleUnderstandingRating),
  );
  final experiencedRule = _avg(
    games.where(AdminOverviewStats.isExperiencedSession).map((g) => g.ruleUnderstandingRating),
  );
  if (firstTimeRule != null &&
      experiencedRule != null &&
      experiencedRule - firstTimeRule >= 1.0) {
    findings.add(
      AnalysisFinding(
        severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
        category: 'onboarding',
        title: '初回プレイヤーのruleUnderstandingが経験者より1.0以上低い',
        description: tone(
          '初回${firstTimeRule.toStringAsFixed(2)} vs 経験者${experiencedRule.toStringAsFixed(2)}',
        ),
        metric: 'ruleUnderstanding',
        value: firstTimeRule,
        comparison: '経験者との差1.0未満が目安',
        sampleSize: games.where(AdminOverviewStats.isFirstTimeSession).length,
      ),
    );
  }

  // 特定cpuDifficultyでプレイヤー勝率が35%未満 / 65%超
  final byDifficulty = _groupBy(games, (g) => g.cpuDifficulty);
  for (final entry in byDifficulty.entries) {
    final rate = _rate(
      entry.value.where((g) => g.winner == g.playerFaction).length,
      entry.value.length,
    );
    if (rate == null) continue;
    if (rate < 0.35) {
      findings.add(
        AnalysisFinding(
          severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
          category: 'cpu',
          title: '${entry.key}でプレイヤー勝率が35%未満',
          description: tone(
            '${entry.key}: プレイヤー勝率${(rate * 100).toStringAsFixed(1)}% (n=${entry.value.length})',
          ),
          metric: 'playerWinRateByCpuDifficulty',
          value: rate,
          comparison: '目安35-65%',
          sampleSize: entry.value.length,
        ),
      );
    } else if (rate > 0.65) {
      findings.add(
        AnalysisFinding(
          severity: hedge ? FindingSeverity.info : FindingSeverity.watch,
          category: 'cpu',
          title: '${entry.key}でプレイヤー勝率が65%超',
          description: tone(
            '${entry.key}: プレイヤー勝率${(rate * 100).toStringAsFixed(1)}% (n=${entry.value.length})',
          ),
          metric: 'playerWinRateByCpuDifficulty',
          value: rate,
          comparison: '目安35-65%',
          sampleSize: entry.value.length,
        ),
      );
    }
  }

  if (uniqueTesters < 10) {
    findings.add(
      AnalysisFinding(
        severity: FindingSeverity.info,
        category: 'meta',
        title: 'サンプル数不足',
        description:
            'ユニークテストプレイヤー数が$uniqueTesters人と少ないため、本レポートの数値は暫定傾向として扱ってください。',
        metric: 'uniqueTesterCount',
        value: uniqueTesters,
        comparison: '10人以上で傾向評価が可能',
        sampleSize: uniqueTesters,
      ),
    );
  }

  return findings;
}
