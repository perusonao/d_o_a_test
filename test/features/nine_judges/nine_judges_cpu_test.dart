import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CPU viewは自分側3枚だけ初期既知で中央・相手側は未知', () {
    final game = NineJudgesController(
      seed: 70,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        cpuFaction: Faction.executor,
        firstPlayer: Faction.executor,
      ),
    );
    final view = game.cpuView();
    expect(
      view.slots.take(3).every((slot) => slot.knownAttribute != null),
      isTrue,
    );
    expect(
      view.slots.skip(3).every((slot) => slot.knownAttribute == null),
      isTrue,
    );
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
        cpuLevel: CpuLevel.balanced,
      ),
    );
    // 執行者(CPU)の手番。共有エンジン経由でスロット5(未知)へEYEを強制し、
    // CPUメッセージ生成が属性を漏らさないことを決定論的に検証する。
    final ok = game.performTutorialAction(ActionType.eye, 5);
    expect(ok, isTrue);
    expect(game.lastCpuActionType, ActionType.eye);
    expect(game.lastCpuActionMessage, isNotNull);
    expect(game.lastCpuActionMessage, isNot(contains('善人')));
    expect(game.lastCpuActionMessage, isNot(contains('悪人')));
    expect(game.lastCpuActionMessage, isNot(contains('中立')));
  });

  test('CPUにも逆LIFEの1回制限が適用される', () {
    final game = NineJudgesController(
      seed: 73,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        cpuFaction: Faction.executor,
        firstPlayer: Faction.executor,
        firstPlayerSelection: FirstPlayerSelection.cpu,
      ),
    );
    expect(game.cpuView().legalTargets[ActionType.life], isNotEmpty);
    game.reverseActionUsed[Faction.executor] = true;
    expect(game.cpuView().legalTargets[ActionType.life], isNull);
  });
}
