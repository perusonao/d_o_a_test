import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_rule_flags.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SimulationRuleFlags.current (default)', () {
    test('reproduces the exact same games as an unset ruleFlags config', () {
      const withDefaultFlags = SimulationConfig(gameCount: 20, baseSeed: 777);
      const withExplicitCurrent = SimulationConfig(
        gameCount: 20,
        baseSeed: 777,
        ruleFlags: SimulationRuleFlags.current,
      );
      final a = const SimulationRunner().run(withDefaultFlags);
      final b = const SimulationRunner().run(withExplicitCurrent);
      expect(
        a.results.map((r) => r.toJson()).toList(),
        b.results.map((r) => r.toJson()).toList(),
      );
    });
  });

  group('SimulationRuleFlags.judgeFreeWithNaturalConfirmation (pattern②)', () {
    test('JUDGE can confirm a person outside the deliberating/0-history state', () {
      const config = SimulationConfig(
        gameCount: 100,
        baseSeed: 555,
        ruleFlags: SimulationRuleFlags.judgeFreeWithNaturalConfirmation,
      );
      final run = const SimulationRunner().run(config);
      final judgeOnNonFreshPerson = run.results
          .expand((result) => result.actions)
          .where(
            (action) =>
                action.action == ActionType.specialVerdict &&
                (action.historyBefore.isNotEmpty ||
                    action.stateBefore != VerdictState.deliberating),
          );
      expect(judgeOnNonFreshPerson, isNotEmpty);
      // Statistics/FirstSecondAnalysis must not crash for this preset.
      expect(run.statistics.toJson()['gameCount'], 100);
      expect(run.firstSecondAnalysis.toJson()['games'], 100);
    });
  });

  group('SimulationRuleFlags.judgeOnlyConfirmation (pattern③)', () {
    const config = SimulationConfig(
      gameCount: 50,
      baseSeed: 333,
      ruleFlags: SimulationRuleFlags.judgeOnlyConfirmation,
    );

    test('LIFE/DEATH never confirm a person on their own', () {
      final run = const SimulationRunner().run(config);
      for (final result in run.results) {
        expect(result.saviorNaturalConfirmationCount, 0);
        expect(result.executorNaturalConfirmationCount, 0);
      }
      // Statistics/FirstSecondAnalysis must not crash even though every
      // game currently exhausts the turn cap (see below) with 0 or few
      // confirmations.
      expect(run.statistics.toJson()['gameCount'], 50);
      expect(run.firstSecondAnalysis.toJson()['games'], 50);
    });

    test(
      'known current limitation: existing CPU logic rarely chooses JUDGE '
      'once it is unlimited, so this preset mostly exhausts the turn limit '
      '— turnLimitReachedRate surfaces this instead of crashing',
      () {
        final run = const SimulationRunner().run(config);
        final timeoutRate =
            run.statistics.toJson()['turnLimitReachedRate']! as double;
        expect(timeoutRate, greaterThan(0));
      },
    );
  });

  group('Individual rule flags', () {
    test('eyeEnabled: false removes EYE from every game entirely', () {
      const config = SimulationConfig(
        gameCount: 30,
        baseSeed: 111,
        ruleFlags: SimulationRuleFlags(eyeEnabled: false),
      );
      final run = const SimulationRunner().run(config);
      expect(
        run.results.expand((r) => r.actions).where(
          (a) => a.action == ActionType.eye,
        ),
        isEmpty,
      );
    });

    test(
      'reverseLifeEnabled: false blocks executor LIFE but savior LIFE stays legal',
      () {
        const config = SimulationConfig(
          gameCount: 30,
          baseSeed: 222,
          ruleFlags: SimulationRuleFlags(reverseLifeEnabled: false),
        );
        final run = const SimulationRunner().run(config);
        final actions = run.results.expand((r) => r.actions);
        expect(
          actions.where(
            (a) =>
                a.action == ActionType.life && a.faction == Faction.executor,
          ),
          isEmpty,
        );
        expect(
          actions.where(
            (a) => a.action == ActionType.life && a.faction == Faction.savior,
          ),
          isNotEmpty,
        );
      },
    );

    test('bonusAlwaysPublic: true means every action sees a known bonus', () {
      const config = SimulationConfig(
        gameCount: 20,
        baseSeed: 444,
        ruleFlags: SimulationRuleFlags(bonusAlwaysPublic: true),
      );
      final run = const SimulationRunner().run(config);
      for (final action in run.results.expand((r) => r.actions)) {
        expect(action.currentBonusKnown, isTrue);
      }
    });

    test('judgeUsesPerPlayer caps JUDGE uses per faction per game', () {
      const config = SimulationConfig(
        gameCount: 40,
        baseSeed: 888,
        ruleFlags: SimulationRuleFlags(judgeUsesPerPlayer: 2),
      );
      final run = const SimulationRunner().run(config);
      for (final result in run.results) {
        for (final faction in Faction.values) {
          final uses = result.actions
              .where(
                (a) =>
                    a.faction == faction &&
                    a.action == ActionType.specialVerdict,
              )
              .length;
          expect(uses, lessThanOrEqualTo(2));
        }
      }
    });
  });
}
