import 'package:dead_or_alive/features/nine_judges/cpu/cpu_evaluator.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

CpuSlotView _slot(
  int index,
  PersonAttribute attribute, {
  VerdictState state = VerdictState.deliberating,
  int count = 0,
  bool known = true,
}) => CpuSlotView(
  index: index,
  person: PersonCard(
    id: 'p$index',
    attribute: attribute,
    verdictState: state,
    verdictActionCount: count,
  ),
  knownAttribute: known ? attribute : null,
);

CpuGameView _view(Faction faction, List<CpuSlotView> slots, {int bonus = 5}) =>
    CpuGameView(
      faction: faction,
      slots: slots,
      legalTargets: const {},
      currentBonus: bonus,
      specialVerdictAvailable: true,
    );

void main() {
  test('scorerForは陣営の得点条件と一致する', () {
    expect(
      CpuEvaluator.scorerFor(PersonAttribute.good, alive: true),
      Faction.savior,
    );
    expect(
      CpuEvaluator.scorerFor(PersonAttribute.neutral, alive: false),
      Faction.executor,
    );
    expect(
      CpuEvaluator.scorerFor(PersonAttribute.evil, alive: true),
      Faction.executor,
    );
    expect(
      CpuEvaluator.scorerFor(PersonAttribute.evil, alive: false),
      Faction.savior,
    );
  });

  test('自分が得点する確定は高く評価される', () {
    // 執行者: 既に「死」の善人へDEATHで死亡確定 → 善人死は執行者得点。
    final slot = _slot(
      0,
      PersonAttribute.good,
      state: VerdictState.dead,
      count: 1,
    );
    final score = CpuEvaluator.actionScore(
      _view(Faction.executor, [slot], bonus: 9),
      ActionType.death,
      slot,
      profile: CpuProfile.balanced,
    );
    expect(score, greaterThan(CpuProfile.balanced.eyeValue));
    expect(score, greaterThan(12));
  });

  test('相手へ得点させる確定は強く忌避される', () {
    // 執行者: 既に「死」の悪人へDEATHで死亡確定 → 悪人死は救済者得点。
    final slot = _slot(
      0,
      PersonAttribute.evil,
      state: VerdictState.dead,
      count: 1,
    );
    final score = CpuEvaluator.actionScore(
      _view(Faction.executor, [slot], bonus: 9),
      ActionType.death,
      slot,
      profile: CpuProfile.balanced,
    );
    expect(score, lessThan(0));
  });

  test('審判(JUDGE)は自分得点なら評価し、相手得点なら-100', () {
    final good = _slot(0, PersonAttribute.good);
    final evil = _slot(1, PersonAttribute.evil);
    final view = _view(Faction.executor, [good, evil], bonus: 9);
    // 執行者JUDGE → 死亡確定。善人死=執行者得点、悪人死=救済者得点。
    expect(
      CpuEvaluator.actionScore(
        view,
        ActionType.specialVerdict,
        good,
        profile: CpuProfile.balanced,
      ),
      greaterThan(10),
    );
    expect(
      CpuEvaluator.actionScore(
        view,
        ActionType.specialVerdict,
        evil,
        profile: CpuProfile.balanced,
      ),
      lessThan(-50),
    );
  });

  test('逆転アクションは悪人を仕留める決め手として高評価', () {
    // 救済者は本来LIFEのみ。逆転DEATHで既に「死」の悪人を死亡確定 → 救済者得点。
    final slot = _slot(
      0,
      PersonAttribute.evil,
      state: VerdictState.dead,
      count: 1,
    );
    final score = CpuEvaluator.actionScore(
      _view(Faction.savior, [slot], bonus: 9),
      ActionType.death,
      slot,
      profile: CpuProfile.balanced,
    );
    expect(score, greaterThan(12));
  });

  test('opponentThreatは相手の即時得点を検出する', () {
    // 救済者視点: 善人が「死」count2 → 執行者のDEATHで死亡確定=執行者得点。
    final slots = [
      _slot(0, PersonAttribute.good, state: VerdictState.dead, count: 2),
    ];
    final threat = CpuEvaluator.opponentThreat(slots, Faction.savior, 7);
    expect(threat, 7);
    // 未知の人物は脅威判定から除外される。
    final hidden = [
      _slot(
        0,
        PersonAttribute.good,
        state: VerdictState.dead,
        count: 2,
        known: false,
      ),
    ];
    expect(CpuEvaluator.opponentThreat(hidden, Faction.savior, 7), 0);
  });
}
