import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';

/// How many games to pull as the analysis pool before [AnalysisFilter]'s own
/// field filters narrow it further (section 3). [allLoaded] never issues a
/// new Firestore query — it reuses whatever the ゲームログ tab has already
/// paginated in.
enum AnalysisSource {
  latest20(20, '最新20件'),
  latest50(50, '最新50件'),
  latest100(100, '最新100件'),
  allLoaded(null, '現在読み込み済みの全件');

  const AnalysisSource(this.limit, this.label);

  /// Firestore query limit for this source, or null for [allLoaded] (no
  /// new query — see [AnalysisSource.allLoaded]).
  final int? limit;
  final String label;
}

enum AnalysisMode {
  /// playtests本体のみ(actionsは取得しない) — section 4's default.
  basic('基本分析'),

  /// 対象ゲームのactionsも取得する(section 4) — Firestore読み取りが増える。
  detailed('詳細分析');

  const AnalysisMode(this.label);
  final String label;
}

/// Section 3's analysis-target selection: a [source] pool, further narrowed
/// by these field filters (applied client-side over whatever the source
/// fetched — never a new composite Firestore query, per section 11/23).
class AnalysisFilter {
  const AnalysisFilter({
    this.source = AnalysisSource.latest50,
    this.mode = AnalysisMode.basic,
    this.from,
    this.to,
    this.rulesVersion,
    this.gameVersion,
    this.playerFaction,
    this.winner,
    this.firstPlayer,
    this.cpuDifficulty,
    this.isFirstGame,
    this.testCohort,
    this.ratedOnly = false,
    this.commentedOnly = false,
  });

  final AnalysisSource source;
  final AnalysisMode mode;
  final DateTime? from;
  final DateTime? to;
  final String? rulesVersion;
  final String? gameVersion;
  final String? playerFaction;
  final String? winner;
  final String? firstPlayer;
  final String? cpuDifficulty;
  final bool? isFirstGame;
  final String? testCohort;
  final bool ratedOnly;
  final bool commentedOnly;

  bool get hasFieldFilters =>
      from != null ||
      to != null ||
      rulesVersion != null ||
      gameVersion != null ||
      playerFaction != null ||
      winner != null ||
      firstPlayer != null ||
      cpuDifficulty != null ||
      isFirstGame != null ||
      testCohort != null ||
      ratedOnly ||
      commentedOnly;

  AnalysisFilter copyWith({
    AnalysisSource? source,
    AnalysisMode? mode,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? rulesVersion,
    bool clearRulesVersion = false,
    String? gameVersion,
    bool clearGameVersion = false,
    String? playerFaction,
    bool clearPlayerFaction = false,
    String? winner,
    bool clearWinner = false,
    String? firstPlayer,
    bool clearFirstPlayer = false,
    String? cpuDifficulty,
    bool clearCpuDifficulty = false,
    bool? isFirstGame,
    bool clearIsFirstGame = false,
    String? testCohort,
    bool clearTestCohort = false,
    bool? ratedOnly,
    bool? commentedOnly,
  }) => AnalysisFilter(
    source: source ?? this.source,
    mode: mode ?? this.mode,
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
    rulesVersion: clearRulesVersion ? null : (rulesVersion ?? this.rulesVersion),
    gameVersion: clearGameVersion ? null : (gameVersion ?? this.gameVersion),
    playerFaction: clearPlayerFaction
        ? null
        : (playerFaction ?? this.playerFaction),
    winner: clearWinner ? null : (winner ?? this.winner),
    firstPlayer: clearFirstPlayer ? null : (firstPlayer ?? this.firstPlayer),
    cpuDifficulty: clearCpuDifficulty
        ? null
        : (cpuDifficulty ?? this.cpuDifficulty),
    isFirstGame: clearIsFirstGame ? null : (isFirstGame ?? this.isFirstGame),
    testCohort: clearTestCohort ? null : (testCohort ?? this.testCohort),
    ratedOnly: ratedOnly ?? this.ratedOnly,
    commentedOnly: commentedOnly ?? this.commentedOnly,
  );

  static bool _hasAnyRating(PlaytestRecord r) {
    final s = r.session;
    return [
      s.funRating,
      s.readingRating,
      s.luckRating,
      s.tempoRating,
      s.eyeChoiceRating,
      s.ruleUnderstandingRating,
      s.judgeUsefulnessRating,
      s.eyeTensionRating,
      s.strategicDepthRating,
      s.replayIntentRating,
    ].any((r) => r != null);
  }

  /// Applies only this filter's field-refinement conditions — the [source]
  /// itself is resolved separately (fresh Firestore fetch vs. reusing
  /// already-loaded records) before this runs.
  bool matches(PlaytestRecord record) {
    final s = record.session;
    if (from != null &&
        (s.finishedAt == null || s.finishedAt!.isBefore(from!))) {
      return false;
    }
    if (to != null && (s.finishedAt == null || s.finishedAt!.isAfter(to!))) {
      return false;
    }
    if (rulesVersion != null && s.rulesVersion != rulesVersion) return false;
    if (gameVersion != null && s.gameVersion != gameVersion) return false;
    if (playerFaction != null && s.playerFaction != playerFaction) {
      return false;
    }
    if (winner != null && s.winner != winner) return false;
    if (firstPlayer != null && s.firstPlayer != firstPlayer) return false;
    if (cpuDifficulty != null && s.cpuDifficulty != cpuDifficulty) {
      return false;
    }
    if (isFirstGame != null && s.isFirstGame != isFirstGame) return false;
    if (testCohort != null && s.testCohort != testCohort) return false;
    if (ratedOnly && !_hasAnyRating(record)) return false;
    if (commentedOnly && (record.session.feedbackComment ?? '').trim().isEmpty) {
      return false;
    }
    return true;
  }
}
