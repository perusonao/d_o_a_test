// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/first_second_analysis.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_statistics.dart';

void main(List<String> arguments) {
  final options = _parse(arguments);
  final gamesPerSeed = int.parse(options['games-per-seed'] ?? '10000');
  final crossGames = int.parse(options['cross-games'] ?? '5000');
  final seeds = (options['seeds'] ?? '1000,11000,21000,31000,41000')
      .split(',')
      .map(int.parse)
      .toList();
  final runner = const SimulationRunner();
  final seedRuns = <SimulationRun>[];
  for (final seed in seeds) {
    print('Running balanced vs balanced: seed=$seed games=$gamesPerSeed');
    seedRuns.add(
      runner.run(
        SimulationConfig(
          gameCount: gamesPerSeed,
          baseSeed: seed,
          firstPlayer: SimulationFirstPlayer.alternate,
        ),
      ),
    );
  }
  final allResults = seedRuns.expand((run) => run.results).toList();
  final combinedConfig = SimulationConfig(
    gameCount: allResults.length,
    baseSeed: seeds.first,
    firstPlayer: SimulationFirstPlayer.alternate,
  );
  final combined = SimulationRun(
    config: combinedConfig,
    results: allResults,
    statistics: SimulationStatistics.fromResults(allResults, combinedConfig),
    firstSecondAnalysis: FirstSecondAnalysis.fromResults(
      allResults,
      combinedConfig,
    ),
    elapsed: seedRuns.fold(Duration.zero, (sum, run) => sum + run.elapsed),
  );

  final matchups = <(String, CpuLevel, CpuLevel)>[
    ('balanced_vs_balanced', CpuLevel.balanced, CpuLevel.balanced),
    ('aggressive_vs_balanced', CpuLevel.aggressive, CpuLevel.balanced),
    ('defensive_vs_balanced', CpuLevel.defensive, CpuLevel.balanced),
    ('expert_vs_balanced', CpuLevel.expert, CpuLevel.balanced),
    ('balanced_vs_expert', CpuLevel.balanced, CpuLevel.expert),
    ('expert_vs_expert', CpuLevel.expert, CpuLevel.expert),
    ('random_vs_balanced', CpuLevel.random, CpuLevel.balanced),
  ];
  final crossResults = <String, Object>{};
  for (var i = 0; i < matchups.length; i++) {
    final matchup = matchups[i];
    print('Running ${matchup.$1}: games=$crossGames');
    final run = runner.run(
      SimulationConfig(
        gameCount: crossGames,
        baseSeed: 101000 + i * crossGames,
        saviorDifficulty: matchup.$2,
        executorDifficulty: matchup.$3,
        firstPlayer: SimulationFirstPlayer.alternate,
      ),
    );
    crossResults[matchup.$1] = {
      'games': crossGames,
      'saviorDifficulty': matchup.$2.name,
      'executorDifficulty': matchup.$3.name,
      'statistics': run.statistics.toJson(),
      'firstSecond': run.firstSecondAnalysis.toJson()['firstSecond']!,
      'elapsedMilliseconds': run.elapsed.inMilliseconds,
    };
  }

  final seedRates = [
    for (var i = 0; i < seedRuns.length; i++)
      {
        'baseSeed': seeds[i],
        'games': gamesPerSeed,
        'firstPlayerWinRate':
            seedRuns[i].statistics.values['firstPlayerWinRate'],
        'secondPlayerWinRate':
            seedRuns[i].statistics.values['secondPlayerWinRate'],
        'saviorWinRate': seedRuns[i].statistics.values['saviorWinRate'],
        'executorWinRate': seedRuns[i].statistics.values['executorWinRate'],
      },
  ];
  final firstRates = seedRates
      .map((entry) => entry['firstPlayerWinRate']! as double)
      .toList();
  final output = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'rulesVersion': '1.1',
    'balancedVsBalanced': {
      'games': allResults.length,
      'seedSets': seedRates,
      'firstPlayerWinRateAcrossSeeds': {
        'minimum': firstRates.reduce((a, b) => a < b ? a : b),
        'maximum': firstRates.reduce((a, b) => a > b ? a : b),
        'mean': firstRates.reduce((a, b) => a + b) / firstRates.length,
      },
      'statistics': combined.statistics.toJson(),
      ...combined.firstSecondAnalysis.toJson(),
      'elapsedMilliseconds': combined.elapsed.inMilliseconds,
    },
    'cpuCrossMatchups': crossResults,
  };
  final path =
      options['output'] ??
      'simulation_output${Platform.pathSeparator}first_second_analysis_${allResults.length}.json';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  print(combined.statistics.toConsoleReport());
  print('Study JSON: $path');
}

Map<String, String?> _parse(List<String> arguments) {
  final result = <String, String?>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--')) continue;
    final raw = argument.substring(2);
    final separator = raw.indexOf('=');
    result[separator < 0 ? raw : raw.substring(0, separator)] = separator < 0
        ? null
        : raw.substring(separator + 1);
  }
  return result;
}
