// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_exporter.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/first_second_analysis.dart';

const _baseSeed = 5000;
const _outDir = 'simulation_output/experiments';

void main(List<String> arguments) {
  final options = _parse(arguments);
  final screeningGames = int.parse(options['screening-games'] ?? '10000');
  final finalistGames = int.parse(options['finalist-games'] ?? '50000');

  print('=== SCREENING: balanced vs balanced, $screeningGames games each ===');
  final screeningConfig = SimulationConfig(
    gameCount: screeningGames,
    baseSeed: _baseSeed,
  );
  final screeningReports = _runAll(
    screeningConfig,
    [...SimulationExperimentConfig.primarySet, ...SimulationExperimentConfig.combinationSet],
  );
  _write('$_outDir/screening_10000.json', ExperimentExporter.allReportsJson(screeningReports));
  _write('$_outDir/screening_10000.csv', ExperimentExporter.summaryCsv(screeningReports));
  _write(
    '$_outDir/screening_10000.md',
    ExperimentExporter.comparisonMarkdown(
      screeningReports,
      title: 'Screening ($screeningGames games, Balanced vs Balanced)',
    ),
  );
  for (final report in screeningReports) {
    _printOneLine(report);
  }

  // A data-derived promising filter for the primary (single-toggle)
  // experiments: within shouting distance of the 47-53% first-player target
  // at screening scale (a wider 44-56% band absorbs 10k-game sampling
  // noise). CONTROL is always re-run as the 50k reference point. Combos are
  // only escalated if their underlying base experiment already looked
  // promising, per the "有望なものについて" instruction.
  bool promising(ExperimentReport report) {
    final firstWin = report.statistics.values['firstPlayerWinRate']! as double;
    return firstWin >= 0.44 && firstWin <= 0.56;
  }

  final promisingNames = {
    for (final report in screeningReports)
      if (report.experiment.isControl || promising(report)) report.experiment.name,
  };
  final finalistConfigs = [
    for (final experiment in [
      ...SimulationExperimentConfig.primarySet,
      ...SimulationExperimentConfig.combinationSet,
    ])
      if (promisingNames.contains(experiment.name)) experiment,
  ];

  print('');
  print(
    '=== FINALISTS: balanced vs balanced, $finalistGames games each '
    '(${finalistConfigs.length} configs promoted from screening) ===',
  );
  final finalistConfig = SimulationConfig(
    gameCount: finalistGames,
    baseSeed: _baseSeed,
  );
  final finalistReports = _runAll(finalistConfig, finalistConfigs);
  _write('$_outDir/finalists_50000.json', ExperimentExporter.allReportsJson(finalistReports));
  _write('$_outDir/finalists_50000.csv', ExperimentExporter.summaryCsv(finalistReports));
  _write(
    '$_outDir/finalists_50000.md',
    ExperimentExporter.comparisonMarkdown(
      finalistReports,
      title: 'Finalists ($finalistGames games, Balanced vs Balanced)',
    ),
  );
  for (final report in finalistReports) {
    _printOneLine(report);
  }

  // Re-confirm the single best-looking non-control finalist under
  // Expert vs Expert, per "必要であれば、Expert vs Expertでも再確認".
  final bestNonControl = [
    for (final report in finalistReports)
      if (!report.experiment.isControl) report,
  ]..sort((a, b) {
    double distance(ExperimentReport r) =>
        ((r.statistics.values['firstPlayerWinRate']! as double) - 0.5).abs();
    return distance(a).compareTo(distance(b));
  });
  if (bestNonControl.isNotEmpty) {
    final candidate = bestNonControl.first.experiment;
    print('');
    print(
      '=== EXPERT vs EXPERT reconfirmation: CONTROL vs ${candidate.name}, '
      '$finalistGames games ===',
    );
    final expertConfig = SimulationConfig(
      gameCount: finalistGames,
      baseSeed: _baseSeed,
      saviorDifficulty: CpuLevel.expert,
      executorDifficulty: CpuLevel.expert,
    );
    final expertReports = _runAll(expertConfig, [
      SimulationExperimentConfig.control,
      candidate,
    ]);
    _write(
      '$_outDir/expert_vs_expert_${candidate.name}.json',
      ExperimentExporter.allReportsJson(expertReports),
    );
    _write(
      '$_outDir/expert_vs_expert_${candidate.name}.md',
      ExperimentExporter.comparisonMarkdown(
        expertReports,
        title: 'Expert vs Expert reconfirmation ($finalistGames games)',
      ),
    );
    for (final report in expertReports) {
      _printOneLine(report);
    }
  }

  print('');
  print('Study output written to $_outDir/');
}

List<ExperimentReport> _runAll(
  SimulationConfig config,
  List<SimulationExperimentConfig> experiments,
) {
  final controlRun = const SimulationRunner().run(config);
  final controlStats = controlRun.statistics;
  final reports = <ExperimentReport>[];
  for (final experiment in experiments) {
    if (experiment.isControl) {
      reports.add(
        ExperimentReport(
          experiment: experiment,
          gameCount: config.gameCount,
          elapsed: controlRun.elapsed,
          statistics: controlStats,
          firstSecondAnalysis: controlRun.firstSecondAnalysis,
          extra: ExperimentExtraStatistics.fromOutcomes(const [], experiment),
          paired: PairedComparison.compare(controlRun.results, controlRun.results),
          delta: ControlDelta.compute(controlStats, controlStats),
        ),
      );
      continue;
    }
    final run = const ExperimentSimulationRunner().run(config, experiment);
    final stats = SimulationStatistics.fromResults(run.results, config);
    final analysis = FirstSecondAnalysis.fromResults(run.results, config);
    reports.add(
      ExperimentReport(
        experiment: experiment,
        gameCount: config.gameCount,
        elapsed: run.elapsed,
        statistics: stats,
        firstSecondAnalysis: analysis,
        extra: ExperimentExtraStatistics.fromOutcomes(run.outcomes, experiment),
        paired: PairedComparison.compare(controlRun.results, run.results),
        delta: ControlDelta.compute(controlStats, stats),
      ),
    );
  }
  return reports;
}

void _printOneLine(ExperimentReport report) {
  final s = report.statistics.values;
  String pct(Object? v) => '${((v as num) * 100).toStringAsFixed(1)}%';
  print(
    '${report.experiment.name.padRight(34)} '
    'first=${pct(s['firstPlayerWinRate'])} '
    'savior=${pct(s['saviorWinRate'])} '
    'turns=${(s['averageTurns'] as num).toStringAsFixed(1)} '
    'eye=${(s['averageEyePerGame'] as num).toStringAsFixed(2)} '
    'flip=${pct(report.paired.values['totalFlipRate'])}',
  );
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
  print('Wrote $path');
}
