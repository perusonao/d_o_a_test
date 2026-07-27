import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';

/// Detailed observational metrics for diagnosing turn-order effects.
///
/// Correlations such as JUDGE-user win rate and reverse outcome alignment are
/// descriptive only; they do not establish causality.
class FirstSecondAnalysis {
  const FirstSecondAnalysis._(this.values);

  final Map<String, Object> values;

  factory FirstSecondAnalysis.fromResults(
    List<SimulationResult> results,
    SimulationConfig config,
  ) {
    final games = results.length;
    final confirmations = results
        .expand((result) => result.actions)
        .where((action) => action.confirmedThisAction)
        .toList();
    final allActions = results.expand((result) => result.actions).toList();
    final ownerByAction =
        Map<SimulationActionRecord, SimulationResult>.identity();
    for (final result in results) {
      for (final action in result.actions) {
        ownerByAction[action] = result;
      }
    }
    final firstWins = results
        .where((result) => result.winner == result.firstPlayer)
        .length;
    final secondWins = results
        .where(
          (result) =>
              result.winner != null && result.winner != result.firstPlayer,
        )
        .length;

    final firstScores = <int>[];
    final secondScores = <int>[];
    final firstBonuses = <int>[];
    final secondBonuses = <int>[];
    final firstPersons = <int>[];
    final secondPersons = <int>[];
    final firstHigh = <int>[];
    final secondHigh = <int>[];
    for (final result in results) {
      final firstScore = result.firstPlayer == Faction.savior
          ? result.saviorScore
          : result.executorScore;
      firstScores.add(firstScore);
      secondScores.add(45 - firstScore);
      final gameConfirmations = result.actions
          .where((action) => action.confirmedThisAction)
          .toList();
      final firstCaptured = gameConfirmations
          .where((action) => action.scoringFaction == result.firstPlayer)
          .toList();
      final secondCaptured = gameConfirmations
          .where((action) => action.scoringFaction != result.firstPlayer)
          .toList();
      firstPersons.add(firstCaptured.length);
      secondPersons.add(secondCaptured.length);
      firstBonuses.addAll(firstCaptured.map((action) => action.verdictBonus!));
      secondBonuses.addAll(
        secondCaptured.map((action) => action.verdictBonus!),
      );
      firstHigh.add(
        firstCaptured
            .where(
              (action) => action.verdictBonus! >= config.highBonusThreshold,
            )
            .length,
      );
      secondHigh.add(
        secondCaptured
            .where(
              (action) => action.verdictBonus! >= config.highBonusThreshold,
            )
            .length,
      );
    }

    final thirdActions = confirmations
        .where(
          (action) =>
              action.action != ActionType.specialVerdict &&
              action.historyAfter.length == 3,
        )
        .toList();
    var thirdFirstScored = 0;
    var thirdSecondScored = 0;
    var thirdSaviorScored = 0;
    var thirdExecutorScored = 0;
    var firstTouchScored = 0;
    var secondTouchScored = 0;
    var thirdTouchScored = 0;
    var thirdBonusFirst = 0;
    var thirdBonusSecond = 0;
    var thirdBonusSavior = 0;
    var thirdBonusExecutor = 0;
    final thirdActorPatterns = <String, int>{};
    for (final confirmation in thirdActions) {
      final result = ownerByAction[confirmation]!;
      final verdictActions = result.actions
          .where(
            (action) =>
                action.targetIndex == confirmation.targetIndex &&
                (action.action == ActionType.life ||
                    action.action == ActionType.death),
          )
          .take(3)
          .toList();
      final scorer = confirmation.scoringFaction!;
      final isFirstScorer = scorer == result.firstPlayer;
      if (isFirstScorer) {
        thirdFirstScored++;
        thirdBonusFirst += confirmation.verdictBonus!;
      } else {
        thirdSecondScored++;
        thirdBonusSecond += confirmation.verdictBonus!;
      }
      if (scorer == Faction.savior) {
        thirdSaviorScored++;
        thirdBonusSavior += confirmation.verdictBonus!;
      } else {
        thirdExecutorScored++;
        thirdBonusExecutor += confirmation.verdictBonus!;
      }
      if (verdictActions[0].faction == scorer) firstTouchScored++;
      if (verdictActions[1].faction == scorer) secondTouchScored++;
      if (verdictActions[2].faction == scorer) thirdTouchScored++;
      final pattern = verdictActions
          .map(
            (action) =>
                action.faction == result.firstPlayer ? 'first' : 'second',
          )
          .join('-');
      thirdActorPatterns[pattern] = (thirdActorPatterns[pattern] ?? 0) + 1;
    }

    final eyeActions = allActions
        .where((action) => action.action == ActionType.eye)
        .toList();
    final eyesBeforeFirstConfirmation = <int>[];
    final firstConfirmationTurns = <int>[];
    for (final result in results) {
      final firstConfirmation = result.actions.firstWhere(
        (action) => action.confirmedThisAction,
      );
      firstConfirmationTurns.add(firstConfirmation.turn);
      eyesBeforeFirstConfirmation.add(
        result.actions
            .where(
              (action) =>
                  action.action == ActionType.eye &&
                  action.turn < firstConfirmation.turn,
            )
            .length,
      );
    }

    final reverseActions = allActions
        .where((action) => action.wasReverseAction)
        .toList();
    var reverseUserScored = 0;
    var reverseFirst = 0;
    var reverseSecond = 0;
    final reverseFinalBonuses = <int>[];
    for (final reverse in reverseActions) {
      final result = ownerByAction[reverse]!;
      final finalConfirmation = result.actions.firstWhere(
        (action) =>
            action.targetIndex == reverse.targetIndex &&
            action.confirmedThisAction,
      );
      if (finalConfirmation.scoringFaction == reverse.faction) {
        reverseUserScored++;
      }
      if (reverse.faction == result.firstPlayer) {
        reverseFirst++;
      } else {
        reverseSecond++;
      }
      reverseFinalBonuses.add(finalConfirmation.verdictBonus!);
    }

    final judgeActions = allActions
        .where((action) => action.action == ActionType.specialVerdict)
        .toList();
    var judgeFirst = 0;
    var judgeSecond = 0;
    var judgeUserWins = 0;
    for (final judge in judgeActions) {
      final result = ownerByAction[judge]!;
      if (judge.faction == result.firstPlayer) {
        judgeFirst++;
      } else {
        judgeSecond++;
      }
      if (result.winner == judge.faction) judgeUserWins++;
    }

    final confirmationOrder = <String, Object>{
      for (var order = 1; order <= 9; order++)
        '$order': _confirmationOrderSummary(results, order),
    };
    final contested = _contestedAnalysis(results);

    return FirstSecondAnalysis._({
      'games': games,
      'firstSecond': {
        'first': {
          'wins': firstWins,
          'winRate': _rate(firstWins, games),
          'winRate95CI': _wilson(firstWins, games),
          'averageScore': _average(firstScores),
          'medianScore': _median(firstScores),
          'averageCapturedBonus': _average(firstBonuses),
          'averageCapturedPersons': _average(firstPersons),
          'averageHighBonuses': _average(firstHigh),
        },
        'second': {
          'wins': secondWins,
          'winRate': _rate(secondWins, games),
          'winRate95CI': _wilson(secondWins, games),
          'averageScore': _average(secondScores),
          'medianScore': _median(secondScores),
          'averageCapturedBonus': _average(secondBonuses),
          'averageCapturedPersons': _average(secondPersons),
          'averageHighBonuses': _average(secondHigh),
        },
      },
      'threeActionConfirmation': {
        'total': thirdActions.length,
        'averagePerGame': thirdActions.length / games,
        'scoredByFirst': thirdFirstScored,
        'scoredBySecond': thirdSecondScored,
        'scoredBySavior': thirdSaviorScored,
        'scoredByExecutor': thirdExecutorScored,
        'firstTouchScoredRate': _rate(firstTouchScored, thirdActions.length),
        'secondTouchScoredRate': _rate(secondTouchScored, thirdActions.length),
        'thirdTouchScoredRate': _rate(thirdTouchScored, thirdActions.length),
        'bonusToFirst': thirdBonusFirst,
        'bonusToSecond': thirdBonusSecond,
        'bonusToSavior': thirdBonusSavior,
        'bonusToExecutor': thirdBonusExecutor,
        'actorPatterns': thirdActorPatterns,
      },
      'eyeTiming': {
        'total': eyeActions.length,
        'averagePerGame': eyeActions.length / games,
        'firstPlayer': _actionsByTurnOrder(results, ActionType.eye, true),
        'secondPlayer': _actionsByTurnOrder(results, ActionType.eye, false),
        'savior': eyeActions
            .where((action) => action.faction == Faction.savior)
            .length,
        'executor': eyeActions
            .where((action) => action.faction == Faction.executor)
            .length,
        'turnBands': _turnBands(eyeActions.map((action) => action.turn), const [
          10,
          20,
          30,
        ]),
        'turnBandRates': _turnBandRates(
          eyeActions.map((action) => action.turn),
          const [10, 20, 30],
        ),
        'averageBeforeFirstConfirmation': _average(eyesBeforeFirstConfirmation),
        'firstConfirmationTurn': {
          'average': _average(firstConfirmationTurns),
          'median': _median(firstConfirmationTurns),
          'min': firstConfirmationTurns.reduce(min),
          'max': firstConfirmationTurns.reduce(max),
        },
      },
      'reverseTiming': {
        'total': reverseActions.length,
        'savior': reverseActions
            .where((action) => action.faction == Faction.savior)
            .length,
        'executor': reverseActions
            .where((action) => action.faction == Faction.executor)
            .length,
        'firstPlayer': reverseFirst,
        'secondPlayer': reverseSecond,
        'turnBands': _turnBands(
          reverseActions.map((action) => action.turn),
          const [10, 20, 25, 30],
        ),
        'reverseUserScoredRate': _rate(
          reverseUserScored,
          reverseActions.length,
        ),
        'averageCurrentBonusAtUse': _average(
          reverseActions.map((action) => action.currentBonusValue),
        ),
        'averageFinalTargetBonus': _average(reverseFinalBonuses),
      },
      'judgeAnalysis': {
        'total': judgeActions.length,
        'saviorUsageRate': _rate(
          judgeActions
              .where((action) => action.faction == Faction.savior)
              .length,
          games,
        ),
        'executorUsageRate': _rate(
          judgeActions
              .where((action) => action.faction == Faction.executor)
              .length,
          games,
        ),
        'firstPlayerUsageRate': _rate(judgeFirst, games),
        'secondPlayerUsageRate': _rate(judgeSecond, games),
        'averageTurn': _average(judgeActions.map((action) => action.turn)),
        'medianTurn': _median(judgeActions.map((action) => action.turn)),
        'averageBonus': _average(
          judgeActions.map((action) => action.verdictBonus!),
        ),
        'medianBonus': _median(
          judgeActions.map((action) => action.verdictBonus!),
        ),
        'bonusCounts': {
          for (var bonus = 1; bonus <= 9; bonus++)
            '$bonus': judgeActions
                .where((action) => action.verdictBonus == bonus)
                .length,
        },
        'judgeUserWinRateCorrelation': _rate(
          judgeUserWins,
          judgeActions.length,
        ),
      },
      'confirmationOrder': confirmationOrder,
      'contestedPersonAnalysis': contested,
    });
  }

