// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/eye_zone_report.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';

/// Runs rulesVersion 1.1 and 1.2 back-to-back on the *same* seed/games/CPU
/// settings (only [SimulationConfig.ruleVersion] differs), so any difference
/// in the report is attributable to the EYE-restriction rule change alone.
void main(List<String> arguments) {
  final options = _parse(arguments);
  final games = int.parse(options['games'] ?? '50000');
  final baseSeed = int.parse(options['seed'] ?? '1000');
  final savior = _difficulty(options['savior'] ?? 'balanced');
  final executor = _difficulty(options['executor'] ?? 'balanced');
  final first = _firstPlayer(options['first'] ?? 'alternate');

  final run11 = const SimulationRunner().run(
    SimulationConfig(
      gameCount: games,
      baseSeed: baseSeed,
      saviorDifficulty: savior,
      executorDifficulty: executor,
      firstPlayer: first,
      ruleVersion: NineJudgesRuleVersion.v1_1,
    ),
  );
  final run12 = const SimulationRunner().run(
    SimulationConfig(
      gameCount: games,
      baseSeed: baseSeed,
      saviorDifficulty: savior,
      executorDifficulty: executor,
      firstPlayer: first,
      ruleVersion: NineJudgesRuleVersion.v1_2,
    ),
  );

  const rows = [
    (label: 'Savior win rate', key: 'saviorWinRate', percent: true),
    (label: 'Executor win rate', key: 'executorWinRate', percent: true),
    (
      label: 'First player win rate',
      key: 'firstPlayerWinRate',
      percent: true,
    ),
    (
      label: 'Second player win rate',
      key: 'secondPlayerWinRate',
      percent: true,
    ),
    (label: 'Avg turns', key: 'averageTurns', percent: false),
    (label: 'Avg EYE / game', key: 'averageEyePerGame', percent: false),
    (label: 'One-sided rate', key: 'oneSidedGameRate', percent: true),
    (label: 'JUDGE usage rate', key: 'overallJudgeUsageRate', percent: true),
    (
      label: 'Reverse usage rate',
      key: 'overallReverseUsageRate',
      percent: true,
    ),
    (
      label: 'Avg contested persons',
      key: 'averageContestedPersons',
      percent: false,
    ),
  ];

  String fmt(num value, bool percent) =>
      percent ? '${(value * 100).toStringAsFixed(1)}%' : value.toStringAsFixed(2);

  final buffer = StringBuffer()
    ..writeln('# Rule 1.1 vs 1.2 comparison')
    ..writeln()
    ..writeln(
      'games=$games seed=$baseSeed savior=${savior.name} '
      'executor=${executor.name} first=${first.name}',
    )
    ..writeln()
    ..writeln('| Metric | Rule 1.1 | Rule 1.2 | Diff (1.2 - 1.1) |')
    ..writeln('|---|---|---|---|');
  for (final row in rows) {
    final v11 = run11.statistics.values[row.key]! as num;
    final v12 = run12.statistics.values[row.key]! as num;
    final diff = v12 - v11;
    final diffLabel = row.percent
        ? '${(diff * 100).toStringAsFixed(1)}pt'
        : diff.toStringAsFixed(2);
    buffer.writeln(
      '| ${row.label} | ${fmt(v11, row.percent)} | ${fmt(v12, row.percent)} | $diffLabel |',
    );
  }

  final eyeZone = EyeZoneReport.fromResults(run12.results);
  buffer
    ..writeln()
    ..writeln('## EYE / center-zone (rule 1.2 only)')
    ..writeln()
    ..writeln(eyeZone.toConsoleReport());

  print(buffer.toString());

  if (options.containsKey('export-markdown')) {
    final path = _outputPath(
      options['export-markdown'],
      'rule_comparison_$games.md',
    );
    _write(path, buffer.toString());
    print('Markdown: $path');
  }
  if (options.containsKey('export-json')) {
    final path = _outputPath(
      options['export-json'],
      'rule_comparison_$games.json',
    );
    final json = {
      'games': games,
      'seed': baseSeed,
      'savior': savior.name,
      'executor': executor.name,
      'first': first.name,
      'rule1_1': run11.statistics.toJson(),
      'rule1_2': run12.statistics.toJson(),
      'rule1_2EyeZone': eyeZone.toJson(),
    };
    _write(path, const JsonEncoder.withIndent('  ').convert(json));
    print('JSON: $path');
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

String _outputPath(String? option, String fallbackName) {
  if (option != null && option.isNotEmpty) return option;
  return 'simulation_output${Platform.pathSeparator}$fallbackName';
}

void _write(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}
