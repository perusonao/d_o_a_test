import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

double? _average(Iterable<num?> values) {
  final present = values.whereType<num>().toList();
  return present.isEmpty
      ? null
      : present.reduce((a, b) => a + b) / present.length;
}

double? _rate(int value, int denominator) =>
    denominator == 0 ? null : value / denominator;

/// Section 14: EYE analysis. Everything here (per-action counts, candidate
/// counts, decision times, target positions) lives only in each game's
/// `actions` subcollection, which the dashboard fetches lazily, only when a
/// detail view is opened (section 12/23) — never in bulk for every loaded
/// game. So this is computed over whichever loaded records happen to
/// already have `actions` populated (i.e. a human has opened their detail
/// view during this session); [sampleSize] reports how many that was. Split
/// by rulesVersion since 1.1-and-earlier games have no EYE cap.
class EyeAnalysis {
  const EyeAnalysis({
    required this.sampleSize,
    required this.avgUsesPerGame,
    required this.avgUsesPerGamePlayerSide,
    required this.avgUsesPerGameCpuSide,
    required this.usedUpToCapRate,
    required this.avgCandidateCount,
    required this.candidateCountOneRate,
    required this.avgDecisionTimeMs,
    required this.selectionCountByCenterPosition,
    required this.bothFactionsSameTargetGames,
  });

  final int sampleSize;
  final double? avgUsesPerGame;
  final double? avgUsesPerGamePlayerSide;
  final double? avgUsesPerGameCpuSide;

  /// Rate of games (rulesVersion 1.2 only, where the cap applies) where EYE
  /// was used the full [NineJudgesConfig.eyeMaxUsesPerPlayer] times by at
  /// least one faction.
  final double? usedUpToCapRate;
  final double? avgCandidateCount;
  final double? candidateCountOneRate;
  final double? avgDecisionTimeMs;

  /// Selection counts for each of the 3 center board positions (indices 3-5
  /// — see [NineJudgesConfig.centerIndices]), keyed by positionIndex.
  final Map<int, int> selectionCountByCenterPosition;

  final int bothFactionsSameTargetGames;

  factory EyeAnalysis.compute(List<PlaytestRecord> records) {
    final withActions = records.where((r) => r.actions != null).toList();
    final eyeActionsPerGame = withActions
        .map((r) => r.actions!.where((a) => a.actionType == 'eye').toList())
        .toList();
    final allEyeActions = eyeActionsPerGame.expand((e) => e).toList();

    final playerSideCounts = <int>[];
    final cpuSideCounts = <int>[];
    for (final record in withActions) {
      final eyeActions = record.actions!.where((a) => a.actionType == 'eye');
      playerSideCounts.add(
        eyeActions.where((a) => a.faction == record.session.playerFaction).length,
      );
      cpuSideCounts.add(
        eyeActions.where((a) => a.faction == record.session.cpuFaction).length,
      );
    }

    var cappedGames = 0;
    var cappedEligibleGames = 0;
    for (final record in withActions) {
      final s = record.session;
      final ruleVersion = switch (s.rulesVersion) {
        '1.1' => NineJudgesRuleVersion.v1_1,
        '1.2' => NineJudgesRuleVersion.v1_2,
        _ => null,
      };
      final cap = ruleVersion == null
          ? null
          : NineJudgesConfig.eyeMaxUsesPerPlayer(ruleVersion);
      if (cap == null) continue;
      cappedEligibleGames++;
      final eyeActions = record.actions!.where((a) => a.actionType == 'eye');
      final byFaction = <String, int>{};
      for (final a in eyeActions) {
        byFaction[a.faction] = (byFaction[a.faction] ?? 0) + 1;
      }
      if (byFaction.values.any((count) => count >= cap)) cappedGames++;
    }

    final candidates = allEyeActions
        .map((a) => a.eyeCandidateCount)
        .whereType<int>()
        .toList();
    final decisionTimes = allEyeActions
        .map((a) => a.turnDecisionTimeMs)
        .whereType<int>()
        .toList();

    final positionCounts = <int, int>{};
    for (final record in withActions) {
      final byId = {
        for (final p in record.session.initialBoard) p.personId: p.positionIndex,
      };
      for (final action in record.session.actions.where(
        (a) => a.actionType == 'eye',
      )) {
        final position = byId[action.targetPersonId];
        if (position != null) {
          positionCounts[position] = (positionCounts[position] ?? 0) + 1;
        }
      }
    }

    var sameTargetGames = 0;
    for (final record in withActions) {
      final byFactionTargets = <String, Set<String>>{};
      for (final a in record.actions!.where((a) => a.actionType == 'eye')) {
        byFactionTargets
            .putIfAbsent(a.faction, () => {})
            .add(a.targetPersonId);
      }
      final targetSets = byFactionTargets.values.toList();
      if (targetSets.length >= 2 &&
          targetSets[0].intersection(targetSets[1]).isNotEmpty) {
        sameTargetGames++;
      }
    }

    return EyeAnalysis(
      sampleSize: withActions.length,
      avgUsesPerGame: _average(eyeActionsPerGame.map((e) => e.length)),
      avgUsesPerGamePlayerSide: _average(playerSideCounts),
      avgUsesPerGameCpuSide: _average(cpuSideCounts),
      usedUpToCapRate: cappedEligibleGames == 0
          ? null
          : _rate(cappedGames, cappedEligibleGames),
      avgCandidateCount: _average(candidates),
      candidateCountOneRate: candidates.isEmpty
          ? null
          : _rate(candidates.where((c) => c == 1).length, candidates.length),
      avgDecisionTimeMs: _average(decisionTimes),
      selectionCountByCenterPosition: positionCounts,
      bothFactionsSameTargetGames: sameTargetGames,
    );
  }
}

