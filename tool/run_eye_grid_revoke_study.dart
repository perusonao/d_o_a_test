// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_exporter.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/first_second_analysis.dart';

const _outDir = 'simulation_output/eye_grid_revoke';

// Deliberately not 1000/5000/etc (the previous round's seeds) — a fresh,
// disjoint seed family so this round's screening cannot silently reuse the
// same boards/bonus decks as the earlier A-G study.
const _screeningSeeds = [70001, 80002];
const _finalistSeeds = [70001, 80002, 90003, 100004, 110005];
const _crossStudySeeds = [70001, 80002];

void main(List<String> arguments) {
  final options = _parse(arguments);
  final screeningGamesPerSeed = int.parse(
    options['screening-games-per-seed'] ?? '5000',
  );
  final finalistGamesPerSeed = int.parse(
    options['finalist-games-per-seed'] ?? '10000',
  );
  final crossGamesPerSeed = int.parse(
    options['cross-games-per-seed'] ?? '5000',
  );

  print('=== EYE GRID SCREENING ===');
  print(
    '${_screeningSeeds.length} seeds x $screeningGamesPerSeed games = '
    '${_screeningSeeds.length * screeningGamesPerSeed} games/condition, '
    'Balanced vs Balanced, first=alternate',
  );
  final controlResults = _controlResults(_screeningSeeds, screeningGamesPerSeed);
  final repConfig = SimulationConfig(
    gameCount: controlResults.length,
    baseSeed: _screeningSeeds.first,
  );
  final eyeGridCandidates = [
    SimulationExperimentConfig.control,
    SimulationExperimentConfig.eyeZoneBase,
    ...SimulationExperimentConfig.eyeGrid,
    ...SimulationExperimentConfig.eyeFreeFirstUseGrid,
  ];
  final eyeGridReports = <ExperimentReport>[];
  for (final experiment in eyeGridCandidates) {
    final stopwatch = Stopwatch()..start();
    final outcomes = experiment.isControl
        ? [
            for (final result in controlResults)
              ExperimentGameOutcome(result: result, extras: const {}),
          ]
        : _experimentOutcomes(
            _screeningSeeds,
            screeningGamesPerSeed,
            experiment,
          );
    stopwatch.stop();
    eyeGridReports.add(
      _buildReport(experiment, controlResults, outcomes, repConfig, stopwatch.elapsed),
    );
    _printOneLine(eyeGridReports.last);
  }
  _write(
    '$_outDir/eye_grid_screening_10000.json',
    ExperimentExporter.allReportsJson(eyeGridReports),
  );
  _write(
    '$_outDir/eye_grid_screening_10000.csv',
    ExperimentExporter.summaryCsv(eyeGridReports),
  );
  _write(
    '$_outDir/eye_grid_screening_10000.md',
    ExperimentExporter.comparisonMarkdown(
      eyeGridReports,
      title:
          'EYE grid screening (${controlResults.length} games/condition across '
          '${_screeningSeeds.length} seeds, Balanced vs Balanced)',
    ),
  );

  // Rank every non-control EYE-grid cell by distance from the ideal band on
  // the 5 headline axes (see _rankingDistance for the exact formula — this
  // is a mechanical shortlist aid only, not the final qualitative verdict).
  final rankedEyeGrid = [
    for (final report in eyeGridReports)
      if (!report.experiment.isControl) report,
  ]..sort((a, b) => _rankingDistance(a).compareTo(_rankingDistance(b)));
  final topEyeConditions = rankedEyeGrid.take(5).toList();
  print('');
  print('Top 5 EYE-grid conditions by ranking distance (for REVOKE stage):');
  for (final report in topEyeConditions) {
    print(
      '  ${report.experiment.name.padRight(24)} distance=${_rankingDistance(report).toStringAsFixed(3)}',
    );
  }

  print('');
  print('=== REVOKE SCREENING (2nd stage) ===');
  final revokeReports = <ExperimentReport>[];
  for (final base in topEyeConditions.map((r) => r.experiment)) {
    for (final experiment in SimulationExperimentConfig.revokeVariants(base)) {
      final stopwatch = Stopwatch()..start();
      final outcomes = _experimentOutcomes(
        _screeningSeeds,
        screeningGamesPerSeed,
        experiment,
      );
      stopwatch.stop();
      revokeReports.add(
        _buildReport(
          experiment,
          controlResults,
          outcomes,
          repConfig,
          stopwatch.elapsed,
        ),
      );
      _printOneLine(revokeReports.last);
    }
  }
  _write(
    '$_outDir/revoke_screening_10000.json',
    ExperimentExporter.allReportsJson(revokeReports),
  );
  _write(
    '$_outDir/revoke_screening_10000.csv',
    ExperimentExporter.summaryCsv(revokeReports),
  );
  _write(
    '$_outDir/revoke_screening_10000.md',
    ExperimentExporter.comparisonMarkdown(
      revokeReports,
      title:
          'REVOKE screening (${controlResults.length} games/condition across '
          '${_screeningSeeds.length} seeds, Balanced vs Balanced)',
    ),
  );

  // Finalists: top 5 overall across both screening stages (EYE-grid alone
  // and every REVOKE variant on the top EYE conditions), re-verified with
  // 5x the games across 5 disjoint seeds.
  final allScreened = [...eyeGridReports, ...revokeReports]
    ..removeWhere((r) => r.experiment.isControl);
  final rankedAll = [...allScreened]
    ..sort((a, b) => _rankingDistance(a).compareTo(_rankingDistance(b)));
  final finalistConfigs = <SimulationExperimentConfig>[];
  final seenNames = <String>{};
  for (final report in rankedAll) {
    if (seenNames.add(report.experiment.name)) {
      finalistConfigs.add(report.experiment);
    }
    if (finalistConfigs.length == 5) break;
  }
  print('');
  print('Finalists selected for 50,000-game re-verification:');
  for (final experiment in finalistConfigs) {
    print('  ${experiment.name}');
  }

  print('');
  print('=== FINALISTS (${_finalistSeeds.length} seeds x $finalistGamesPerSeed games) ===');
  final finalistControlResults = _controlResults(
    _finalistSeeds,
    finalistGamesPerSeed,
  );
  final finalistRepConfig = SimulationConfig(
    gameCount: finalistControlResults.length,
    baseSeed: _finalistSeeds.first,
  );
  final finalistReports = <ExperimentReport>[
    _buildReport(
      SimulationExperimentConfig.control,
      finalistControlResults,
      [
        for (final result in finalistControlResults)
          ExperimentGameOutcome(result: result, extras: const {}),
      ],
      finalistRepConfig,
      Duration.zero,
    ),
  ];
  for (final experiment in finalistConfigs) {
    final stopwatch = Stopwatch()..start();
    final outcomes = _experimentOutcomes(
      _finalistSeeds,
      finalistGamesPerSeed,
      experiment,
    );
    stopwatch.stop();
    finalistReports.add(
      _buildReport(
        experiment,
        finalistControlResults,
        outcomes,
        finalistRepConfig,
        stopwatch.elapsed,
      ),
    );
    _printOneLine(finalistReports.last);
  }
  _write(
    '$_outDir/finalists_50000.json',
    ExperimentExporter.allReportsJson(finalistReports),
  );
  _write(
    '$_outDir/finalists_50000.csv',
    ExperimentExporter.summaryCsv(finalistReports),
  );
  _write(
    '$_outDir/finalists_50000.md',
    ExperimentExporter.comparisonMarkdown(
      finalistReports,
      title:
          'Finalists (${finalistControlResults.length} games/condition across '
          '${_finalistSeeds.length} seeds, Balanced vs Balanced)',
    ),
  );

  // CPU cross-study: top 2-3 finalists (excluding CONTROL) across
  // Balanced/Expert pairings. Balanced-vs-Balanced is already covered above.
  final crossCandidates = [
    for (final report in finalistReports)
      if (!report.experiment.isControl) report,
  ]..sort((a, b) => _rankingDistance(a).compareTo(_rankingDistance(b)));
  final topCross = crossCandidates.take(3).map((r) => r.experiment).toList();
  print('');
  print('=== CPU CROSS-STUDY (top ${topCross.length} finalists) ===');
  final crossPairings = [
    (CpuLevel.expert, CpuLevel.expert, 'ExpertVsExpert'),
    (CpuLevel.expert, CpuLevel.balanced, 'ExpertVsBalanced'),
    (CpuLevel.balanced, CpuLevel.expert, 'BalancedVsExpert'),
  ];
  final crossBuffer = StringBuffer('# CPU cross-study\n\n');
  for (final (savior, executor, label) in crossPairings) {
    final controlCross = _controlResults(
      _crossStudySeeds,
      crossGamesPerSeed,
      savior: savior,
      executor: executor,
    );
    final crossRepConfig = SimulationConfig(
      gameCount: controlCross.length,
      baseSeed: _crossStudySeeds.first,
      saviorDifficulty: savior,
      executorDifficulty: executor,
    );
    final reports = <ExperimentReport>[
      _buildReport(
        SimulationExperimentConfig.control,
        controlCross,
        [
          for (final result in controlCross)
            ExperimentGameOutcome(result: result, extras: const {}),
        ],
        crossRepConfig,
        Duration.zero,
      ),
    ];
    for (final experiment in topCross) {
      final outcomes = _experimentOutcomes(
        _crossStudySeeds,
        crossGamesPerSeed,
        experiment,
        savior: savior,
        executor: executor,
      );
      reports.add(
        _buildReport(
          experiment,
          controlCross,
          outcomes,
          crossRepConfig,
          Duration.zero,
        ),
      );
    }
    print('--- $label ---');
    for (final report in reports) {
      _printOneLine(report);
    }
    crossBuffer
      ..writeln('## $label')
      ..writeln()
      ..writeln(ExperimentExporter.comparisonMarkdown(reports, title: label));
  }
  _write('$_outDir/expert_cross_study.md', crossBuffer.toString());

  print('');
  print('Study output written to $_outDir/');
}

