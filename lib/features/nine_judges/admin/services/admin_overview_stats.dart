import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';

/// One rating's average excluding null responses, plus the response count
/// `n` that made up that average (section 7: "楽しさ 4.2/5 n=12").
class RatingAverage {
  const RatingAverage({required this.average, required this.n});
  final double? average;
  final int n;
}

/// Section 7's overview dashboard cards, computed from whatever
/// [PlaytestRecord]s are currently loaded in the admin screen (never a
/// separate full-collection fetch — see section 10's "filtering within
/// loaded data" rule, which applies to these aggregates too).
class AdminOverviewStats {
  const AdminOverviewStats({
    required this.totalGames,
    required this.uniqueTesterCount,
    required this.firstTimePlayerCount,
    required this.repeaterCount,
    required this.avgPlayNumber,
    required this.avgTurns,
    required this.avgScoreDiff,
    required this.saviorWinRate,
    required this.executorWinRate,
    required this.firstPlayerWinRate,
    required this.secondPlayerWinRate,
    required this.avgGameDurationMinutes,
    required this.abandonmentRate,
    required this.abandonmentSampleSize,
    required this.ratings,
  });

  final int totalGames;
  final int uniqueTesterCount;

  /// Unique testers whose loaded games are all "first game" (see
  /// [isFirstTimeSession]) — i.e. no evidence yet of a repeat play.
  final int firstTimePlayerCount;

  /// Unique testers with at least one loaded game showing evidence of a
  /// repeat play (see [isExperiencedSession]).
  final int repeaterCount;

  final double? avgPlayNumber;
  final double? avgTurns;
  final double? avgScoreDiff;
  final double? saviorWinRate;
  final double? executorWinRate;
  final double? firstPlayerWinRate;
  final double? secondPlayerWinRate;
  final double? avgGameDurationMinutes;

  /// Null when no loaded game has a non-null `gameAbandoned` (old logs never
  /// counted as "not abandoned" by assumption — see [abandonmentSampleSize]).
  final double? abandonmentRate;
  final int abandonmentSampleSize;

  final Map<String, RatingAverage> ratings;

  static const ratingKeys = [
    'fun',
    'reading',
    'luck',
    'tempo',
    'eyeChoice',
    'ruleUnderstanding',
    'judgeUsefulness',
    'eyeTension',
    'strategicDepth',
    'replayIntent',
  ];

  static const ratingLabels = {
    'fun': '楽しさ',
    'reading': '読み合い',
    'luck': '運要素',
    'tempo': 'テンポ',
    'eyeChoice': 'EYEの選択',
    'ruleUnderstanding': 'ルール理解度',
    'judgeUsefulness': 'JUDGEの有用性',
    'eyeTension': 'EYEの緊張感',
    'strategicDepth': '戦略の深さ',
    'replayIntent': '再プレイ意向',
  };

  /// Section 8: a game counts as this tester's "first game" evidence if
  /// either field says so — both are checked because either one alone may
  /// be missing/unreliable on some logs.
  static bool isFirstTimeSession(GameSession s) =>
      s.isFirstGame == true || s.playNumber == 1;

  static bool isExperiencedSession(GameSession s) =>
      s.isFirstGame == false || (s.playNumber != null && s.playNumber! >= 2);

  /// The raw 1-5 rating value for [key] (one of [ratingKeys]) on session
  /// [s], or null if that rating wasn't answered. Public so other
  /// admin-analysis code (e.g. the AI-analysis report) reads ratings via
  /// this single switch rather than re-deriving its own field mapping.
  static int? ratingValue(GameSession s, String key) => switch (key) {
    'fun' => s.funRating,
    'reading' => s.readingRating,
    'luck' => s.luckRating,
    'tempo' => s.tempoRating,
    'eyeChoice' => s.eyeChoiceRating,
    'ruleUnderstanding' => s.ruleUnderstandingRating,
    'judgeUsefulness' => s.judgeUsefulnessRating,
    'eyeTension' => s.eyeTensionRating,
    'strategicDepth' => s.strategicDepthRating,
    'replayIntent' => s.replayIntentRating,
    _ => null,
  };

  static double? _average(Iterable<num?> values) {
    final present = values.whereType<num>().toList();
    return present.isEmpty
        ? null
        : present.reduce((a, b) => a + b) / present.length;
  }

  static double? _rate(int value, int denominator) =>
      denominator == 0 ? null : value / denominator;

  factory AdminOverviewStats.compute(List<GameSession> games) {
    final testerGames = <String, List<GameSession>>{};
    for (final g in games) {
      final id = g.testerId;
      if (id != null) testerGames.putIfAbsent(id, () => []).add(g);
    }
    var firstTimeCount = 0;
    var repeaterCount = 0;
    for (final testerSessions in testerGames.values) {
      if (testerSessions.any(isExperiencedSession)) {
        repeaterCount++;
      } else {
        firstTimeCount++;
      }
    }

    final decisive = games
        .where((g) => g.winner != null && g.winner != 'draw')
        .toList();
    final firstWins = decisive.where((g) => g.winner == g.firstPlayer).length;

    final durations = games
        .where((g) => g.finishedAt != null)
        .map((g) => g.finishedAt!.difference(g.startedAt).inSeconds / 60.0)
        .toList();

    final abandonmentTracked = games
        .where((g) => g.gameAbandoned != null)
        .toList();

    final ratings = <String, RatingAverage>{
      for (final key in ratingKeys)
        key: () {
          final values = games
              .map((s) => ratingValue(s, key)?.toDouble())
              .whereType<double>()
              .toList();
          return RatingAverage(
            average: values.isEmpty
                ? null
                : values.reduce((a, b) => a + b) / values.length,
            n: values.length,
          );
        }(),
    };

    return AdminOverviewStats(
      totalGames: games.length,
      uniqueTesterCount: testerGames.length,
      firstTimePlayerCount: firstTimeCount,
      repeaterCount: repeaterCount,
      avgPlayNumber: _average(games.map((g) => g.playNumber)),
      avgTurns: _average(games.map((g) => g.totalTurns)),
      avgScoreDiff: _average(
        games
            .where((g) => g.saviorScore != null && g.executorScore != null)
            .map((g) => (g.saviorScore! - g.executorScore!).abs()),
      ),
      saviorWinRate: _rate(
        games.where((g) => g.winner == 'savior').length,
        games.length,
      ),
      executorWinRate: _rate(
        games.where((g) => g.winner == 'executor').length,
        games.length,
      ),
      firstPlayerWinRate: _rate(firstWins, decisive.length),
      secondPlayerWinRate: _rate(decisive.length - firstWins, decisive.length),
      avgGameDurationMinutes: _average(durations),
      abandonmentRate: _rate(
        abandonmentTracked.where((g) => g.gameAbandoned == true).length,
        abandonmentTracked.length,
      ),
      abandonmentSampleSize: abandonmentTracked.length,
      ratings: ratings,
    );
  }
}
