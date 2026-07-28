// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_exporter.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/first_second_analysis.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_statistics.dart';

/// EXPERIMENTAL ONLY — not part of the official ruleset.
///
/// Compares the shipped rulesVersion 1.2 EYE rule (center-only, max 2 uses,
/// no cost — [SimulationExperimentConfig.eyeGridCell] with eyeMax:2,
/// eyeCost:0) against that same base plus an experimental REVOKE action
/// (remove the most recent LIFE/DEATH mark from a still-undecided person),
/// in "both players get one" and "first player only" flavors. Purely for
/// future read-the-opponent research; reuses the existing experiment engine
/// from simulation/experiments/ instead of re-implementing REVOKE here.
void main(List<String> arguments) {
  final options = _parse(arguments);
  final gamesPerSeed = int.parse(options['games-per-seed'] ?? '10000');
  final seeds = (options['seeds'] ?? '70001,80002,90003,100004,110005')
      .split(',')
      .map(int.parse)
      .toList();

  final base = SimulationExperimentConfig.eyeGridCell(eyeMax: 2, eyeCost: 0);
  final variants = [
    base.copyWith(name: '${base.name}_REVOKE_NONE'),
    base.copyWith(
      name: '${base.name}_REVOKE_BOTH1',
      revokeBudgetFirstPlayer: 1,
      revokeBudgetSecondPlayer: 1,
    ),
    base.copyWith(
      name: '${base.name}_REVOKE_FIRST1',
      revokeBudgetFirstPlayer: 1,
      revokeBudgetSecondPlayer: 0,
    ),
  ];

  print('=== EXPERIMENTAL REVOKE comparison (NOT part of official rules) ===');
  print(
    '${seeds.length} seeds x $gamesPerSeed games = '
    '${seeds.length * gamesPerSeed} games/condition, base=${base.name}',
  );

  final controlResults = _run(seeds, gamesPerSeed);
  final repConfig = SimulationConfig(
    gameCount: controlResults.length,
    baseSeed: seeds.first,
  );
  final reports = <ExperimentReport>[];
  for (final experiment in variants) {
    final stopwatch = Stopwatch()..start();
    final outcomes = <ExperimentGameOutcome>[];
    for (final seed in seeds) {
      final config = SimulationConfig(gameCount: gamesPerSeed, baseSeed: seed);
      outcomes.addAll(
        const ExperimentSimulationRunner().run(config, experiment).outcomes,
      );
    }
    stopwatch.stop();
    final results = [for (final outcome in outcomes) outcome.result];
    final stats = SimulationStatistics.fromResults(results, repConfig);
    final controlStats = SimulationStatistics.fromResults(
      controlResults,
      repConfig,
    );
    reports.add(
      ExperimentReport(
        experiment: experiment,
        gameCount: results.length,
        elapsed: stopwatch.elapsed,
        statistics: stats,
        firstSecondAnalysis: FirstSecondAnalysis.fromResults(
          results,
          repConfig,
        ),
        extra: ExperimentExtraStatistics.fromOutcomes(outcomes, experiment),
        paired: PairedComparison.compare(controlResults, results),
        delta: ControlDelta.compute(controlStats, stats),
      ),
    );
    final s = stats.values;
    String pct(Object? v) => '${((v as num) * 100).toStringAsFixed(1)}%';
    print(
      '${experiment.name.padRight(40)} '
      'first=${pct(s['firstPlayerWinRate'])} '
      'savior=${pct(s['saviorWinRate'])} '
      'turns=${(s['averageTurns'] as num).toStringAsFixed(1)} '
      'oneSided=${pct(s['oneSidedGameRate'])} '
      'flip=${pct(reports.last.paired.values['totalFlipRate'])}',
    );
  }

  const outDir = 'simulation_output/revoke_comparison';
  _write(
    '$outDir/revoke_comparison.md',
    ExperimentExporter.comparisonMarkdown(
      reports,
      title:
          'EXPERIMENTAL REVOKE comparison on rulesVersion 1.2 EYE base '
          '(${controlResults.length} games/condition across ${seeds.length} seeds) '
          '— research only, not shipped',
    ),
  );
  _write(
    '$outDir/revoke_comparison.json',
    ExperimentExporter.allReportsJson(reports),
  );
  print('');
  print('Wrote $outDir/revoke_comparison.md and .json');
}

List<SimulationResult> _run(List<int> seeds, int gamesPerSeed) {
  final all = <SimulationResult>[];
  for (final seed in seeds) {
    final config = SimulationConfig(gameCount: gamesPerSeed, baseSeed: seed);
    all.addAll(const SimulationRunner().run(config).results);
  }
  return all;
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

void _write(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}
