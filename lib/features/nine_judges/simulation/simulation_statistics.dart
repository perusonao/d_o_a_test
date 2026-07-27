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