/// Section 15: JUDGE (special verdict) analysis. Usage rates and opportunity
/// counts come from each GameSession's own top-level fields (no actions
/// fetch needed, so these cover ALL loaded games). Turn-of-use and
/// decision-time-of-use need the `actions` subcollection, so those two are
/// only computed over records with actions already loaded — shown as
/// "記録なし" (never assumed 0) when unavailable, per section 15.
class JudgeAnalysis {
  const JudgeAnalysis({
    required this.saviorUsageRate,
    required this.executorUsageRate,
    required this.bothUnusedRate,
    required this.usedGamesCount,
    required this.unusedGamesCount,
    required this.avgOpportunityCountSavior,
    required this.avgOpportunityCountExecutor,
    required this.avgMaxVisibleBonusWhileAvailable,
    required this.highBonusRate,
    required this.avgTurnOfUse,
    required this.avgDecisionTimeMsOfUse,
    required this.turnOfUseSampleSize,
  });

  /// Section 15: provisional "high bonus" threshold, named per the task's
  /// explicit "must be a named constant" instruction.
  static const highBonusThreshold = 7;

  final double? saviorUsageRate;
  final double? executorUsageRate;
  final double? bothUnusedRate;
  final int usedGamesCount;
  final int unusedGamesCount;
  final double? avgOpportunityCountSavior;
  final double? avgOpportunityCountExecutor;
  final double? avgMaxVisibleBonusWhileAvailable;
  final double? highBonusRate;

  final double? avgTurnOfUse;
  final double? avgDecisionTimeMsOfUse;
  final int turnOfUseSampleSize;

  factory JudgeAnalysis.compute(List<PlaytestRecord> records) {
    final games = records.map((r) => r.session).toList();
    final saviorTracked = games
        .where((g) => g.saviorSpecialVerdictUsed != null)
        .toList();
    final executorTracked = games
        .where((g) => g.executorSpecialVerdictUsed != null)
        .toList();
    final bothTracked = games
        .where(
          (g) =>
              g.saviorSpecialVerdictUsed != null &&
              g.executorSpecialVerdictUsed != null,
        )
        .toList();

    final usedGames = bothTracked
        .where(
          (g) =>
              g.saviorSpecialVerdictUsed == true ||
              g.executorSpecialVerdictUsed == true,
        )
        .length;
    final unusedGames = bothTracked
        .where(
          (g) =>
              g.saviorSpecialVerdictUsed == false &&
              g.executorSpecialVerdictUsed == false,
        )
        .length;

    final maxVisibleBonuses = <int>[
      for (final g in games) ...[
        if (g.maxVisibleBonusWhileJudgeAvailableSavior != null)
          g.maxVisibleBonusWhileJudgeAvailableSavior!,
        if (g.maxVisibleBonusWhileJudgeAvailableExecutor != null)
          g.maxVisibleBonusWhileJudgeAvailableExecutor!,
      ],
    ];

    final withActions = records.where((r) => r.actions != null).toList();
    final judgeUses = withActions
        .expand((r) => r.actions!.where((a) => a.actionType == 'specialVerdict'))
        .toList();

    return JudgeAnalysis(
      saviorUsageRate: _rate(
        saviorTracked.where((g) => g.saviorSpecialVerdictUsed == true).length,
        saviorTracked.length,
      ),
      executorUsageRate: _rate(
        executorTracked
            .where((g) => g.executorSpecialVerdictUsed == true)
            .length,
        executorTracked.length,
      ),
      bothUnusedRate: _rate(unusedGames, bothTracked.length),
      usedGamesCount: usedGames,
      unusedGamesCount: unusedGames,
      avgOpportunityCountSavior: _average(
        games.map((g) => g.judgeOpportunityCountSavior),
      ),
      avgOpportunityCountExecutor: _average(
        games.map((g) => g.judgeOpportunityCountExecutor),
      ),
      avgMaxVisibleBonusWhileAvailable: _average(maxVisibleBonuses),
      highBonusRate: maxVisibleBonuses.isEmpty
          ? null
          : _rate(
              maxVisibleBonuses
                  .where((b) => b >= highBonusThreshold)
                  .length,
              maxVisibleBonuses.length,
            ),
      avgTurnOfUse: judgeUses.isEmpty
          ? null
          : _average(judgeUses.map((a) => a.turnNumber)),
      avgDecisionTimeMsOfUse: _average(
        judgeUses.map((a) => a.turnDecisionTimeMs),
      ),
      turnOfUseSampleSize: judgeUses.length,
    );
  }
}