List<SimulationResult> _controlResults(
  List<int> seeds,
  int gamesPerSeed, {
  CpuLevel savior = CpuLevel.balanced,
  CpuLevel executor = CpuLevel.balanced,
}) {
  final all = <SimulationResult>[];
  for (final seed in seeds) {
    final config = SimulationConfig(
      gameCount: gamesPerSeed,
      baseSeed: seed,
      saviorDifficulty: savior,
      executorDifficulty: executor,
    );
    all.addAll(const SimulationRunner().run(config).results);
  }
  return all;
}

List<ExperimentGameOutcome> _experimentOutcomes(
  List<int> seeds,
  int gamesPerSeed,
  SimulationExperimentConfig experiment, {
  CpuLevel savior = CpuLevel.balanced,
  CpuLevel executor = CpuLevel.balanced,
}) {
  final all = <ExperimentGameOutcome>[];
  for (final seed in seeds) {
    final config = SimulationConfig(
      gameCount: gamesPerSeed,
      baseSeed: seed,
      saviorDifficulty: savior,
      executorDifficulty: executor,
    );
    all.addAll(const ExperimentSimulationRunner().run(config, experiment).outcomes);
  }
  return all;
}

ExperimentReport _buildReport(
  SimulationExperimentConfig experiment,
  List<SimulationResult> controlResults,
  List<ExperimentGameOutcome> outcomes,
  SimulationConfig repConfig,
  Duration elapsed,
) {
  final results = [for (final outcome in outcomes) outcome.result];
  final stats = SimulationStatistics.fromResults(results, repConfig);
  final controlStats = SimulationStatistics.fromResults(
    controlResults,
    repConfig,
  );
  return ExperimentReport(
    experiment: experiment,
    gameCount: results.length,
    elapsed: elapsed,
    statistics: stats,
    firstSecondAnalysis: FirstSecondAnalysis.fromResults(results, repConfig),
    extra: ExperimentExtraStatistics.fromOutcomes(outcomes, experiment),
    paired: PairedComparison.compare(controlResults, results),
    delta: ControlDelta.compute(controlStats, stats),
  );
}

