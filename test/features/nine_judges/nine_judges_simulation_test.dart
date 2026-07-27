import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_exporter.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = SimulationConfig(gameCount: 10, baseSeed: 4242);

  test('10 CPU vs CPU games finish with internally consistent results', () {
    final run = const SimulationRunner().run(config);

    expect(run.results, hasLength(10));
    for (final result in run.results) {
      expect(result.finalConfirmedCount, 9);
      expect(result.saviorScore + result.executorScore, 45);
      expect(result.totalTurns, result.actions.length);
      expect(
        result.saviorEyeCount + result.executorEyeCount,
        result.actions
            .where((action) => action.action == ActionType.eye)
            .length,
      );
      expect(
        (result.saviorJudgeUsed ? 1 : 0) + (result.executorJudgeUsed ? 1 : 0),
        result.actions
            .where((action) => action.action == ActionType.specialVerdict)
            .length,
      );
      expect(
        (result.saviorReverseUsed ? 1 : 0) +
            (result.executorReverseUsed ? 1 : 0),
        result.actions.where((action) => action.wasReverseAction).length,
      );
      if (result.saviorScore > result.executorScore) {
        expect(result.winner, Faction.savior);
      } else if (result.executorScore > result.saviorScore) {
        expect(result.winner, Faction.executor);
      } else {
        expect(result.winner, isNull);
      }
    }
  });

  test('same configuration and base seed reproduce identical games', () {
    final first = const SimulationRunner().run(config);
    final second = const SimulationRunner().run(config);
    expect(
      first.results.map((result) => result.toJson()).toList(),
      second.results.map((result) => result.toJson()).toList(),
    );
  });

  test('CSV and summary JSON exports are valid', () {
    final run = const SimulationRunner().run(config);
    final csv = SimulationExporter.resultsCsv(run);
    expect(csv.split('\n'), hasLength(11));
    expect(csv, contains('gameIndex,seed,winner'));

    final json = jsonDecode(SimulationExporter.summaryJson(run));
    expect(json['config']['gameCount'], 10);
    expect(json['statistics']['gameCount'], 10);
    expect(json['firstSecondAnalysis']['games'], 10);
  });

  test('turn-order detail aggregates reconcile with action records', () {
    final run = const SimulationRunner().run(config);
    final analysis = run.firstSecondAnalysis.toJson();
    final firstSecond = analysis['firstSecond']! as Map<String, Object>;
    final first = firstSecond['first']! as Map<String, Object>;
    final second = firstSecond['second']! as Map<String, Object>;
    expect((first['wins']! as int) + (second['wins']! as int), 10);

    final firstScoreTotal = run.results.fold<int>(0, (sum, result) {
      return sum +
          (result.firstPlayer == Faction.savior
              ? result.saviorScore
              : result.executorScore);
    });
    final secondScoreTotal = run.results.fold<int>(
      0,
      (sum, result) =>
          sum +
          (result.firstPlayer == Faction.savior
              ? result.executorScore
              : result.saviorScore),
    );
    expect(firstScoreTotal + secondScoreTotal, 10 * 45);

    final order = analysis['confirmationOrder']! as Map<String, Object>;
    expect(
      order.values.fold<int>(
        0,
        (sum, value) => sum + ((value as Map<String, Object>)['total']! as int),
      ),
      10 * 9,
    );

    final third = analysis['threeActionConfirmation']! as Map<String, Object>;
    final loggedThird = run.results
        .expand((result) => result.actions)
        .where(
          (action) =>
              action.confirmedThisAction &&
              action.action != ActionType.specialVerdict &&
              action.historyAfter.length == 3,
        )
        .length;
    expect(third['total'], loggedThird);

    final eye = analysis['eyeTiming']! as Map<String, Object>;
    expect(
      (eye['turnBands']! as Map<String, Object>).values.fold<int>(
        0,
        (sum, value) => sum + (value as int),
      ),
      eye['total'],
    );
    final reverse = analysis['reverseTiming']! as Map<String, Object>;
    expect(
      (reverse['turnBands']! as Map<String, Object>).values.fold<int>(
        0,
        (sum, value) => sum + (value as int),
      ),
      reverse['total'],
    );
    final judge = analysis['judgeAnalysis']! as Map<String, Object>;
    expect(
      (judge['bonusCounts']! as Map<String, Object>).values.fold<int>(
        0,
        (sum, value) => sum + (value as int),
      ),
      judge['total'],
    );
  });
}
