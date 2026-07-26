import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CPU viewは未知属性を公開しない', () {
    final game = NineJudgesController(
      seed: 70,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        cpuFaction: Faction.executor,
        firstPlayer: Faction.executor,
      ),
    );
    final view = game.cpuView();
    expect(view.slots.every((slot) => slot.knownAttribute == null), isTrue);
  });

  test('CPUは合法な通常行動を1つ実行する', () {
    final game = NineJudgesController(
      seed: 71,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        cpuFaction: Faction.executor,
        firstPlayer: Faction.executor,
        firstPlayerSelection: FirstPlayerSelection.cpu,
        skipCpuDelays: true,
      ),
    );
    final decision = game.performCpuAction();
    expect(decision, isNotNull);
    expect(decision!.action, isNot(ActionType.life));
    expect(game.turn, 2);
  });

  test('CPU EYE結果は公開メッセージへ漏れない', () {
    final game = NineJudgesController(
      seed: 72,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        cpuFaction: Faction.executor,
        firstPlayer: Faction.executor,
        firstPlayerSelection: FirstPlayerSelection.cpu,
        cpuLevel: CpuLevel.basic,
      ),
    );
    final decision = game.performCpuAction();
    expect(decision!.action, ActionType.eye);
    expect(game.lastCpuActionMessage, isNotNull);
    expect(game.lastCpuActionMessage, isNot(contains('善人')));
    expect(game.lastCpuActionMessage, isNot(contains('悪人')));
    expect(game.lastCpuActionMessage, isNot(contains('中立')));
  });
}
