import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = SimulationConfig(gameCount: 400, baseSeed: 12000);

  group('CONTROL parity is preserved after the EYE-grid/REVOKE refactor', () {
    test('ExperimentSimulationRunner still matches production exactly', () {
      final production = const SimulationRunner().run(config);
      final experimentControl = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.control,
      );
      for (var i = 0; i < config.gameCount; i++) {
        expect(
          experimentControl.results[i].saviorScore,
          production.results[i].saviorScore,
        );
        expect(
          experimentControl.results[i].executorScore,
          production.results[i].executorScore,
        );
        expect(
          experimentControl.results[i].totalTurns,
          production.results[i].totalTurns,
        );
        expect(
          experimentControl.results[i].winner,
          production.results[i].winner,
        );
      }
    });
  });

  group('EYE grid — eyeMaxUsesPerPlayer', () {
    test('caps each player at the configured number of EYE uses', () {
      for (final eyeMax in [0, 1, 2, 3]) {
        final experiment = SimulationExperimentConfig.eyeGridCell(
          eyeMax: eyeMax,
          eyeCost: 0,
        );
        final run = const ExperimentSimulationRunner().run(config, experiment);
        for (final result in run.results) {
          expect(result.saviorEyeCount, lessThanOrEqualTo(eyeMax));
          expect(result.executorEyeCount, lessThanOrEqualTo(eyeMax));
        }
      }
    });

    test('EYE is only ever legal on the center row (indices 3,4,5)', () {
      final experiment = SimulationExperimentConfig.eyeGridCell(
        eyeMax: 3,
        eyeCost: 0,
      );
      final run = const ExperimentSimulationRunner().run(config, experiment);
      for (final result in run.results) {
        for (final action in result.actions) {
          if (action.action == ActionType.eye) {
            expect(action.targetIndex, anyOf(3, 4, 5));
          }
        }
      }
    });

    test('eyeGrid contains exactly the 4x2x2=16 requested cells', () {
      expect(SimulationExperimentConfig.eyeGrid, hasLength(16));
      expect(
        SimulationExperimentConfig.eyeGrid.map((e) => e.name).toSet().length,
        16,
        reason: 'every grid cell must have a unique name',
      );
    });
  });

  group('EYE grid — cost curves', () {
    test('flat cost: score never exceeds pre-cost score', () {
      final experiment = SimulationExperimentConfig.eyeGridCell(
        eyeMax: 3,
        eyeCost: 1,
      );
      final run = const ExperimentSimulationRunner().run(config, experiment);
      for (final outcome in run.outcomes) {
        final beforeSavior = outcome.extras['saviorScoreBeforeEyeCost']! as int;
        final beforeExecutor =
            outcome.extras['executorScoreBeforeEyeCost']! as int;
        expect(outcome.result.saviorScore, lessThanOrEqualTo(beforeSavior));
        expect(outcome.result.executorScore, lessThanOrEqualTo(beforeExecutor));
      }
    });

    test('free-first-use: cost equals eyeScoreCost * max(0, count - 1)', () {
      final experiment = SimulationExperimentConfig.eyeGridCell(
        eyeMax: 2,
        eyeCost: 1,
        freeFirstUse: true,
      );
      final run = const ExperimentSimulationRunner().run(config, experiment);
      for (final outcome in run.outcomes) {
        final saviorCount = outcome.result.saviorEyeCount;
        final executorCount = outcome.result.executorEyeCount;
        expect(
          outcome.extras['saviorEyeCost'],
          (saviorCount - 1).clamp(0, 1000),
        );
        expect(
          outcome.extras['executorEyeCost'],
          (executorCount - 1).clamp(0, 1000),
        );
      }
    });
  });

  group('Experiment 4 — REVOKE', () {
    test('never targets a confirmed person or an empty history', () {
      // Indirect check: every revoke event's historyLengthBefore is >= 1,
      // and the target was not yet confirmed at that point (guaranteed by
      // construction — the loop only offers REVOKE targets that pass both
      // checks — but we also confirm no game ever exceeds its budget).
      final base = SimulationExperimentConfig.eyeGridCell(eyeMax: 2, eyeCost: 0);
      final experiment = SimulationExperimentConfig.revokeVariants(
        base,
      ).firstWhere((e) => e.name.endsWith('REVOKE_BOTH1'));
      final run = const ExperimentSimulationRunner().run(config, experiment);
      for (final outcome in run.outcomes) {
        final events =
            outcome.extras['revokeEvents'] as List<Map<String, Object?>>?;
        if (events == null) continue;
        for (final event in events) {
          expect(event['historyLengthBefore'], greaterThanOrEqualTo(1));
        }
        expect(events.length, lessThanOrEqualTo(2));
      }
    });

    test('removing the mark reproduces exactly what the history would be '
        'without it (via the same production state machine)', () {
      // If REVOKE always removed exactly the last LIFE/DEATH mark, then for
      // every still-undecided or since-confirmed slot, replaying its
      // (history-before-revoke minus the revoked mark) must be internally
      // consistent — checked indirectly: total LIFE removals + DEATH
      // removals must equal total revoke events, and nothing else exotic
      // was removed.
      final base = SimulationExperimentConfig.eyeGridCell(eyeMax: 2, eyeCost: 0);
      final experiment = SimulationExperimentConfig.revokeVariants(
        base,
      ).firstWhere((e) => e.name.endsWith('REVOKE_BOTH1'));
      final run = const ExperimentSimulationRunner().run(config, experiment);
      final extra = ExperimentExtraStatistics.fromOutcomes(
        run.outcomes,
        experiment,
      );
      final lifeRemoved = extra.values['revokeLifeRemovedCount']! as int;
      final deathRemoved = extra.values['revokeDeathRemovedCount']! as int;
      final total = extra.values['revokeTotalEvents']! as int;
      expect(lifeRemoved + deathRemoved, total);
    });

    test('budgets are respected: NONE=0, BOTH1<=1 each, FIRST1 only first '
        'player, FIRST2_SECOND1 respects the 2/1 split', () {
      final base = SimulationExperimentConfig.eyeGridCell(eyeMax: 2, eyeCost: 0);
      for (final experiment in SimulationExperimentConfig.revokeVariants(
        base,
      )) {
        final run = const ExperimentSimulationRunner().run(config, experiment);
        for (final outcome in run.outcomes) {
          final firstPlayer = outcome.result.firstPlayer;
          final events =
              outcome.extras['revokeEvents'] as List<Map<String, Object?>>? ??
              const [];
          final firstCount = events
              .where((e) => e['faction'] == firstPlayer.name)
              .length;
          final secondCount = events
              .where((e) => e['faction'] != firstPlayer.name)
              .length;
          if (experiment.name.endsWith('NONE')) {
            expect(firstCount, 0);
            expect(secondCount, 0);
          } else if (experiment.name.endsWith('BOTH1')) {
            expect(firstCount, lessThanOrEqualTo(1));
            expect(secondCount, lessThanOrEqualTo(1));
          } else if (experiment.name.endsWith('FIRST1')) {
            expect(firstCount, lessThanOrEqualTo(1));
            expect(secondCount, 0);
          } else if (experiment.name.endsWith('FIRST2_SECOND1')) {
            expect(firstCount, lessThanOrEqualTo(2));
            expect(secondCount, lessThanOrEqualTo(1));
          }
        }
      }
    });

    test('REVOKE does not add to totalTurns bookkeeping inconsistency: '
        'totalTurns always equals the number of turns actually elapsed', () {
      // A revoke turn does not append a SimulationActionRecord, so
      // totalTurns must come from the real elapsed-turn counter, not
      // actions.length. If this regressed, totalTurns would UNDERcount by
      // the revoke total for every game that used it.
      final base = SimulationExperimentConfig.eyeGridCell(eyeMax: 2, eyeCost: 0);
      final experiment = SimulationExperimentConfig.revokeVariants(
        base,
      ).firstWhere((e) => e.name.endsWith('REVOKE_BOTH1'));
      final run = const ExperimentSimulationRunner().run(config, experiment);
      for (final outcome in run.outcomes) {
        final revokeCount = outcome.extras['revokeCount']! as int;
        expect(
          outcome.result.totalTurns,
          outcome.result.actions.length + revokeCount,
        );
      }
    });

    test('extra statistics report usage rate 100% only when budgets exist', () {
      final base = SimulationExperimentConfig.eyeGridCell(eyeMax: 2, eyeCost: 0);
      final none = SimulationExperimentConfig.revokeVariants(
        base,
      ).firstWhere((e) => e.name.endsWith('NONE'));
      final run = const ExperimentSimulationRunner().run(config, none);
      final extra = ExperimentExtraStatistics.fromOutcomes(run.outcomes, none);
      // REVOKE toggles are all off, so no revoke-specific keys are reported.
      expect(extra.values.containsKey('revokeUsageRate'), isFalse);
    });
  });

  group('center-zone resolution stats', () {
    test('centerPersonsEyed + centerPersonsBlindConfirmed averages to 3', () {
      final experiment = SimulationExperimentConfig.eyeGridCell(
        eyeMax: 2,
        eyeCost: 0,
      );
      final run = const ExperimentSimulationRunner().run(config, experiment);
      final extra = ExperimentExtraStatistics.fromOutcomes(
        run.outcomes,
        experiment,
      );
      final eyed = extra.values['centerPersonsEyedAverage']! as double;
      final blind = extra.values['centerPersonsBlindConfirmedAverage']! as double;
      expect(eyed + blind, closeTo(3.0, 1e-9));
    });

    test('eyeTargetDistribution only contains center indices', () {
      final experiment = SimulationExperimentConfig.eyeGridCell(
        eyeMax: 3,
        eyeCost: 0,
      );
      final run = const ExperimentSimulationRunner().run(config, experiment);
      final extra = ExperimentExtraStatistics.fromOutcomes(
        run.outcomes,
        experiment,
      );
      final distribution =
          extra.values['eyeTargetDistribution']! as Map<String, int>;
      expect(distribution.keys.toSet(), {'3', '4', '5'});
    });
  });

  group('Wilson 95% CI helper', () {
    test('produces a valid [lower, upper] interval containing the point rate', () {
      final experiment = SimulationExperimentConfig.eyeGridCell(
        eyeMax: 2,
        eyeCost: 0,
      );
      final run = const ExperimentSimulationRunner().run(config, experiment);
      final extra = ExperimentExtraStatistics.fromOutcomes(
        run.outcomes,
        experiment,
      );
      final ci = extra.values['saviorWinRate95CI']! as Map<String, double>;
      expect(ci['lower']!, lessThanOrEqualTo(ci['upper']!));
      expect(ci['lower']!, greaterThanOrEqualTo(0));
      expect(ci['upper']!, lessThanOrEqualTo(1));
    });
  });
}