/// Mechanical shortlist aid only (documented in REPORT_NEXT_RULE.md): a
/// weighted distance from the ideal band on the 5 headline axes. It is
/// deliberately *not* the final say — the report's qualitative 8-axis
/// judgement (balance/tempo/info-warfare/read-the-opponent/simplicity/
/// special-action dependence/CPU dependence/human fun potential) decides the
/// actual recommendation.
double _rankingDistance(ExperimentReport report) {
  final s = report.statistics.values;
  double bandPenalty(
    double value, {
    required double idealLo,
    required double idealHi,
    required double okLo,
    required double okHi,
  }) {
    if (value >= idealLo && value <= idealHi) return 0;
    if (value >= okLo && value <= okHi) {
      return value < idealLo ? (idealLo - value) * 2 : (value - idealHi) * 2;
    }
    final outside = value < okLo ? okLo - value : value - okHi;
    return 1 + outside * 4;
  }

  final firstWin = s['firstPlayerWinRate']! as double;
  final saviorWin = s['saviorWinRate']! as double;
  final turns = s['averageTurns']! as double;
  final eye = s['averageEyePerGame']! as double;
  final oneSided = s['oneSidedGameRate']! as double;

  final firstPenalty = bandPenalty(
    firstWin,
    idealLo: 0.48,
    idealHi: 0.52,
    okLo: 0.47,
    okHi: 0.53,
  );
  final saviorPenalty = bandPenalty(
    saviorWin,
    idealLo: 0.48,
    idealHi: 0.52,
    okLo: 0.47,
    okHi: 0.53,
  );
  final turnsPenalty = bandPenalty(
    turns,
    idealLo: 20,
    idealHi: 26,
    okLo: 18,
    okHi: 29,
  );
  final eyePenalty = bandPenalty(
    eye,
    idealLo: 2,
    idealHi: 4,
    okLo: 1,
    okHi: 6,
  );
  final oneSidedPenalty = oneSided <= 0.12 ? 0.0 : (oneSided - 0.12) * 5;

  return firstPenalty * 3 +
      saviorPenalty * 3 +
      turnsPenalty * 1.5 +
      eyePenalty * 1 +
      oneSidedPenalty * 1.5;
}

void _printOneLine(ExperimentReport report) {
  final s = report.statistics.values;
  String pct(Object? v) => '${((v as num) * 100).toStringAsFixed(1)}%';
  print(
    '${report.experiment.name.padRight(36)} '
    'first=${pct(s['firstPlayerWinRate'])} '
    'savior=${pct(s['saviorWinRate'])} '
    'turns=${(s['averageTurns'] as num).toStringAsFixed(1)} '
    'eye=${(s['averageEyePerGame'] as num).toStringAsFixed(2)} '
    'oneSided=${pct(s['oneSidedGameRate'])} '
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
