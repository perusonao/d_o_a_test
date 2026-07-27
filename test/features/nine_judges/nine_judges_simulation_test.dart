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
  });
}
