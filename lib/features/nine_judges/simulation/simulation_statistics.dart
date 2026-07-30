import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';

class SimulationStatistics {
  const SimulationStatistics._(this.values);

  final Map<String, Object> values;

  factory SimulationStatistics.fromResults(
    List<SimulationResult> results,
    SimulationConfig config,
  ) {
    final games = results.length;
    int wins(Faction faction) =>
        results.where((result) => result.winner == faction).length;
    double average(num Function(SimulationResult result) read) =>
        results.fold<double>(0, (sum, result) => sum + read(result)) / games;
    final firstWins = results
        .where((result) => result.winner == result.firstPlayer)
        .length;
    final draws = results.where((result) => result.winner == null).length;
    final eyeTotal = results.fold<int>(
      0,
      (sum, result) => sum + result.totalEyeCount,
    );
    final redundantEyes = results.fold<int>(
      0,
      (sum, result) => sum + result.totalRedundantEyeCount,
    );
    final judgeBonuses = results
        .expand((result) => result.judgeBonuses)
        .toList();
    final highSavior = results.fold<int>(
      0,
      (sum, result) => sum + result.highBonusWonBySavior,
    );
    final highExecutor = results.fold<int>(
      0,
      (sum, result) => sum + result.highBonusWonByExecutor,
    );
    final turnValues = results.map((result) => result.totalTurns).toList();
    final diffValues = results
        .map((result) => result.absoluteScoreDiff)
        .toList();
    final bonusCaptures = <String, Object>{
      for (var bonus = 1; bonus <= 9; bonus++)
        '$bonus': {
          'savior': results
              .expand((result) => result.bonusValuesWonBySavior)
              .where((value) => value == bonus)
              .length,
          'executor': results
              .expand((result) => result.bonusValuesWonByExecutor)
              .where((value) => value == bonus)
              .length,
        },
    };
    double rate(int value, [int? denominator]) =>
        (denominator ?? games) == 0 ? 0 : value / (denominator ?? games);

    // Section 5 (admin "ゲームバランス分析" tool): usage rate + win rate for
    // every trackable card. Adding a future card/rule is just one more
    // entry here — [Faction]-neutral by construction (some cards, like the
    // one-shot reverse actions, are only ever legal for a single faction;
    // that's simply reflected as a zero count on the other side).
    Map<String, Object> cardUsage({
      required int Function(SimulationResult) savior,
      required int Function(SimulationResult) executor,
    }) {
      final totalSavior = results.fold<int>(0, (sum, r) => sum + savior(r));
      final totalExecutor = results.fold<int>(
        0,
        (sum, r) => sum + executor(r),
      );
      final outcomes = <bool>[
        for (final r in results)
          if (r.winner != null) ...[
            if (savior(r) > 0) r.winner == Faction.savior,
            if (executor(r) > 0) r.winner == Faction.executor,
          ],
      ];
      final gamesUsed = results
          .where((r) => savior(r) > 0 || executor(r) > 0)
          .length;
      return {
        'timesUsedTotal': totalSavior + totalExecutor,
        'timesUsedSavior': totalSavior,
        'timesUsedExecutor': totalExecutor,
        'averagePerGame': (totalSavior + totalExecutor) / games,
        'gamesUsedRate': rate(gamesUsed),
        'winRateWhenUsed': outcomes.isEmpty
            ? 0.0
            : outcomes.where((used) => used).length / outcomes.length,
      };
    }

    final cardUsageStats = <String, Object>{
      'LIFE': cardUsage(
        savior: (r) => r.saviorLifeCount,
        executor: (r) => r.executorLifeCount,
      ),
      'DEATH': cardUsage(
        savior: (r) => r.saviorDeathCount,
        executor: (r) => r.executorDeathCount,
      ),
      'EYE': cardUsage(
        savior: (r) => r.saviorEyeCount,
        executor: (r) => r.executorEyeCount,
      ),
      'JUDGE': cardUsage(
        savior: (r) => r.saviorJudgeUsed ? 1 : 0,
        executor: (r) => r.executorJudgeUsed ? 1 : 0,
      ),
      // Only ever legal for one faction each — see NineJudgesRules.
      'ReverseLIFE': cardUsage(
        savior: (r) => 0,
        executor: (r) => r.executorReverseUsed ? 1 : 0,
      ),
      'ReverseDEATH': cardUsage(
        savior: (r) => r.saviorReverseUsed ? 1 : 0,
        executor: (r) => 0,
      ),
      'SPECIAL_VERDICT': cardUsage(
        savior: (r) => r.saviorNaturalConfirmationCount,
        executor: (r) => r.executorNaturalConfirmationCount,
      ),
    };

    // Section 6: per bonus-value (1-9) capture rate + win rate/average
    // final score for whichever faction captured it.
    final bonusAnalysis = <String, Object>{
      for (var bonus = 1; bonus <= 9; bonus++)
        '$bonus': () {
          final saviorGames = results
              .where((r) => r.bonusValuesWonBySavior.contains(bonus))
              .toList();
          final executorGames = results
              .where((r) => r.bonusValuesWonByExecutor.contains(bonus))
              .toList();
          final outcomes = <bool>[
            for (final r in saviorGames)
              if (r.winner != null) r.winner == Faction.savior,
            for (final r in executorGames)
              if (r.winner != null) r.winner == Faction.executor,
          ];
          return {
            'saviorCaptures': saviorGames.length,
            'executorCaptures': executorGames.length,
            'winRateWhenCaptured': outcomes.isEmpty
                ? 0.0
                : outcomes.where((won) => won).length / outcomes.length,
            'averageFinalScoreWhenCapturedBySavior': saviorGames.isEmpty
                ? 0.0
                : saviorGames.fold<int>(0, (sum, r) => sum + r.saviorScore) /
                      saviorGames.length,
            'averageFinalScoreWhenCapturedByExecutor': executorGames.isEmpty
                ? 0.0
                : executorGames.fold<int>(
                        0,
                        (sum, r) => sum + r.executorScore,
                      ) /
                      executorGames.length,
          };
        }(),
    };
    return SimulationStatistics._({
      'gameCount': games,
      'saviorWins': wins(Faction.savior),
      'executorWins': wins(Faction.executor),
      'draws': draws,
      'saviorWinRate': rate(wins(Faction.savior)),
      'executorWinRate': rate(wins(Faction.executor)),
      'firstPlayerWins': firstWins,
      'secondPlayerWins': games - firstWins - draws,
      'firstPlayerWinRate': rate(firstWins),
      'secondPlayerWinRate': rate(games - firstWins - draws),
      'saviorFirstGames': results
          .where((result) => result.firstPlayer == Faction.savior)
          .length,
      'saviorFirstWins': results
          .where(
            (result) =>
                result.firstPlayer == Faction.savior &&
                result.winner == Faction.savior,
          )
          .length,
      'executorFirstGames': results
          .where((result) => result.firstPlayer == Faction.executor)
          .length,
      'executorFirstWins': results
          .where(
            (result) =>
                result.firstPlayer == Faction.executor &&
                result.winner == Faction.executor,
          )
          .length,
      'averageSaviorScore': average((result) => result.saviorScore),
      'averageExecutorScore': average((result) => result.executorScore),
      'averageScoreDifference': average((result) => result.absoluteScoreDiff),
      'medianScoreDifference': _median(diffValues),
      'oneSidedGameRate': rate(
        results
            .where(
              (result) => result.absoluteScoreDiff >= config.oneSidedThreshold,
            )
            .length,
      ),
      'averageTurns': average((result) => result.totalTurns),
      'medianTurns': _median(turnValues),
      'minTurns': turnValues.reduce((a, b) => a < b ? a : b),
      'maxTurns': turnValues.reduce((a, b) => a > b ? a : b),
      'turnDistribution': {
        '20OrLess': rate(
          results.where((result) => result.totalTurns <= 20).length,
        ),
        '21To25': rate(
          results
              .where(
                (result) => result.totalTurns >= 21 && result.totalTurns <= 25,
              )
              .length,
        ),
        '26To30': rate(
          results
              .where(
                (result) => result.totalTurns >= 26 && result.totalTurns <= 30,
              )
              .length,
        ),
        '31To35': rate(
          results
              .where(
                (result) => result.totalTurns >= 31 && result.totalTurns <= 35,
              )
              .length,
        ),
        '36OrMore': rate(
          results.where((result) => result.totalTurns >= 36).length,
        ),
      },
      'averageEyePerGame': eyeTotal / games,
      'averageSaviorEye': average((result) => result.saviorEyeCount),
      'averageExecutorEye': average((result) => result.executorEyeCount),
      'usefulEyeRate': eyeTotal == 0
          ? 0.0
          : (eyeTotal - redundantEyes) / eyeTotal,
      'redundantEyeRate': eyeTotal == 0 ? 0.0 : redundantEyes / eyeTotal,
      'saviorJudgeUsageRate': rate(
        results.where((result) => result.saviorJudgeUsed).length,
      ),
      'executorJudgeUsageRate': rate(
        results.where((result) => result.executorJudgeUsed).length,
      ),
      'overallJudgeUsageRate': rate(
        results.fold<int>(
          0,
          (sum, result) =>
              sum +
              (result.saviorJudgeUsed ? 1 : 0) +
              (result.executorJudgeUsed ? 1 : 0),
        ),
        games * 2,
      ),
      'judgeUnusedGameRate': rate(
        results
            .where(
              (result) => !result.saviorJudgeUsed && !result.executorJudgeUsed,
            )
            .length,
      ),
      'averageBonusWhenJudgeUsed': judgeBonuses.isEmpty
          ? 0.0
          : judgeBonuses.reduce((a, b) => a + b) / judgeBonuses.length,
      'judgeBonus1To3': judgeBonuses.where((bonus) => bonus <= 3).length,
      'judgeBonus4To6': judgeBonuses
          .where((bonus) => bonus >= 4 && bonus <= 6)
          .length,
      'judgeBonus7To9': judgeBonuses.where((bonus) => bonus >= 7).length,
      'saviorReverseUsageRate': rate(
        results.where((result) => result.saviorReverseUsed).length,
      ),
      'executorReverseUsageRate': rate(
        results.where((result) => result.executorReverseUsed).length,
      ),
      'overallReverseUsageRate': rate(
        results.fold<int>(
          0,
          (sum, result) =>
              sum +
              (result.saviorReverseUsed ? 1 : 0) +
              (result.executorReverseUsed ? 1 : 0),
        ),
        games * 2,
      ),
      'averageReverseTurn': _nullableAverage(
        results.expand(
          (result) => [result.saviorReverseTurn, result.executorReverseTurn],
        ),
      ),
      'reverseOutcomeChangedApproxRate': rate(
        results.fold<int>(
          0,
          (sum, result) => sum + result.reverseOutcomeChangedCount,
        ),
        results.fold<int>(
          0,
          (sum, result) =>
              sum +
              (result.saviorReverseUsed ? 1 : 0) +
              (result.executorReverseUsed ? 1 : 0),
        ),
      ),
      'averageContestedPersons': average(
        (result) => result.contestedPersonCount,
      ),
      'averageLifeDeathFlips': average((result) => result.lifeDeathFlipCount),
      'averageThirdActionConfirms': average(
        (result) => result.thirdActionConfirmationCount,
      ),
      'averageInstantJudgeConfirms': average(
        (result) => result.instantJudgeConfirmationCount,
      ),
      'saviorHighBonusCaptureRate': rate(highSavior, highSavior + highExecutor),
      'executorHighBonusCaptureRate': rate(
        highExecutor,
        highSavior + highExecutor,
      ),
      'bonusCaptures': bonusCaptures,
      'cardUsage': cardUsageStats,
      'bonusAnalysis': bonusAnalysis,
      // Games that hit the turn cap before every person was confirmed —
      // only ever non-zero for an untested SimulationRuleFlags combination
      // the current CPU logic can't play out to completion (e.g. it rarely
      // chooses JUDGE once natural confirmation is disabled and JUDGE is
      // unlimited). A high rate here means the *CPU*, not the ruleset
      // itself, is the bottleneck — worth flagging prominently in the UI.
      'turnLimitReachedRate': rate(
        results.where((result) => result.endReason == 'turnLimitReached').length,
      ),
    });
  }

