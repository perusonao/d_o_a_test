import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';

/// Section 10 filters. Applied client-side over whichever pages are
/// currently loaded — the admin logs tab must show a "現在読み込み済みのデータ内で
/// 絞り込み中" notice whenever any filter is active, since this never
/// re-queries Firestore for a filtered result.
class AdminLogFilters {
  const AdminLogFilters({
    this.from,
    this.to,
    this.gameId,
    this.testerLabel,
    this.rulesVersion,
    this.gameVersion,
    this.playerFaction,
    this.winner,
    this.firstPlayer,
    this.cpuDifficulty,
    this.isFirstGame,
    this.hasFeedbackComment,
    this.hasAnyRating,
  });

  final DateTime? from;
  final DateTime? to;
  final String? gameId;

  /// Matched against the anonymized "Player NNN" label, never the raw id.
  final String? testerLabel;
  final String? rulesVersion;
  final String? gameVersion;
  final String? playerFaction;
  final String? winner;
  final String? firstPlayer;
  final String? cpuDifficulty;
  final bool? isFirstGame;
  final bool? hasFeedbackComment;
  final bool? hasAnyRating;

  bool get isActive =>
      from != null ||
      to != null ||
      (gameId?.isNotEmpty ?? false) ||
      (testerLabel?.isNotEmpty ?? false) ||
      rulesVersion != null ||
      gameVersion != null ||
      playerFaction != null ||
      winner != null ||
      firstPlayer != null ||
      cpuDifficulty != null ||
      isFirstGame != null ||
      hasFeedbackComment != null ||
      hasAnyRating != null;

  AdminLogFilters clearAll() => const AdminLogFilters();

  AdminLogFilters copyWith({
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? gameId,
    String? testerLabel,
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
    bool? hasFeedbackComment,
    bool clearHasFeedbackComment = false,
    bool? hasAnyRating,
    bool clearHasAnyRating = false,
  }) => AdminLogFilters(
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
    gameId: gameId ?? this.gameId,
    testerLabel: testerLabel ?? this.testerLabel,
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
    hasFeedbackComment: clearHasFeedbackComment
        ? null
        : (hasFeedbackComment ?? this.hasFeedbackComment),
    hasAnyRating: clearHasAnyRating ? null : (hasAnyRating ?? this.hasAnyRating),
  );

  bool matches(PlaytestRecord record, String testerLabelFor) {
    final s = record.session;
    if (from != null &&
        (s.finishedAt == null || s.finishedAt!.isBefore(from!))) {
      return false;
    }
    if (to != null && (s.finishedAt == null || s.finishedAt!.isAfter(to!))) {
      return false;
    }
    if (gameId != null &&
        gameId!.isNotEmpty &&
        !s.gameId.toLowerCase().contains(gameId!.toLowerCase())) {
      return false;
    }
    if (testerLabel != null &&
        testerLabel!.isNotEmpty &&
        !testerLabelFor.toLowerCase().contains(testerLabel!.toLowerCase())) {
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
    if (hasFeedbackComment != null) {
      final has = (s.feedbackComment?.trim().isNotEmpty ?? false);
      if (has != hasFeedbackComment) return false;
    }
    if (hasAnyRating != null) {
      final has = [
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
      if (has != hasAnyRating) return false;
    }
    return true;
  }
}
