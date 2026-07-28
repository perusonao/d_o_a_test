import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rulesVersion 1.2 — 既定値', () {
    test('デフォルトのNineJudgesControllerは1.2で動く', () {
      final game = NineJudgesController(seed: 500);
      expect(game.settings.ruleVersion, NineJudgesRuleVersion.v1_2);
      expect(game.session.rulesVersion, '1.2');
      expect(NineJudgesConfig.rulesVersion, '1.2');
    });

    test('デフォルトのSimulationConfigは1.1のまま(既存ツールの回帰防止)', () {
      const config = SimulationConfig();
      expect(config.ruleVersion, NineJudgesRuleVersion.v1_1);
    });
  });

  group('rulesVersion 1.2 — EYEは中央3人のみ', () {
    test('中央(3,4,5)はEYE可能、自陣・相手陣は不可', () {
      final game = NineJudgesController(seed: 501);
      game.chooseAction(ActionType.eye);
      final legalEye = [
        for (var i = 0; i < 9; i++)
          if (game.canTarget(i)) i,
      ];
      expect(legalEye, unorderedEquals([3, 4, 5]));
    });

    test('相手陣は未知であってもEYE不可(v1.1では可)', () {
      final v12 = NineJudgesController(seed: 502);
      v12.chooseAction(ActionType.eye);
      // 執行者の手前(0,1,2)は救済者(先手)にとって相手陣かつ未知。
      expect(v12.canTarget(0), isFalse);

      final v11 = NineJudgesController(
        seed: 502,
        settings: const NineJudgesGameSettings(
          ruleVersion: NineJudgesRuleVersion.v1_1,
        ),
      );
      v11.chooseAction(ActionType.eye);
      expect(v11.canTarget(0), isTrue);
    });

    test('targetZoneはself/center/opponentを正しく返す', () {
      final game = NineJudgesController(seed: 503);
      expect(game.targetZone(7, Faction.savior), 'self');
      expect(game.targetZone(1, Faction.savior), 'opponent');
      expect(game.targetZone(4, Faction.savior), 'center');
    });
  });

  group('rulesVersion 1.2 — EYEは2回まで', () {
    test('初期2回、1回使用後1回、2回使用後0回で3回目は不可', () {
      final game = NineJudgesController(seed: 504);
      expect(game.eyeUsesRemaining(Faction.savior), 2);

      game.chooseAction(ActionType.eye);
      game.selectSlot(3); // 救済者の1回目のEYE
      expect(game.eyeUsesRemaining(Faction.savior), 1);
      game.confirmHandoff();

      game.chooseAction(ActionType.death);
      game.selectSlot(0); // 執行者の手番(EYEと無関係)
      game.confirmHandoff();

      expect(game.currentPlayer, Faction.savior);
      game.chooseAction(ActionType.eye);
      game.selectSlot(4); // 救済者の2回目のEYE
      expect(game.eyeUsesRemaining(Faction.savior), 0);
      game.confirmHandoff();

      game.chooseAction(ActionType.death);
      game.selectSlot(1); // 執行者の手番(EYEと無関係)
      game.confirmHandoff();

      expect(game.currentPlayer, Faction.savior);
      game.chooseAction(ActionType.eye);
      expect(game.canTarget(5), isFalse);
    });

    test('EYEはスコアを減らさない', () {
      final game = NineJudgesController(seed: 505);
      game.chooseAction(ActionType.eye);
      game.selectSlot(3);
      expect(game.score.savior, 0);
      expect(game.score.executor, 0);
    });

    test('同一プレイヤーは同じ人物へ再EYE不可だが、別プレイヤーは可能', () {
      final game = NineJudgesController(seed: 506);
      game.chooseAction(ActionType.eye);
      game.selectSlot(3); // 救済者が3をEYE
      game.confirmHandoff();

      expect(game.currentPlayer, Faction.executor);
      game.chooseAction(ActionType.eye);
      expect(game.canTarget(3), isTrue); // 別プレイヤーは同じ人物を見られる
      game.selectSlot(3);
      game.confirmHandoff();

      expect(game.currentPlayer, Faction.savior);
      game.chooseAction(ActionType.eye);
      expect(game.canTarget(3), isFalse); // 同一プレイヤーは再EYEできない
    });
  });

  group('rulesVersion 1.2 — canUseActionの直接検証', () {
    PersonCard person() => const PersonCard(
      id: 'p',
      attribute: PersonAttribute.good,
      verdictState: VerdictState.deliberating,
      verdictActionCount: 0,
    );

    test('eyeAllowedForZone=falseならEYE不可', () {
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.eye,
          person: person(),
          actor: Faction.savior,
          actorKnowsAttribute: false,
          specialVerdictUsed: false,
          eyeAllowedForZone: false,
        ),
        isFalse,
      );
    });

    test('eyeUsesRemaining=0ならEYE不可', () {
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.eye,
          person: person(),
          actor: Faction.savior,
          actorKnowsAttribute: false,
          specialVerdictUsed: false,
          eyeUsesRemaining: 0,
        ),
        isFalse,
      );
    });

    test('eyeUsesRemaining=nullなら無制限(v1.1互換)', () {
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.eye,
          person: person(),
          actor: Faction.savior,
          actorKnowsAttribute: false,
          specialVerdictUsed: false,
        ),
        isTrue,
      );
    });
  });

  group('rulesVersion 1.2 — ログ拡張', () {
    test('EYEアクションのログにゾーン・残数・ルールバージョンが記録される', () {
      final game = NineJudgesController(seed: 507);
      game.chooseAction(ActionType.eye);
      game.selectSlot(4);
      final log = game.session.actions.single;
      expect(log.ruleVersion, '1.2');
      expect(log.targetZone, 'center');
      expect(log.eyeUsesRemainingBefore, 2);
      expect(log.eyeUsesRemainingAfter, 1);
      expect(log.eyeEligibleAtTime, isTrue);
      expect(log.eyeAlreadyUsedOnTargetByActor, isFalse);
    });

    test('セッションに開始時の既知位置が記録される', () {
      final game = NineJudgesController(seed: 508);
      expect(
        game.session.initialKnownPositionsBySavior,
        unorderedEquals([6, 7, 8]),
      );
      expect(
        game.session.initialKnownPositionsByExecutor,
        unorderedEquals([0, 1, 2]),
      );
      expect(game.session.experimentalRevokeMode, 'disabled');
    });
  });

  group('rulesVersion 1.2 — CPU/シミュレーション', () {
    test('CPUのEYEは常に中央3人以内、上限2回を超えない', () {
      const config = SimulationConfig(
        gameCount: 150,
        baseSeed: 5000,
        ruleVersion: NineJudgesRuleVersion.v1_2,
      );
      final run = const SimulationRunner().run(config);
      for (final result in run.results) {
        expect(result.saviorEyeCount, lessThanOrEqualTo(2));
        expect(result.executorEyeCount, lessThanOrEqualTo(2));
        for (final action in result.actions) {
          if (action.action == ActionType.eye) {
            expect(
              NineJudgesConfig.centerIndices,
              contains(action.targetIndex),
            );
          }
        }
      }
    });

    test('150戦は正常終了し、全員確定・合計45点・再現性がある', () {
      const config = SimulationConfig(
        gameCount: 150,
        baseSeed: 6000,
        ruleVersion: NineJudgesRuleVersion.v1_2,
      );
      final first = const SimulationRunner().run(config);
      final second = const SimulationRunner().run(config);
      for (final result in first.results) {
        expect(result.finalConfirmedCount, 9);
        expect(result.saviorScore + result.executorScore, 45);
      }
      expect(
        first.results.map((r) => r.toJson()).toList(),
        second.results.map((r) => r.toJson()).toList(),
      );
    });
  });
}
