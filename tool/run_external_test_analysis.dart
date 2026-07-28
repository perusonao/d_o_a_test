// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_record.dart';

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
  final oneSidedThreshold = int.parse(options['one-sided-threshold'] ?? '15');
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

/// A metric's judgement against its target — never auto-adjusts the rules,
/// only reports where things stand (see task instruction: report first).
enum KpiVerdict { pass, watch, fail, noData }

extension on KpiVerdict {
  String get label => switch (this) {
    KpiVerdict.pass => 'PASS',
    KpiVerdict.watch => 'WATCH',
    KpiVerdict.fail => 'FAIL',
    KpiVerdict.noData => 'N/A',
  };
}

class KpiResult {
  const KpiResult({
    required this.name,
    required this.value,
    required this.verdict,
    required this.target,
  });
  final String name;
  final String value;
  final KpiVerdict verdict;
  final String target;

  Map<String, Object> toJson() => {
    'name': name,
    'value': value,
    'target': target,
    'verdict': verdict.label,
  };
}

class ExternalTestReport {
  const ExternalTestReport._(
    this.values,
    this.kpis,
    this.comments,
    this.uniqueTesterCount,
  );

  final Map<String, Object?> values;
  final List<KpiResult> kpis;
  final List<String> comments;
  final int uniqueTesterCount;

