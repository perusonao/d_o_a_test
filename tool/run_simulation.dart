// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/eye_zone_report.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_exporter.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';

void main(List<String> arguments) {
  final options = _parse(arguments);
  final games = int.parse(options['games'] ?? '100');
  final ruleVersion = _ruleVersion(options['rules'] ?? '1.1');
  final config = SimulationConfig(
    gameCount: games,
    baseSeed: int.parse(options['seed'] ?? '1000'),
    saviorDifficulty: _difficulty(options['savior'] ?? 'balanced'),
    executorDifficulty: _difficulty(options['executor'] ?? 'balanced'),
    firstPlayer: _firstPlayer(options['first'] ?? 'alternate'),
    ruleVersion: ruleVersion,
  );
  final run = const SimulationRunner().run(config);
  print(run.statistics.toConsoleReport());
  if (ruleVersion == NineJudgesRuleVersion.v1_2) {
    print(EyeZoneReport.fromResults(run.results).toConsoleReport());
  }
  final seconds = run.elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  print('Elapsed: ${seconds.toStringAsFixed(3)} sec');
  print(
    'Games/sec: ${(games / (seconds == 0 ? 0.000001 : seconds)).toStringAsFixed(1)}',
  );

  if (options.containsKey('export-csv')) {
    final path = _outputPath(
      options['export-csv'],
      'simulation_results_$games.csv',
    );
    _write(path, SimulationExporter.resultsCsv(run));
    print('CSV: $path');
  }
  if (options.containsKey('export-json')) {
    final path = _outputPath(
      options['export-json'],
      'simulation_summary_$games.json',
    );
    _write(path, SimulationExporter.summaryJson(run));
    print('JSON: $path');
  }
  if (options.containsKey('export-analysis')) {
    final path = _outputPath(
      options['export-analysis'],
      'first_second_analysis_$games.json',
    );
    _write(path, SimulationExporter.firstSecondAnalysisJson(run));
    print('Analysis: $path');
  }
}

Map<String, String?> _parse(List<String> arguments) {
  final result = <String, String?>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--')) continue;
    final value = argument.substring(2);
    final separator = value.indexOf('=');
    if (separator < 0) {
      result[value] = null;
    } else {
      result[value.substring(0, separator)] = value.substring(separator + 1);
    }
  }
  return result;
}

CpuLevel _difficulty(String value) => switch (value.toLowerCase()) {
  'random' => CpuLevel.random,
  'balanced' || 'basic' => CpuLevel.balanced,
  'aggressive' => CpuLevel.aggressive,
  'defensive' => CpuLevel.defensive,
  'expert' => CpuLevel.expert,
  _ => throw ArgumentError('Unknown CPU difficulty: $value'),
};

SimulationFirstPlayer _firstPlayer(String value) =>
    switch (value.toLowerCase()) {
      'alternate' => SimulationFirstPlayer.alternate,
      'random' => SimulationFirstPlayer.random,
      'savior' => SimulationFirstPlayer.savior,
      'executor' => SimulationFirstPlayer.executor,
      _ => throw ArgumentError('Unknown first-player mode: $value'),
    };

NineJudgesRuleVersion _ruleVersion(String value) => switch (value) {
  '1.1' => NineJudgesRuleVersion.v1_1,
  '1.2' => NineJudgesRuleVersion.v1_2,
  _ => throw ArgumentError('Unknown rules version: $value'),
};

String _outputPath(String? option, String fallbackName) {
  if (option != null && option.isNotEmpty) return option;
  return 'simulation_output${Platform.pathSeparator}$fallbackName';
}

void _write(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}
