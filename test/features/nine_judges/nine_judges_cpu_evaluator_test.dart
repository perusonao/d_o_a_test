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

/// Builds a full 9-slot board (3 good/3 evil/3 neutral, matching the fixed
/// RULES.md composition) split into [knownIndexToAttribute] (slots this CPU
/// already knows, in index order) and everything else left unknown. The
/// unknown slots' real attributes are filled in from whatever is left over
/// (irrelevant to the evaluator, which never reads them) purely so every
/// slot has a valid [PersonCard].
List<CpuSlotView> _board9({
  required Map<int, PersonAttribute> known,
  Map<int, int> verdictActionCounts = const {},
}) {
  final pool = [
    for (var i = 0; i < 3; i++) PersonAttribute.good,
    for (var i = 0; i < 3; i++) PersonAttribute.evil,
    for (var i = 0; i < 3; i++) PersonAttribute.neutral,
  ];
  for (final attr in known.values) {
    pool.remove(attr);
  }
  var poolIndex = 0;
  return [
    for (var i = 0; i < 9; i++)
      () {
        final knownAttr = known[i];
        final realAttr = knownAttr ?? pool[poolIndex++];
        return CpuSlotView(
          index: i,
          person: PersonCard(
            id: 'p$i',
            attribute: realAttr,
            verdictState: VerdictState.deliberating,
            verdictActionCount: verdictActionCounts[i] ?? 0,
          ),
          knownAttribute: knownAttr,
        );
      }(),
  ];
}

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

  group('EYEの情報価値(残り属性の確率分布)', () {
    test('残り属性が均等に近いほどEYEの評価は高くなる', () {
      // ケースA: 既知3枚(善悪中立を1枚ずつ)以外の6枚は善2/悪2/中立2の均等な
      // 三択のまま — 最も不確実。対象(index3)はその6枚の1つ。
      final balanced = _board9(
        known: {
          0: PersonAttribute.good,
          1: PersonAttribute.evil,
          2: PersonAttribute.neutral,
        },
      );
      // ケースB: 悪人・中立をすべて公開済みで、残り3枚(対象含む)は必ず善人と
      // 推測できる — 最も確実(EYEしなくてもほぼ分かる)。
      final determined = _board9(
        known: {
          0: PersonAttribute.evil,
          1: PersonAttribute.evil,
          2: PersonAttribute.evil,
          3: PersonAttribute.neutral,
          4: PersonAttribute.neutral,
          5: PersonAttribute.neutral,
        },
      );

      final balancedScore = CpuEvaluator.actionScore(
        _view(Faction.savior, balanced),
        ActionType.eye,
        balanced[3],
        profile: CpuProfile.balanced,
      );
      final determinedScore = CpuEvaluator.actionScore(
        _view(Faction.savior, determined),
        ActionType.eye,
        determined[6],
        profile: CpuProfile.balanced,
      );

      expect(balancedScore, greaterThan(determinedScore));
    });

    test('対象の隠された実属性そのものは評価に一切影響しない(非公開情報を参照しない)', () {
      final known = {
        0: PersonAttribute.good,
        1: PersonAttribute.evil,
        2: PersonAttribute.neutral,
      };
      // 対象(index3)の実属性だけを差し替えた2つの盤面 — knownAttributeはどちらも
      // nullのまま(CPUには見えない)なので、スコアは完全に一致するはず。
      final withGoodTarget = _board9(known: known);
      final targetIndex = withGoodTarget.indexWhere(
        (s) => s.index == 3 && s.knownAttribute == null,
      );
      final rebuilt = [
        for (final slot in withGoodTarget)
          if (slot.index == 3)
            CpuSlotView(
              index: 3,
              person: PersonCard(
                id: slot.person.id,
                attribute: PersonAttribute.evil, // 実属性だけ変更
                verdictState: slot.person.verdictState,
                verdictActionCount: slot.person.verdictActionCount,
              ),
              knownAttribute: null,
            )
          else
            slot,
      ];
      expect(targetIndex, isNonNegative);

      final scoreA = CpuEvaluator.actionScore(
        _view(Faction.savior, withGoodTarget),
        ActionType.eye,
        withGoodTarget[3],
        profile: CpuProfile.balanced,
      );
      final scoreB = CpuEvaluator.actionScore(
        _view(Faction.savior, rebuilt),
        ActionType.eye,
        rebuilt[3],
        profile: CpuProfile.balanced,
      );
      expect(scoreA, scoreB);
    });

    test('残り使用回数が1回以下だと最後の一手として少し優遇される', () {
      final slots = _board9(
        known: {
          0: PersonAttribute.good,
          1: PersonAttribute.evil,
          2: PersonAttribute.neutral,
        },
      );
      final view = CpuGameView(
        faction: Faction.savior,
        slots: slots,
        legalTargets: const {},
        currentBonus: 5,
        specialVerdictAvailable: true,
        eyeUsesRemaining: 1,
      );
      final viewNoUrgency = CpuGameView(
        faction: Faction.savior,
        slots: slots,
        legalTargets: const {},
        currentBonus: 5,
        specialVerdictAvailable: true,
        eyeUsesRemaining: 2,
      );
      final urgent = CpuEvaluator.actionScore(
        view,
        ActionType.eye,
        slots[3],
        profile: CpuProfile.balanced,
      );
      final relaxed = CpuEvaluator.actionScore(
        viewNoUrgency,
        ActionType.eye,
        slots[3],
        profile: CpuProfile.balanced,
      );
      expect(urgent, greaterThan(relaxed));
    });
  });

  group('終盤補正(残り確定数が少ないほど確定・JUDGEの評価を上げる)', () {
    test('確定を伴うLIFE/DEATHは残り確定数が少ないほど高評価になる', () {
      // 対象以外の全員が確定済み(残り確定数=1) vs 誰も確定していない(残り確定数=9)。
      final target = _slot(
        0,
        PersonAttribute.good,
        state: VerdictState.dead,
        count: 1,
      );
      final confirmedOther = PersonCard(
        id: 'confirmed',
        attribute: PersonAttribute.neutral,
        verdictState: VerdictState.aliveConfirmed,
      );
      final lateGame = _view(Faction.executor, [
        target,
        for (var i = 1; i < 9; i++)
          CpuSlotView(index: i, person: confirmedOther, knownAttribute: PersonAttribute.neutral),
      ], bonus: 9);
      final earlyGame = _view(Faction.executor, [
        target,
        for (var i = 1; i < 9; i++)
          _slot(i, PersonAttribute.neutral),
      ], bonus: 9);

      final lateScore = CpuEvaluator.actionScore(
        lateGame,
        ActionType.death,
        target,
        profile: CpuProfile.balanced,
      );
      final earlyScore = CpuEvaluator.actionScore(
        earlyGame,
        ActionType.death,
        target,
        profile: CpuProfile.balanced,
      );
      expect(lateScore, greaterThan(earlyScore));
    });

    test('JUDGEも残り確定数が少ないほど高評価になり、温存し続けにくくなる', () {
      final target = _slot(0, PersonAttribute.good);
      final confirmedOther = PersonCard(
        id: 'confirmed',
        attribute: PersonAttribute.neutral,
        verdictState: VerdictState.aliveConfirmed,
      );
      final lateGame = _view(Faction.savior, [
        target,
        for (var i = 1; i < 9; i++)
          CpuSlotView(index: i, person: confirmedOther, knownAttribute: PersonAttribute.neutral),
      ], bonus: 5);
      final earlyGame = _view(Faction.savior, [
        target,
        for (var i = 1; i < 9; i++)
          _slot(i, PersonAttribute.neutral),
      ], bonus: 5);

      final lateScore = CpuEvaluator.actionScore(
        lateGame,
        ActionType.specialVerdict,
        target,
        profile: CpuProfile.balanced,
      );
      final earlyScore = CpuEvaluator.actionScore(
        earlyGame,
        ActionType.specialVerdict,
        target,
        profile: CpuProfile.balanced,
      );
      expect(lateScore, greaterThan(earlyScore));
    });
  });

  group('評価理由(reasons)の内訳', () {
    test('確定を伴う手にはlockBonus、EYEにはinfoValueという理由が含まれる', () {
      final slot = _slot(
        0,
        PersonAttribute.good,
        state: VerdictState.dead,
        count: 1,
      );
      final lockResult = CpuEvaluator.actionScoreDetailed(
        _view(Faction.executor, [slot], bonus: 9),
        ActionType.death,
        slot,
        profile: CpuProfile.balanced,
      );
      expect(lockResult.reasons, isNotEmpty);
      expect(lockResult.reasons.map((r) => r.key), contains('lockBonus'));

      final eyeSlot = _slot(1, PersonAttribute.good, known: false);
      final eyeResult = CpuEvaluator.actionScoreDetailed(
        _view(Faction.savior, [eyeSlot]),
        ActionType.eye,
        eyeSlot,
        profile: CpuProfile.balanced,
      );
      expect(eyeResult.reasons, isNotEmpty);
      expect(eyeResult.reasons.map((r) => r.key), contains('infoValue'));
    });
  });
}