  factory ExternalTestReport.build({
    required List<GameSession> sessions,
    required List<TutorialEventRecord> tutorialEvents,
    required int oneSidedThreshold,
  }) {
    final games = sessions.length;
    final testerIds = sessions
        .map((s) => s.testerId)
        .whereType<String>()
        .toSet();
    final uniqueTesters = testerIds.length;

    double? average(Iterable<num?> values) {
      final present = values.whereType<num>().toList();
      return present.isEmpty
          ? null
          : present.reduce((a, b) => a + b) / present.length;
    }

    double rate(int value, int denominator) =>
        denominator == 0 ? 0 : value / denominator;

    final decisive = sessions.where((s) => s.winner != 'draw').toList();
    final saviorWins = sessions.where((s) => s.winner == 'savior').length;
    final executorWins = sessions.where((s) => s.winner == 'executor').length;
    final firstWins = decisive.where((s) => s.winner == s.firstPlayer).length;
    final secondWins = decisive.length - firstWins;

    final scoreDiffs = sessions
        .where((s) => s.saviorScore != null && s.executorScore != null)
        .map((s) => (s.saviorScore! - s.executorScore!).abs())
        .toList();
    final oneSided = scoreDiffs
        .where((diff) => diff >= oneSidedThreshold)
        .length;

    final turns = sessions.map((s) => s.totalTurns).toList();

    Map<String, double?> ratingAverages(Iterable<GameSession> pool) => {
      'fun': average(pool.map((s) => s.funRating)),
      'reading': average(pool.map((s) => s.readingRating)),
      'luck': average(pool.map((s) => s.luckRating)),
      'tempo': average(pool.map((s) => s.tempoRating)),
      'eyeChoice': average(pool.map((s) => s.eyeChoiceRating)),
      'ruleUnderstanding': average(pool.map((s) => s.ruleUnderstandingRating)),
      'judgeUsefulness': average(pool.map((s) => s.judgeUsefulnessRating)),
      'eyeTension': average(pool.map((s) => s.eyeTensionRating)),
      'strategicDepth': average(pool.map((s) => s.strategicDepthRating)),
      'replayIntent': average(pool.map((s) => s.replayIntentRating)),
    };
    final overallRatings = ratingAverages(sessions);
    final firstGameRatings = ratingAverages(
      sessions.where((s) => s.isFirstGame == true),
    );
    final laterGameRatings = ratingAverages(
      sessions.where((s) => s.isFirstGame == false),
    );

    final eyeActions = sessions
        .expand((s) => s.actions)
        .where((a) => a.actionType == 'eye')
        .toList();
    final eyeCountsPerGame = sessions
        .map((s) => s.actions.where((a) => a.actionType == 'eye').length)
        .toList();
    final eyeCandidates = eyeActions
        .map((a) => a.eyeCandidateCount)
        .whereType<int>()
        .toList();
    final eyeDecisionTimes = eyeActions
        .map((a) => a.turnDecisionTimeMs)
        .whereType<int>()
        .toList();

    final judgeActions = sessions
        .expand((s) => s.actions)
        .where((a) => a.actionType == 'specialVerdict')
        .toList();
    final judgeUsedGames = sessions
        .where(
          (s) =>
              s.saviorSpecialVerdictUsed == true ||
              s.executorSpecialVerdictUsed == true,
        )
        .length;
    final judgeUnusedOpportunities = <int>[
      for (final s in sessions) ...[
        if (s.saviorSpecialVerdictUsed == false) ?s.judgeOpportunityCountSavior,
        if (s.executorSpecialVerdictUsed == false)
          ?s.judgeOpportunityCountExecutor,
      ],
    ];
    final judgeDecisionTimes = judgeActions
        .map((a) => a.turnDecisionTimeMs)
        .whereType<int>()
        .toList();

    final reverseActions = sessions
        .expand((s) => s.actions)
        .where((a) => a.wasReverseAction)
        .toList();
    final reverseUsedGames = sessions
        .where(
          (s) =>
              s.saviorReverseActionUsed == true ||
              s.executorReverseActionUsed == true,
        )
        .length;

    final tutorialStarted = tutorialEvents
        .where((e) => e.type == 'tutorialStarted')
        .length;
    final tutorialCompleted = tutorialEvents
        .where((e) => e.type == 'tutorialCompleted')
        .length;
    final tutorialSkipped = tutorialEvents
        .where((e) => e.type == 'tutorialSkipped')
        .length;
    final finalSteps = tutorialEvents
        .where((e) => e.type == 'tutorialStepReached')
        .map((e) => e.step)
        .whereType<int>()
        .toList();

    final values = <String, Object?>{
      'gameCount': games,
      'uniqueTesterCount': uniqueTesters,
      'averagePlayNumberPerTester': uniqueTesters == 0
          ? null
          : games / uniqueTesters,
      'saviorWinRate': rate(saviorWins, games),
      'executorWinRate': rate(executorWins, games),
      'firstPlayerWinRate': rate(firstWins, decisive.length),
      'secondPlayerWinRate': rate(secondWins, decisive.length),
      'averageTurns': average(turns),
      'averageScoreDiff': average(scoreDiffs),
      'oneSidedRate': rate(oneSided, scoreDiffs.length),
      'ratings': overallRatings,
      'ratingsFirstGame': firstGameRatings,
      'ratingsLaterGames': laterGameRatings,
      'eye': {
        'averagePerGame': average(eyeCountsPerGame),
        'averageCandidateCount': average(eyeCandidates),
        'candidateCountOneRate': eyeCandidates.isEmpty
            ? null
            : rate(
                eyeCandidates.where((c) => c == 1).length,
                eyeCandidates.length,
              ),
        'averageDecisionTimeMs': average(eyeDecisionTimes),
      },
      'judge': {
        'usageRate': rate(judgeUsedGames, games),
        'unusedRate': rate(games - judgeUsedGames, games),
        'averageOpportunityCountWhenUnused': average(judgeUnusedOpportunities),
        'averageDecisionTimeMs': average(judgeDecisionTimes),
      },
      'reverse': {
        'usageRate': rate(reverseUsedGames, games),
        'averageTurn': average(reverseActions.map((a) => a.turnNumber)),
      },
      'tutorial': {
        'startedCount': tutorialStarted,
        'completionRate': rate(tutorialCompleted, tutorialStarted),
        'skipRate': rate(tutorialSkipped, tutorialStarted),
        'averageFinalStep': average(finalSteps),
      },
    };

    KpiVerdict band(
      double? value, {
      required double pass,
      required double watch,
      bool higherIsBetter = true,
    }) {
      if (value == null) return KpiVerdict.noData;
      if (higherIsBetter) {
        if (value >= pass) return KpiVerdict.pass;
        if (value >= watch) return KpiVerdict.watch;
        return KpiVerdict.fail;
      }
      if (value <= pass) return KpiVerdict.pass;
      if (value <= watch) return KpiVerdict.watch;
      return KpiVerdict.fail;
    }

    KpiVerdict rangeBand(
      double? value, {
      required double idealLo,
      required double idealHi,
      required double okLo,
      required double okHi,
    }) {
      if (value == null) return KpiVerdict.noData;
      if (value >= idealLo && value <= idealHi) return KpiVerdict.pass;
      if (value >= okLo && value <= okHi) return KpiVerdict.watch;
      return KpiVerdict.fail;
    }

    String pct(double? v) =>
        v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';
    String fixed(double? v) => v == null ? '-' : v.toStringAsFixed(2);

    final ruleUnderstanding = overallRatings['ruleUnderstanding'];
    final fun = overallRatings['fun'];
    final replayIntent = overallRatings['replayIntent'];
    final strategicDepth = overallRatings['strategicDepth'];
    final eyeChoice = overallRatings['eyeChoice'];
    final avgTurns = average(turns);
    final avgEye = average(eyeCountsPerGame);
    final firstWinRate = rate(firstWins, decisive.length);
    final saviorWinRate = rate(saviorWins, games);
    final oneSidedRate = rate(oneSided, scoreDiffs.length);
    final tutorialCompletionRate = rate(tutorialCompleted, tutorialStarted);

    final eyeVerdict = (avgEye == null || eyeChoice == null)
        ? KpiVerdict.noData
        : (avgEye <= 4 && eyeChoice >= 3.0)
        ? KpiVerdict.pass
        : (avgEye <= 5 && eyeChoice >= 2.5)
        ? KpiVerdict.watch
        : KpiVerdict.fail;

    final kpis = [
      KpiResult(
        name: 'ruleUnderstanding',
        value: fixed(ruleUnderstanding),
        target: '>= 4.0',
        verdict: band(ruleUnderstanding, pass: 4.0, watch: 3.5),
      ),
      KpiResult(
        name: 'fun',
        value: fixed(fun),
        target: '>= 3.5',
        verdict: band(fun, pass: 3.5, watch: 3.0),
      ),
      KpiResult(
        name: 'replayIntent',
        value: fixed(replayIntent),
        target: '>= 3.5',
        verdict: band(replayIntent, pass: 3.5, watch: 3.0),
      ),
      KpiResult(
        name: 'strategicDepth',
        value: fixed(strategicDepth),
        target: '>= 3.5',
        verdict: band(strategicDepth, pass: 3.5, watch: 3.0),
      ),
      KpiResult(
        name: 'tutorialCompletionRate',
        value: pct(tutorialStarted == 0 ? null : tutorialCompletionRate),
        target: '>= 80%',
        verdict: tutorialStarted == 0
            ? KpiVerdict.noData
            : band(tutorialCompletionRate * 100, pass: 80, watch: 60),
      ),
      KpiResult(
        name: 'averageTurns',
        value: fixed(avgTurns),
        target: '18-26',
        verdict: rangeBand(
          avgTurns,
          idealLo: 18,
          idealHi: 26,
          okLo: 15,
          okHi: 30,
        ),
      ),
      KpiResult(
        name: 'eye (avg<=4 and eyeChoice>=3.0)',
        value: 'avg=${fixed(avgEye)} eyeChoice=${fixed(eyeChoice)}',
        target: 'avg<=4 and eyeChoice>=3.0',
        verdict: eyeVerdict,
      ),
      KpiResult(
        name: 'firstPlayerWinRate',
        value: pct(decisive.isEmpty ? null : firstWinRate),
        target: '45-55%',
        verdict: decisive.isEmpty
            ? KpiVerdict.noData
            : rangeBand(
                firstWinRate * 100,
                idealLo: 45,
                idealHi: 55,
                okLo: 40,
                okHi: 60,
              ),
      ),
      KpiResult(
        name: 'saviorWinRate',
        value: pct(saviorWinRate),
        target: '45-55%',
        verdict: rangeBand(
          saviorWinRate * 100,
          idealLo: 45,
          idealHi: 55,
          okLo: 40,
          okHi: 60,
        ),
      ),
      KpiResult(
        name: 'oneSidedRate',
        value: pct(scoreDiffs.isEmpty ? null : oneSidedRate),
        target: '<= 25%',
        verdict: scoreDiffs.isEmpty
            ? KpiVerdict.noData
            : band(
                oneSidedRate * 100,
                pass: 25,
                watch: 35,
                higherIsBetter: false,
              ),
      ),
    ];

    final comments = <String>[];
    final testerIndex = <String, int>{};
    for (final session in sessions) {
      if (session.feedbackComment case final comment?
          when comment.trim().isNotEmpty) {
        final tester = session.testerId ?? 'unknown';
        final index = testerIndex.putIfAbsent(
          tester,
          () => testerIndex.length + 1,
        );
        comments.add(
          'Player ${index.toString().padLeft(3, '0')}: ${comment.trim()}',
        );
      }
    }

    return ExternalTestReport._(values, kpis, comments, uniqueTesters);
  }

