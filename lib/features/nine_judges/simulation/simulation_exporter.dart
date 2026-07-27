import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';

abstract final class SimulationExporter {
  static String resultsCsv(SimulationRun run) {
    const headers = [
      'gameIndex',
      'seed',
      'winner',
      'firstPlayer',
      'saviorScore',
      'executorScore',
      'scoreDiff',
      'turns',
      'saviorEye',
      'executorEye',
      'saviorJudgeUsed',
      'executorJudgeUsed',
      'saviorReverseUsed',
      'executorReverseUsed',
      'contestedPersons',
      'lifeDeathFlips',
      'thirdActionConfirms',
      'instantJudgeConfirms',
    ];
    final rows = <String>[headers.join(',')];
    for (final result in run.results) {
      rows.add(
        [
          result.gameIndex,
          result.seed,
          result.winner?.name ?? 'draw',
          result.firstPlayer.name,
          result.saviorScore,
          result.executorScore,
          result.scoreDiff,
          result.totalTurns,
          result.saviorEyeCount,
          result.executorEyeCount,
          result.saviorJudgeUsed,
          result.executorJudgeUsed,
          result.saviorReverseUsed,
          result.executorReverseUsed,
          result.contestedPersonCount,
          result.lifeDeathFlipCount,
          result.thirdActionConfirmationCount,
          result.instantJudgeConfirmationCount,
        ].join(','),
      );
    }
    return rows.join('\n');
  }

  static String summaryJson(SimulationRun run) =>
      const JsonEncoder.withIndent('  ').convert({
        'config': {
          'gameCount': run.config.gameCount,
          'baseSeed': run.config.baseSeed,
          'saviorDifficulty': run.config.saviorDifficulty.name,
          'executorDifficulty': run.config.executorDifficulty.name,
          'firstPlayer': run.config.firstPlayer.name,
          'highBonusThreshold': run.config.highBonusThreshold,
          'oneSidedThreshold': run.config.oneSidedThreshold,
        },
        'elapsedMilliseconds': run.elapsed.inMilliseconds,
        'statistics': run.statistics.toJson(),
        'firstSecondAnalysis': run.firstSecondAnalysis.toJson(),
      });

  static String firstSecondAnalysisJson(SimulationRun run) =>
      const JsonEncoder.withIndent('  ').convert({
        'config': {
          'gameCount': run.config.gameCount,
          'baseSeed': run.config.baseSeed,
          'saviorDifficulty': run.config.saviorDifficulty.name,
          'executorDifficulty': run.config.executorDifficulty.name,
          'firstPlayer': run.config.firstPlayer.name,
        },
        ...run.firstSecondAnalysis.toJson(),
      });
}
