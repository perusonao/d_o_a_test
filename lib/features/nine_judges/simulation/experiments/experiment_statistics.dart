import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
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

    final results = [for (final outcome in outcomes) outcome.result];
    if (results.isNotEmpty) {
      final saviorWins = results.where((r) => r.winner == Faction.savior).length;
      final executorWins = results
          .where((r) => r.winner == Faction.executor)
          .length;
      values['saviorWinRate95CI'] = _wilson(saviorWins, games);
      values['executorWinRate95CI'] = _wilson(executorWins, games);
      final firstWins = results
          .where((r) => r.winner == r.firstPlayer)
          .length;
      values['firstWinRate95CI'] = _wilson(firstWins, games);
    }

    // EYE grid: how the center row (the only legal EYE zone this round) was
    // actually resolved — via EYE, or "blind" through LIFE/DEATH alone.
    if (experiment.eyeZoneMode == EyeZoneMode.centerOnly) {
      const center = [3, 4, 5];
      final eyedCounts = <int>[];
      final blindConfirmedCounts = <int>[];
      final eyeTargetTally = {for (final i in center) i: 0};
      final eyeUsesPerPlayer = <int>[];
      for (final result in results) {
        final eyedHere = <int>{};
        for (final action in result.actions) {
          if (action.action == ActionType.eye) {
            eyedHere.add(action.targetIndex);
            eyeTargetTally[action.targetIndex] =
                (eyeTargetTally[action.targetIndex] ?? 0) + 1;
          }
        }
        eyedCounts.add(eyedHere.length);
        blindConfirmedCounts.add(center.length - eyedHere.length);
        eyeUsesPerPlayer
          ..add(result.saviorEyeCount)
          ..add(result.executorEyeCount);
      }
      values['centerPersonsEyedAverage'] = average(eyedCounts);
      values['centerPersonsBlindConfirmedAverage'] = average(
        blindConfirmedCounts,
      );
      values['eyeTargetDistribution'] = eyeTargetTally.map(
        (index, count) => MapEntry('$index', count),
      );
      final usageDistribution = <String, int>{};
      for (final count in eyeUsesPerPlayer) {
        final key = '$count';
        usageDistribution[key] = (usageDistribution[key] ?? 0) + 1;
      }
      values['eyeUsesPerPlayerDistribution'] = usageDistribution;
    }

    // REVOKE (Experiment 4): usage profile plus the requested per-event
    // breakdown. Every figure here is descriptive/correlational, never
    // causal (see REPORT_NEXT_RULE.md).
    if (experiment.revokeBudgetFirstPlayer > 0 ||
        experiment.revokeBudgetSecondPlayer > 0) {
      final revokeCounts = outcomes
          .map((o) => o.extras['revokeCount']! as int)
          .toList();
      final allEvents = <Map<String, Object?>>[
        for (final outcome in outcomes)
          ...?(outcome.extras['revokeEvents'] as List<Map<String, Object?>>?),
      ];
      final usedGames = outcomes
          .where((o) => (o.extras['revokeCount']! as int) > 0)
          .length;
      final firstPlayerEvents = <Map<String, Object?>>[];
      final secondPlayerEvents = <Map<String, Object?>>[];
      for (var i = 0; i < outcomes.length; i++) {
        final events =
            outcomes[i].extras['revokeEvents'] as List<Map<String, Object?>>?;
        if (events == null) continue;
        final firstPlayer = outcomes[i].result.firstPlayer;
        for (final event in events) {
          if (event['faction'] == firstPlayer.name) {
            firstPlayerEvents.add(event);
          } else {
            secondPlayerEvents.add(event);
          }
        }
      }
      final lifeRemoved = allEvents
          .where((e) => e['removedAction'] == 'life')
          .length;
      final deathRemoved = allEvents
          .where((e) => e['removedAction'] == 'death')
          .length;
      final contestedUses = allEvents
          .where((e) => e['wasContestedSoFar'] == true)
          .length;
      final touchedAgain = <bool>[
        for (final outcome in outcomes)
          ...?(outcome.extras['revokeTargetTouchedAgainAfter'] as List<bool>?),
      ];
      final gotCredit = <bool>[
        for (final outcome in outcomes)
          ...?(outcome.extras['revokeUserGotFinalCredit'] as List<bool>?),
      ];
      final finalScorers = <String?>[
        for (final outcome in outcomes)
          ...?(outcome.extras['revokeTargetFinalScorer'] as List<String?>?),
      ];
      final attributeTally = <String, int>{};
      final historyLengths = <int>[];
      final turns = <int>[];
      for (final event in allEvents) {
        final attribute = event['attribute']! as String;
        attributeTally[attribute] = (attributeTally[attribute] ?? 0) + 1;
        historyLengths.add(event['historyLengthBefore']! as int);
        turns.add(event['turn']! as int);
      }
      values['revokeUsageRate'] = rate(usedGames);
      values['revokeAveragePerGame'] = average(revokeCounts);
      values['revokeTotalEvents'] = allEvents.length;
      values['revokeAverageTurn'] = average(turns);
      values['revokeFirstPlayerUsageRate'] = rate(
        outcomes.where((o) {
          final events =
              o.extras['revokeEvents'] as List<Map<String, Object?>>?;
          return events != null &&
              events.any((e) => e['faction'] == o.result.firstPlayer.name);
        }).length,
      );
      values['revokeSecondPlayerUsageRate'] = rate(
        outcomes.where((o) {
          final events =
              o.extras['revokeEvents'] as List<Map<String, Object?>>?;
          return events != null &&
              events.any((e) => e['faction'] != o.result.firstPlayer.name);
        }).length,
      );
      values['revokeTargetAttributeDistribution'] = attributeTally;
      values['revokeAverageHistoryLengthBefore'] = average(historyLengths);
      values['revokeLifeRemovedCount'] = lifeRemoved;
      values['revokeDeathRemovedCount'] = deathRemoved;
      values['revokeContestedSoFarRate'] = allEvents.isEmpty
          ? 0.0
          : contestedUses / allEvents.length;
      values['revokeTargetTouchedAgainRate'] = touchedAgain.isEmpty
          ? 0.0
          : touchedAgain.where((v) => v).length / touchedAgain.length;
      values['revokeUserGotFinalCreditRate'] = gotCredit.isEmpty
          ? 0.0
          : gotCredit.where((v) => v).length / gotCredit.length;
      values['revokeTargetFinalScorerSaviorRate'] = finalScorers.isEmpty
          ? 0.0
          : finalScorers.where((s) => s == 'savior').length /
                finalScorers.length;

      // Reference-only correlation, not causal: win rate in games where a
      // REVOKE happened to be used vs games where it wasn't.
      final withRevoke = [
        for (final o in outcomes)
          if ((o.extras['revokeCount']! as int) > 0) o.result,
      ];
      final withoutRevoke = [
        for (final o in outcomes)
          if ((o.extras['revokeCount']! as int) == 0) o.result,
      ];
      double firstWinRateOf(List<SimulationResult> list) => list.isEmpty
          ? 0.0
          : list.where((r) => r.winner == r.firstPlayer).length / list.length;
      values['firstWinRateInGamesWithRevoke'] = firstWinRateOf(withRevoke);
      values['firstWinRateInGamesWithoutRevoke'] = firstWinRateOf(
        withoutRevoke,
      );
      values['gamesWithRevoke'] = withRevoke.length;
      values['gamesWithoutRevoke'] = withoutRevoke.length;
    }

    return ExperimentExtraStatistics._(values);
  }

  static Map<String, double> _wilson(int successes, int total) {
    if (total == 0) return {'lower': 0, 'upper': 0};
    const z = 1.959963984540054;
    final p = successes / total;
    final denominator = 1 + z * z / total;
    final center = (p + z * z / (2 * total)) / denominator;
    final margin =
        z * sqrt((p * (1 - p) + z * z / (4 * total)) / total) / denominator;
    return {'lower': center - margin, 'upper': center + margin};
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
