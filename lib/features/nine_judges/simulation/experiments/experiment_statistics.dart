import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/first_second_analysis.dart';

/// Aggregates the experiment-only figures that [SimulationStatistics] and
/// [FirstSecondAnalysis] have no field for (they only see the final,
/// post-experiment [SimulationResult], not the [ExperimentGameOutcome.extras]
/// map). Every key here is descriptive only; see `experiment_runner.dart` for
/// how each figure was produced.
class ExperimentExtraStatistics {
  const ExperimentExtraStatistics._(this.values);

  final Map<String, Object> values;

  factory ExperimentExtraStatistics.fromOutcomes(
    List<ExperimentGameOutcome> outcomes,
    SimulationExperimentConfig experiment,
  ) {
    final games = outcomes.length;
    double rate(int value) => games == 0 ? 0 : value / games;
    double average(Iterable<num> values) {
      final list = values.toList();
      return list.isEmpty
          ? 0
          : list.fold<double>(0, (sum, v) => sum + v) / list.length;
    }

    final values = <String, Object>{};

    if (experiment.finalJudgeMode == FinalJudgeMode.doubleBonus) {
      final baseBonuses = outcomes
          .map((outcome) => outcome.extras['finalJudgeBonusBase']! as int)
          .toList();
      final saviorCaptures = outcomes
          .where((outcome) => outcome.extras['finalJudgeScorer'] == 'savior')
          .length;
      final flipped = outcomes
          .where((outcome) => outcome.extras['finalJudgeFlippedWinner'] == true)
          .length;
      values['finalJudgeAverageBaseBonus'] = average(baseBonuses);
      values['finalJudgeSaviorCaptureRate'] = rate(saviorCaptures);
      values['finalJudgeExecutorCaptureRate'] = rate(games - saviorCaptures);
      values['finalJudgeFlippedWinnerCount'] = flipped;
      values['finalJudgeFlippedWinnerRate'] = rate(flipped);
    }

    if (experiment.finalJudgeMode == FinalJudgeMode.tenthPerson) {
      final outcomeCounts = <String, int>{
        'lifeLife': 0,
        'deathDeath': 0,
        'mismatch': 0,
      };
      var saviorCaptures = 0;
      var executorCaptures = 0;
      var flippedWinner = 0;
      for (final outcome in outcomes) {
        final key = outcome.extras['tenthPersonOutcome']! as String;
        outcomeCounts[key] = (outcomeCounts[key] ?? 0) + 1;
        final scorer = outcome.extras['tenthPersonScorer'] as String?;
        if (scorer == 'savior') saviorCaptures++;
        if (scorer == 'executor') executorCaptures++;
        if (outcome.extras['tenthPersonFlippedWinner'] == true) {
          flippedWinner++;
        }
      }
      values['tenthPersonLifeLifeRate'] = rate(outcomeCounts['lifeLife']!);
      values['tenthPersonDeathDeathRate'] = rate(outcomeCounts['deathDeath']!);
      values['tenthPersonMismatchRate'] = rate(outcomeCounts['mismatch']!);
      values['tenthPersonSaviorCaptureRate'] = rate(saviorCaptures);
      values['tenthPersonExecutorCaptureRate'] = rate(executorCaptures);
      values['tenthPersonFlippedWinnerCount'] = flippedWinner;
      values['tenthPersonFlippedWinnerRate'] = rate(flippedWinner);
    }

    if (experiment.judgeVariant == JudgeVariant.reverseConfirmed) {
      final counts = outcomes
          .map((outcome) => outcome.extras['judgeReversalCount']! as int)
          .toList();
      final swings = outcomes
          .map((outcome) => outcome.extras['judgeReversalSwingPoints']! as int)
          .toList();
      values['judgeReversalUsageRate'] = rate(
        counts.where((count) => count > 0).length,
      );
      values['judgeReversalAveragePerGame'] = average(counts);
      values['judgeReversalAverageSwing'] = average(swings);
      final flippedWinner = outcomes
          .where((outcome) => outcome.extras['judgeReversalFlippedWinner'] == true)
          .length;
      values['judgeReversalFlippedWinnerCount'] = flippedWinner;
      values['judgeReversalFlippedWinnerRate'] = rate(flippedWinner);
    }

    if (experiment.eyeZoneMode == EyeZoneMode.centerOnly) {
      values['eyeCenterZoneRestrictionActive'] = true;
    }

    if (experiment.eyeScoreCost > 0) {
      final saviorCosts = outcomes
          .map((outcome) => outcome.extras['saviorEyeCost']! as int)
          .toList();
      final executorCosts = outcomes
          .map((outcome) => outcome.extras['executorEyeCost']! as int)
          .toList();
      values['averageSaviorEyeCost'] = average(saviorCosts);
      values['averageExecutorEyeCost'] = average(executorCosts);
      final distribution = <String, int>{};
      for (final outcome in outcomes) {
        final total = outcome.result.saviorEyeCount + outcome.result.executorEyeCount;
        final key = total >= 4 ? '4OrMore' : '$total';
        distribution[key] = (distribution[key] ?? 0) + 1;
      }
      values['eyeCountDistribution'] = distribution;
    }

    if (experiment.firstPlayerBonusAction != FirstPlayerBonusAction.none) {
      values['firstPlayerBonusAction'] = experiment.firstPlayerBonusAction.name;
    }

    if (experiment.informationMode != InformationMode.standard) {
      values['informationMode'] = experiment.informationMode.name;
    }

    return ExperimentExtraStatistics._(values);
  }

