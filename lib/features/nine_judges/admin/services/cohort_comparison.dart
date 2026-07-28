import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_overview_stats.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';

/// Section 8: first-time vs. experienced player comparison for one cohort
/// (either "first-time" or "experienced").
class CohortStats {
  const CohortStats({
    required this.sampleSize,
    required this.fun,
    required this.ruleUnderstanding,
    required this.eyeTension,
    required this.strategicDepth,
    required this.replayIntent,
    required this.avgTurns,
    required this.avgScoreDiff,
    required this.playerWinRate,
    required this.judgeUsageRate,
    required this.avgEyeUsage,
    required this.avgEyeUsageSampleSize,
  });

  final int sampleSize;
  final RatingAverage fun;
  final RatingAverage ruleUnderstanding;
  final RatingAverage eyeTension;
  final RatingAverage strategicDepth;
  final RatingAverage replayIntent;
  final double? avgTurns;
  final double? avgScoreDiff;
  final double? playerWinRate;

  /// From the loaded GameSession's own `saviorSpecialVerdictUsed`/
  /// `executorSpecialVerdictUsed` fields — no actions fetch needed.
  final double? judgeUsageRate;

  /// Requires each game's `actions` subcollection, which the dashboard only
  /// fetches lazily when a detail view is opened (section 12/23) — so this
  /// is only computed over whichever games in this cohort happen to already
  /// have actions loaded. [avgEyeUsageSampleSize] reports how many that was;
  /// null (shown as "データ不足") when none have been opened yet.
  final double? avgEyeUsage;
  final int avgEyeUsageSampleSize;

  bool get hasEnoughData => sampleSize > 0;
}

class FirstTimeVsExperienced {
  const FirstTimeVsExperienced({
    required this.firstTime,
    required this.experienced,
  });

  final CohortStats firstTime;
  final CohortStats experienced;

  static double? _average(Iterable<num?> values) {
    final present = values.whereType<num>().toList();
    return present.isEmpty
        ? null
        : present.reduce((a, b) => a + b) / present.length;
  }

  static double? _rate(int value, int denominator) =>
      denominator == 0 ? null : value / denominator;

  static RatingAverage _rating(Iterable<int?> values) {
    final present = values.whereType<int>().toList();
    return RatingAverage(
      average: present.isEmpty
          ? null
          : present.reduce((a, b) => a + b) / present.length,
      n: present.length,
    );
  }

  static CohortStats _statsFor(List<PlaytestRecord> pool) {
    final games = pool.map((r) => r.session).toList();
    final playerWins = games.where((g) => g.winner == g.playerFaction).length;

    bool? judgeUsedForPlayer(GameSession s) => s.playerFaction == 'savior'
        ? s.saviorSpecialVerdictUsed
        : s.executorSpecialVerdictUsed;
    final judgeTracked = games.where(
      (g) => judgeUsedForPlayer(g) != null,
    ).toList();

    final withActions = pool.where((r) => r.actions != null).toList();
    final eyeCounts = withActions
        .map(
          (r) =>
              r.actions!.where((a) => a.actionType == 'eye').length.toDouble(),
        )
        .toList();

    return CohortStats(
      sampleSize: games.length,
      fun: _rating(games.map((g) => g.funRating)),
      ruleUnderstanding: _rating(games.map((g) => g.ruleUnderstandingRating)),
      eyeTension: _rating(games.map((g) => g.eyeTensionRating)),
      strategicDepth: _rating(games.map((g) => g.strategicDepthRating)),
      replayIntent: _rating(games.map((g) => g.replayIntentRating)),
      avgTurns: _average(games.map((g) => g.totalTurns)),
      avgScoreDiff: _average(
        games
            .where((g) => g.saviorScore != null && g.executorScore != null)
            .map((g) => (g.saviorScore! - g.executorScore!).abs()),
      ),
      playerWinRate: _rate(playerWins, games.length),
      judgeUsageRate: _rate(
        judgeTracked.where((g) => judgeUsedForPlayer(g) == true).length,
        judgeTracked.length,
      ),
      avgEyeUsage: eyeCounts.isEmpty ? null : _average(eyeCounts),
      avgEyeUsageSampleSize: eyeCounts.length,
    );
  }

  factory FirstTimeVsExperienced.compute(List<PlaytestRecord> records) {
    final firstTimePool = records
        .where((r) => AdminOverviewStats.isFirstTimeSession(r.session))
        .toList();
    final experiencedPool = records
        .where((r) => AdminOverviewStats.isExperiencedSession(r.session))
        .toList();
    return FirstTimeVsExperienced(
      firstTime: _statsFor(firstTimePool),
      experienced: _statsFor(experiencedPool),
    );
  }
}