/// Section 16: reverseLife/reverseDeath analysis. Usage rates and
/// winner/loser-side rates use only top-level GameSession fields (full
/// dataset); avg turn used needs `actions` and is limited to records with
/// actions already loaded. Games missing the reverse fields altogether
/// (pre-reverse-feature logs) are excluded from every rate's denominator.
class ReverseAnalysis {
  const ReverseAnalysis({
    required this.saviorUsageRate,
    required this.executorUsageRate,
    required this.neitherUsedRate,
    required this.winnerSideUsageRate,
    required this.loserSideUsageRate,
    required this.avgTurnUsed,
    required this.avgTurnUsedSampleSize,
  });

  final double? saviorUsageRate;
  final double? executorUsageRate;
  final double? neitherUsedRate;
  final double? winnerSideUsageRate;
  final double? loserSideUsageRate;
  final double? avgTurnUsed;
  final int avgTurnUsedSampleSize;

  factory ReverseAnalysis.compute(List<PlaytestRecord> records) {
    final games = records.map((r) => r.session).toList();
    final saviorTracked = games
        .where((g) => g.saviorReverseActionUsed != null)
        .toList();
    final executorTracked = games
        .where((g) => g.executorReverseActionUsed != null)
        .toList();
    final bothTracked = games
        .where(
          (g) =>
              g.saviorReverseActionUsed != null &&
              g.executorReverseActionUsed != null,
        )
        .toList();

    final decisive = bothTracked
        .where((g) => g.winner == 'savior' || g.winner == 'executor')
        .toList();
    bool winnerUsedReverse(GameSession g) => g.winner == 'savior'
        ? g.saviorReverseActionUsed == true
        : g.executorReverseActionUsed == true;
    bool loserUsedReverse(GameSession g) => g.winner == 'savior'
        ? g.executorReverseActionUsed == true
        : g.saviorReverseActionUsed == true;

    final withActions = records.where((r) => r.actions != null).toList();
    final reverseActions = withActions
        .expand((r) => r.actions!.where((a) => a.wasReverseAction))
        .toList();

    return ReverseAnalysis(
      saviorUsageRate: _rate(
        saviorTracked.where((g) => g.saviorReverseActionUsed == true).length,
        saviorTracked.length,
      ),
      executorUsageRate: _rate(
        executorTracked
            .where((g) => g.executorReverseActionUsed == true)
            .length,
        executorTracked.length,
      ),
      neitherUsedRate: _rate(
        bothTracked
            .where(
              (g) =>
                  g.saviorReverseActionUsed == false &&
                  g.executorReverseActionUsed == false,
            )
            .length,
        bothTracked.length,
      ),
      winnerSideUsageRate: _rate(
        decisive.where(winnerUsedReverse).length,
        decisive.length,
      ),
      loserSideUsageRate: _rate(
        decisive.where(loserUsedReverse).length,
        decisive.length,
      ),
      avgTurnUsed: reverseActions.isEmpty
          ? null
          : _average(reverseActions.map((a) => a.turnNumber)),
      avgTurnUsedSampleSize: reverseActions.length,
    );
  }
}