  Map<String, Object> toJson() => {
    'stats': values,
    'kpis': kpis.map((k) => k.toJson()).toList(),
    'comments': comments,
  };

  /// Item 19: sample-size caveat — never treat a handful of human testers
  /// like the 50,000-game CPU simulations.
  String get _sampleSizeCaveat => switch (uniqueTesterCount) {
    0 => 'テストプレイヤーがいません。',
    >= 1 && <= 4 => '参考値。ルール判断には少なすぎます（ユニークプレイヤー $uniqueTesterCount 人）。',
    >= 5 && <= 9 => '初期傾向（ユニークプレイヤー $uniqueTesterCount 人）。',
    >= 10 && <= 19 => '改善候補の抽出に利用可能（ユニークプレイヤー $uniqueTesterCount 人）。',
    _ => '一定の傾向評価が可能（ユニークプレイヤー $uniqueTesterCount 人）。',
  };

  String toMarkdown() {
    final s = values;
    String pct(Object? v) =>
        v == null ? '-' : '${((v as num) * 100).toStringAsFixed(1)}%';
    String fixed(Object? v) => v == null ? '-' : (v as num).toStringAsFixed(2);
    final ratings = s['ratings']! as Map<String, double?>;
    final ratingsFirst = s['ratingsFirstGame']! as Map<String, double?>;
    final ratingsLater = s['ratingsLaterGames']! as Map<String, double?>;
    final eye = s['eye']! as Map<String, Object?>;
    final judge = s['judge']! as Map<String, Object?>;
    final reverse = s['reverse']! as Map<String, Object?>;
    final tutorial = s['tutorial']! as Map<String, Object?>;

    final buffer = StringBuffer()
      ..writeln('# External Test Report — rulesVersion 1.2')
      ..writeln()
      ..writeln('**サンプル数について: $_sampleSizeCaveat**')
      ..writeln('人間のサンプル数はCPU 5万戦シミュレーションと同じ信頼度では扱わないこと。')
      ..writeln()
      ..writeln('## Overview')
      ..writeln('- Games: ${s['gameCount']}')
      ..writeln('- Unique testers: ${s['uniqueTesterCount']}')
      ..writeln(
        '- Avg plays / tester: ${fixed(s['averagePlayNumberPerTester'])}',
      )
      ..writeln()
      ..writeln('## Win rates')
      ..writeln('| Metric | Value |')
      ..writeln('|---|---|')
      ..writeln('| Savior win rate | ${pct(s['saviorWinRate'])} |')
      ..writeln('| Executor win rate | ${pct(s['executorWinRate'])} |')
      ..writeln('| First player win rate | ${pct(s['firstPlayerWinRate'])} |')
      ..writeln('| Second player win rate | ${pct(s['secondPlayerWinRate'])} |')
      ..writeln('| Avg turns | ${fixed(s['averageTurns'])} |')
      ..writeln('| Avg score diff | ${fixed(s['averageScoreDiff'])} |')
      ..writeln('| One-sided rate | ${pct(s['oneSidedRate'])} |')
      ..writeln()
      ..writeln('## Ratings (1-5 average)')
      ..writeln('| Rating | Overall | First game | Later games |')
      ..writeln('|---|---|---|---|')
      ..writeln(
        '| fun | ${fixed(ratings['fun'])} | ${fixed(ratingsFirst['fun'])} | ${fixed(ratingsLater['fun'])} |',
      )
      ..writeln(
        '| reading | ${fixed(ratings['reading'])} | ${fixed(ratingsFirst['reading'])} | ${fixed(ratingsLater['reading'])} |',
      )
      ..writeln(
        '| luck | ${fixed(ratings['luck'])} | ${fixed(ratingsFirst['luck'])} | ${fixed(ratingsLater['luck'])} |',
      )
      ..writeln(
        '| tempo | ${fixed(ratings['tempo'])} | ${fixed(ratingsFirst['tempo'])} | ${fixed(ratingsLater['tempo'])} |',
      )
      ..writeln(
        '| eyeChoice | ${fixed(ratings['eyeChoice'])} | ${fixed(ratingsFirst['eyeChoice'])} | ${fixed(ratingsLater['eyeChoice'])} |',
      )
      ..writeln(
        '| ruleUnderstanding | ${fixed(ratings['ruleUnderstanding'])} | ${fixed(ratingsFirst['ruleUnderstanding'])} | ${fixed(ratingsLater['ruleUnderstanding'])} |',
      )
      ..writeln(
        '| judgeUsefulness | ${fixed(ratings['judgeUsefulness'])} | ${fixed(ratingsFirst['judgeUsefulness'])} | ${fixed(ratingsLater['judgeUsefulness'])} |',
      )
      ..writeln(
        '| eyeTension | ${fixed(ratings['eyeTension'])} | ${fixed(ratingsFirst['eyeTension'])} | ${fixed(ratingsLater['eyeTension'])} |',
      )
      ..writeln(
        '| strategicDepth | ${fixed(ratings['strategicDepth'])} | ${fixed(ratingsFirst['strategicDepth'])} | ${fixed(ratingsLater['strategicDepth'])} |',
      )
      ..writeln(
        '| replayIntent | ${fixed(ratings['replayIntent'])} | ${fixed(ratingsFirst['replayIntent'])} | ${fixed(ratingsLater['replayIntent'])} |',
      )
      ..writeln()
      ..writeln('## EYE')
      ..writeln('- Avg uses / game: ${fixed(eye['averagePerGame'])}')
      ..writeln('- Avg candidate count: ${fixed(eye['averageCandidateCount'])}')
      ..writeln(
        '- Candidate count = 1 rate: ${pct(eye['candidateCountOneRate'])}',
      )
      ..writeln(
        '- Avg decision time (ms): ${fixed(eye['averageDecisionTimeMs'])}',
      )
      ..writeln()
      ..writeln('## JUDGE')
      ..writeln('- Usage rate: ${pct(judge['usageRate'])}')
      ..writeln('- Unused rate: ${pct(judge['unusedRate'])}')
      ..writeln(
        '- Avg opportunity count (when unused): ${fixed(judge['averageOpportunityCountWhenUnused'])}',
      )
      ..writeln(
        '- Avg decision time (ms): ${fixed(judge['averageDecisionTimeMs'])}',
      )
      ..writeln()
      ..writeln('## Reverse action')
      ..writeln('- Usage rate: ${pct(reverse['usageRate'])}')
      ..writeln('- Avg turn used: ${fixed(reverse['averageTurn'])}')
      ..writeln()
      ..writeln('## Tutorial')
      ..writeln('- Started: ${tutorial['startedCount']}')
      ..writeln('- Completion rate: ${pct(tutorial['completionRate'])}')
      ..writeln('- Skip rate: ${pct(tutorial['skipRate'])}')
      ..writeln(
        '- Avg final step reached: ${fixed(tutorial['averageFinalStep'])}',
      )
      ..writeln()
      ..writeln(
        '## KPI judgement (report only — does not auto-change the rules)',
      )
      ..writeln('| Metric | Value | Target | Verdict |')
      ..writeln('|---|---|---|---|');
    for (final kpi in kpis) {
      buffer.writeln(
        '| ${kpi.name} | ${kpi.value} | ${kpi.target} | ${kpi.verdict.label} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Feedback Comments')
      ..writeln();
    if (comments.isEmpty) {
      buffer.writeln('_No comments._');
    } else {
      for (final comment in comments) {
        buffer.writeln('- $comment');
      }
    }
    return buffer.toString();
  }
}