  Map<String, Object> toJson() => values;

  static Map<String, Object> _confirmationOrderSummary(
    List<SimulationResult> results,
    int order,
  ) {
    var first = 0;
    var second = 0;
    var savior = 0;
    var executor = 0;
    for (final result in results) {
      final action = result.actions.firstWhere(
        (candidate) => candidate.confirmationOrder == order,
      );
      if (action.scoringFaction == result.firstPlayer) {
        first++;
      } else {
        second++;
      }
      if (action.scoringFaction == Faction.savior) {
        savior++;
      } else {
        executor++;
      }
    }
    return {
      'total': results.length,
      'firstPlayer': first,
      'secondPlayer': second,
      'firstPlayerRate': _rate(first, results.length),
      'secondPlayerRate': _rate(second, results.length),
      'savior': savior,
      'executor': executor,
    };
  }

  static Map<String, Object> _contestedAnalysis(
    List<SimulationResult> results,
  ) {
    var total = 0;
    var first = 0;
    var second = 0;
    var savior = 0;
    var executor = 0;
    final byLength = <String, Map<String, int>>{
      for (var length = 1; length <= 3; length++)
        '$length': {'total': 0, 'first': 0, 'second': 0},
    };
    for (final result in results) {
      for (var target = 0; target < 9; target++) {
        final verdictActions = result.actions
            .where(
              (action) =>
                  action.targetIndex == target &&
                  (action.action == ActionType.life ||
                      action.action == ActionType.death),
            )
            .toList();
        if (verdictActions.map((action) => action.faction).toSet().length < 2) {
          continue;
        }
        final confirmation = result.actions.firstWhere(
          (action) =>
              action.targetIndex == target && action.confirmedThisAction,
        );
        total++;
        final firstScored = confirmation.scoringFaction == result.firstPlayer;
        if (firstScored) {
          first++;
        } else {
          second++;
        }
        if (confirmation.scoringFaction == Faction.savior) {
          savior++;
        } else {
          executor++;
        }
        final key = '${confirmation.historyAfter.length.clamp(1, 3)}';
        byLength[key]!['total'] = byLength[key]!['total']! + 1;
        final orderKey = firstScored ? 'first' : 'second';
        byLength[key]![orderKey] = byLength[key]![orderKey]! + 1;
      }
    }
    return {
      'total': total,
      'firstPlayerScoredRate': _rate(first, total),
      'secondPlayerScoredRate': _rate(second, total),
      'saviorScoredRate': _rate(savior, total),
      'executorScoredRate': _rate(executor, total),
      'byHistoryLength': {
        for (final entry in byLength.entries)
          entry.key: {
            ...entry.value,
            'firstPlayerRate': _rate(
              entry.value['first']!,
              entry.value['total']!,
            ),
            'secondPlayerRate': _rate(
              entry.value['second']!,
              entry.value['total']!,
            ),
          },
      },
    };
  }

