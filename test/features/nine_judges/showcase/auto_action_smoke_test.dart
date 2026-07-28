import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// [NineJudgesController.performAutoAction] exists only for the hidden
/// showcase/demo screen (see features/nine_judges/showcase/), which needs to
/// drive a full, deterministic CPU-vs-CPU match to completion for recording.
/// This locks in that it actually terminates and confirms all 9 people
/// across a range of fixed seeds, without touching any real rule/CPU logic.
void main() {
  group('performAutoAction (showcase-only auto-play)', () {
    for (final seed in [1, 42, 12345, 999, 7]) {
      test('seed=$seed: 決定的に最後まで進行し9人全員が確定する', () {
        final controller = NineJudgesController(
          seed: seed,
          settings: const NineJudgesGameSettings(
            mode: GameMode.cpu,
            skipCpuDelays: true,
          ),
        );
        var iterations = 0;
        while (!controller.isFinished && iterations < 500) {
          iterations++;
          if (controller.awaitingConfirmationReveal) {
            controller.confirmConfirmationReveal();
            continue;
          }
          final decision = controller.performAutoAction();
          if (decision == null) break;
        }
        expect(controller.isFinished, isTrue);
        expect(controller.confirmedCount, 9);
        expect(controller.session.actions, isNotEmpty);
      });
    }

    test('通常のperformCpuAction()の挙動には影響しない(settings.cpuFactionのみ動く)', () {
      final controller = NineJudgesController(
        seed: 1,
        settings: const NineJudgesGameSettings(
          mode: GameMode.cpu,
          cpuFaction: Faction.executor,
          skipCpuDelays: true,
        ),
      );
      // It's savior's turn first (default firstPlayer). performCpuAction()
      // must still refuse to act for the non-CPU faction, exactly as before
      // this change.
      expect(controller.currentPlayer, Faction.savior);
      expect(controller.performCpuAction(), isNull);
    });
  });
}