  Map<String, Object> toJson() => values;

  String toConsoleReport() {
    String percent(String key) =>
        '${((values[key]! as num) * 100).toStringAsFixed(1)}%';
    String number(String key) => (values[key]! as num).toStringAsFixed(2);
    return '''
==================================================
NINE VERDICTS SIMULATION
==================================================
Games                  ${values['gameCount']}

WIN RATE
Savior                 ${percent('saviorWinRate')}
Executor               ${percent('executorWinRate')}

FIRST / SECOND
First player            ${percent('firstPlayerWinRate')}
Second player           ${percent('secondPlayerWinRate')}

SCORE
Avg Savior              ${number('averageSaviorScore')}
Avg Executor             ${number('averageExecutorScore')}
Avg difference           ${number('averageScoreDifference')}
One-sided games          ${percent('oneSidedGameRate')}

TEMPO
Avg turns                ${number('averageTurns')}
Median turns             ${values['medianTurns']}
Min / Max                ${values['minTurns']} / ${values['maxTurns']}

EYE
Avg / game               ${number('averageEyePerGame')}
Savior                   ${number('averageSaviorEye')}
Executor                 ${number('averageExecutorEye')}
Useful                   ${percent('usefulEyeRate')}
Redundant                ${percent('redundantEyeRate')}

JUDGE
Usage                    ${percent('overallJudgeUsageRate')}
Unused games             ${percent('judgeUnusedGameRate')}
Avg bonus                ${number('averageBonusWhenJudgeUsed')}

REVERSE ACTION
Usage                    ${percent('overallReverseUsageRate')}
Savior DEATH             ${percent('saviorReverseUsageRate')}
Executor LIFE            ${percent('executorReverseUsageRate')}

CONTEST
Contested persons        ${number('averageContestedPersons')} / game
Life<->Death flips       ${number('averageLifeDeathFlips')} / game
3-action confirms        ${number('averageThirdActionConfirms')} / game

BONUS ${values['saviorHighBonusCaptureRate'] != null ? '7-9' : ''}
Savior capture           ${percent('saviorHighBonusCaptureRate')}
Executor capture         ${percent('executorHighBonusCaptureRate')}
==================================================''';
  }

  static num _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static double _nullableAverage(Iterable<int?> values) {
    final present = values.whereType<int>().toList();
    return present.isEmpty
        ? 0
        : present.reduce((a, b) => a + b) / present.length;
  }
}