  static int _actionsByTurnOrder(
    List<SimulationResult> results,
    ActionType type,
    bool first,
  ) => results.fold(
    0,
    (sum, result) =>
        sum +
        result.actions
            .where(
              (action) =>
                  action.action == type &&
                  (action.faction == result.firstPlayer) == first,
            )
            .length,
  );

  static Map<String, int> _turnBands(
    Iterable<int> turns,
    List<int> boundaries,
  ) {
    final counts = List<int>.filled(boundaries.length + 1, 0);
    for (final turn in turns) {
      var index = boundaries.indexWhere((boundary) => turn <= boundary);
      if (index < 0) index = boundaries.length;
      counts[index]++;
    }
    return {
      for (var i = 0; i < counts.length; i++)
        _bandLabel(i, boundaries): counts[i],
    };
  }

  static Map<String, double> _turnBandRates(
    Iterable<int> turns,
    List<int> boundaries,
  ) {
    final values = turns.toList();
    final counts = _turnBands(values, boundaries);
    return {
      for (final entry in counts.entries)
        entry.key: _rate(entry.value, values.length),
    };
  }

  static String _bandLabel(int index, List<int> boundaries) {
    if (index == 0) return '1To${boundaries.first}';
    if (index == boundaries.length) return '${boundaries.last + 1}OrMore';
    return '${boundaries[index - 1] + 1}To${boundaries[index]}';
  }

  static double _rate(int numerator, int denominator) =>
      denominator == 0 ? 0 : numerator / denominator;

  static double _average(Iterable<int> values) {
    final list = values.toList();
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  static num _median(Iterable<int> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
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
}