  Map<String, Object> toJson() => values;
}

/// Per-seed CONTROL vs EXPERIMENT paired comparison, matching the task's
/// "同一seed比較" requirement: [SimulationConfig.seedFor] guarantees the
/// board, bonus deck, and CPU RNG streams are identical between the two runs
/// (any extra RNG streams an experiment needs are drawn from dedicated,
/// non-overlapping seeds), so the outcome difference is attributable to the
/// rule change alone.
class PairedComparison {
  const PairedComparison._(this.values);

  final Map<String, Object> values;

  factory PairedComparison.compare(
    List<SimulationResult> controlResults,
    List<SimulationResult> experimentResults,
  ) {
    assert(controlResults.length == experimentResults.length);
    var unchanged = 0;
    var firstToSecond = 0;
    var secondToFirst = 0;
    var involvesDraw = 0;
    for (var i = 0; i < controlResults.length; i++) {
      final control = controlResults[i];
      final experiment = experimentResults[i];
      if (control.winner == null || experiment.winner == null) {
        involvesDraw++;
        continue;
      }
      final controlWasFirst = control.winner == control.firstPlayer;
      final experimentWasFirst = experiment.winner == experiment.firstPlayer;
      if (controlWasFirst == experimentWasFirst) {
        unchanged++;
      } else if (controlWasFirst && !experimentWasFirst) {
        firstToSecond++;
      } else {
        secondToFirst++;
      }
    }
    final games = controlResults.length;
    double rate(int value) => games == 0 ? 0 : value / games;
    return PairedComparison._({
      'games': games,
      'winnerUnchanged': unchanged,
      'winnerUnchangedRate': rate(unchanged),
      'firstToSecondFlip': firstToSecond,
      'firstToSecondFlipRate': rate(firstToSecond),
      'secondToFirstFlip': secondToFirst,
      'secondToFirstFlipRate': rate(secondToFirst),
      'involvesDraw': involvesDraw,
      'totalFlipRate': rate(firstToSecond + secondToFirst),
    });
  }

  Map<String, Object> toJson() => values;
}

/// Δ vs CONTROL for the headline metrics the task asks every experiment to
/// report a delta for.
class ControlDelta {
  const ControlDelta._(this.values);

  final Map<String, Object> values;

  factory ControlDelta.compute(
    SimulationStatistics control,
    SimulationStatistics experiment,
  ) {
    double diff(String key) =>
        (experiment.values[key]! as num).toDouble() -
        (control.values[key]! as num).toDouble();
    return ControlDelta._({
      'firstWinRate': diff('firstPlayerWinRate'),
      'secondWinRate': diff('secondPlayerWinRate'),
      'saviorWinRate': diff('saviorWinRate'),
      'executorWinRate': diff('executorWinRate'),
      'turns': diff('averageTurns'),
      'eye': diff('averageEyePerGame'),
      'contestedPersons': diff('averageContestedPersons'),
      'oneSidedRate': diff('oneSidedGameRate'),
    });
  }

  Map<String, Object> toJson() => values;
}

/// Combines every requested figure for one experiment vs. CONTROL: the
/// standard [SimulationStatistics]/[FirstSecondAnalysis] (fed with the final,
/// post-experiment scores so they read exactly like a CONTROL report),
/// experiment-only figures, the paired comparison, and the Δ vs CONTROL.
class ExperimentReport {
  const ExperimentReport({
    required this.experiment,
    required this.gameCount,
    required this.elapsed,
    required this.statistics,
    required this.firstSecondAnalysis,
    required this.extra,
    required this.paired,
    required this.delta,
  });

  final SimulationExperimentConfig experiment;
  final int gameCount;
  final Duration elapsed;
  final SimulationStatistics statistics;
  final FirstSecondAnalysis firstSecondAnalysis;
  final ExperimentExtraStatistics extra;
  final PairedComparison paired;
  final ControlDelta delta;

  Map<String, Object> toJson() => {
    'experiment': experiment.name,
    'gameCount': gameCount,
    'elapsedMilliseconds': elapsed.inMilliseconds,
    'statistics': statistics.toJson(),
    'firstSecondAnalysis': firstSecondAnalysis.toJson(),
    'extra': extra.toJson(),
    'pairedComparison': paired.toJson(),
    'deltaVsControl': delta.toJson(),
  };
}
