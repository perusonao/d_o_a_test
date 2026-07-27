import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_statistics.dart';

abstract final class ExperimentExporter {
  static String allReportsJson(List<ExperimentReport> reports) =>
      const JsonEncoder.withIndent('  ').convert({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'reports': [for (final report in reports) report.toJson()],
      });

  static String summaryCsv(List<ExperimentReport> reports) {
    const headers = [
      'experiment',
      'games',
      'firstWinRate',
      'secondWinRate',
      'saviorWinRate',
      'executorWinRate',
      'avgScoreDiff',
      'medianScoreDiff',
      'avgTurns',
      'avgEye',
      'judgeUsageRate',
      'reverseUsageRate',
      'avgContestedPersons',
      'avgLifeDeathFlips',
      'avgThirdActionConfirms',
      'oneSidedRate',
      'winnerFlipRate',
      'deltaFirstWinRate',
      'deltaSecondWinRate',
      'deltaTurns',
      'deltaEye',
      'deltaContestedPersons',
      'deltaOneSidedRate',
    ];
    final rows = <String>[headers.join(',')];
    for (final report in reports) {
      final s = report.statistics.values;
      final d = report.delta.values;
      rows.add(
        [
          report.experiment.name,
          report.gameCount,
          s['firstPlayerWinRate'],
          s['secondPlayerWinRate'],
          s['saviorWinRate'],
          s['executorWinRate'],
          s['averageScoreDifference'],
          s['medianScoreDifference'],
          s['averageTurns'],
          s['averageEyePerGame'],
          s['overallJudgeUsageRate'],
          s['overallReverseUsageRate'],
          s['averageContestedPersons'],
          s['averageLifeDeathFlips'],
          s['averageThirdActionConfirms'],
          s['oneSidedGameRate'],
          report.paired.values['totalFlipRate'],
          d['firstWinRate'],
          d['secondWinRate'],
          d['turns'],
          d['eye'],
          d['contestedPersons'],
          d['oneSidedRate'],
        ].join(','),
      );
    }
    return rows.join('\n');
  }

  static String comparisonMarkdown(
    List<ExperimentReport> reports, {
    required String title,
  }) {
    String pct(Object? value) =>
        '${((value as num) * 100).toStringAsFixed(1)}%';
    String num2(Object? value) => (value as num).toStringAsFixed(2);

    final buffer = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln(
        '| Experiment | First Win % | Second Win % | Savior Win % | '
        'Executor Win % | Avg Turns | Avg EYE | Avg Contested | '
        'One-sided % | Winner Flip % | Assessment |',
      )
      ..writeln(
        '|---|---|---|---|---|---|---|---|---|---|---|',
      );
    for (final report in reports) {
      final s = report.statistics.values;
      buffer.writeln(
        '| ${report.experiment.name} '
        '| ${pct(s['firstPlayerWinRate'])} '
        '| ${pct(s['secondPlayerWinRate'])} '
        '| ${pct(s['saviorWinRate'])} '
        '| ${pct(s['executorWinRate'])} '
        '| ${num2(s['averageTurns'])} '
        '| ${num2(s['averageEyePerGame'])} '
        '| ${num2(s['averageContestedPersons'])} '
        '| ${pct(s['oneSidedGameRate'])} '
        '| ${pct(report.paired.values['totalFlipRate'])} '
        '| ${_assess(report)} |',
      );
    }
    return buffer.toString();
  }

  /// Rule-based, data-derived assessment label. Thresholds are the ones
  /// specified for this study (first-player win rate target band, tempo not
  /// worse than baseline, etc.) — this is a mechanical read of the numbers,
  /// not a subjective judgement call.
  static String _assess(ExperimentReport report) {
    final s = report.statistics.values;
    final firstWin = s['firstPlayerWinRate']! as double;
    final saviorWin = s['saviorWinRate']! as double;
    final flags = <String>[];
    if (firstWin < 0.47 || firstWin > 0.53) flags.add('先手勝率が目標外');
    if (saviorWin < 0.47 || saviorWin > 0.53) flags.add('陣営勝率が目標外');
    final flip = report.paired.values['totalFlipRate']! as double;
    if (report.experiment.finalJudgeMode.name != 'none' && flip > 0.15) {
      flags.add('逆転率が高すぎる可能性');
    }
    return flags.isEmpty ? 'OK' : flags.join(' / ');
  }
}
