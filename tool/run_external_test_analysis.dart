// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_record.dart';

export 'package:dead_or_alive/features/nine_judges/analysis/external_test_report.dart';

import 'package:dead_or_alive/features/nine_judges/analysis/external_test_report.dart';

/// Offline analysis for the rulesVersion 1.2 external test cohort.
///
/// Input is whatever a tester already exported via the app's "プレイログ"
/// screen ("全ログJSONを書き出す" / "チュートリアル計測JSONを書き出す") — a single
/// [GameSession] JSON object, or a JSON array of them (the shape
/// [GameLogRepository.exportGame]/[exportAllGames] already produce) — plus
/// an optional matching tutorial-events export. Nothing here talks to
/// Firebase directly; this only summarizes files a human already handed
/// over.
///
/// The aggregation/KPI logic itself (`ExternalTestReport`, `KpiResult`,
/// `KpiVerdict`) lives in
/// lib/features/nine_judges/analysis/external_test_report.dart so the admin
/// web dashboard can reuse the exact same definitions this CLI uses.
///
/// Usage:
///   dart run tool/run_external_test_analysis.dart --input=`<path>`
///       [--tutorial-events=`<path>`] [--one-sided-threshold=15]
///       [--output-dir=external_test_output]
void main(List<String> arguments) {
  final options = _parse(arguments);
  final inputPath = options['input'];
  if (inputPath == null) {
    stderr.writeln(
      'Usage: --input=<gamelog.json> [--tutorial-events=<events.json>]',
    );
    exitCode = 64;
    return;
  }
  final oneSidedThreshold = int.parse(
    options['one-sided-threshold'] ?? '$defaultOneSidedThreshold',
  );
  final outputDir = options['output-dir'] ?? 'external_test_output';

  final sessions = _loadSessions(inputPath);
  if (sessions.isEmpty) {
    stderr.writeln('No sessions found in $inputPath');
    exitCode = 1;
    return;
  }
  final tutorialEvents = options['tutorial-events'] != null
      ? _loadTutorialEvents(options['tutorial-events']!)
      : const <TutorialEventRecord>[];

  final report = ExternalTestReport.build(
    sessions: sessions,
    tutorialEvents: tutorialEvents,
    oneSidedThreshold: oneSidedThreshold,
  );

  final jsonPath = '$outputDir/external_test_report.json';
  final mdPath = '$outputDir/external_test_report.md';
  _write(jsonPath, const JsonEncoder.withIndent('  ').convert(report.toJson()));
  _write(mdPath, report.toMarkdown());
  print(
    'Games: ${sessions.length}  Unique testers: ${report.uniqueTesterCount}',
  );
  print('Wrote $jsonPath');
  print('Wrote $mdPath');
}

List<GameSession> _loadSessions(String path) {
  final raw = jsonDecode(File(path).readAsStringSync());
  if (raw is List) {
    return raw
        .map((e) => GameSession.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
  if (raw is Map) {
    return [GameSession.fromJson(raw.cast<String, dynamic>())];
  }
  throw FormatException('Unexpected JSON shape in $path');
}

List<TutorialEventRecord> _loadTutorialEvents(String path) {
  final raw = jsonDecode(File(path).readAsStringSync());
  if (raw is! List) throw FormatException('Unexpected JSON shape in $path');
  return raw
      .map(
        (e) => TutorialEventRecord.fromJson((e as Map).cast<String, dynamic>()),
      )
      .toList();
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

void _write(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}
