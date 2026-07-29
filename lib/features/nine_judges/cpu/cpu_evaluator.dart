import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

/// A candidate's score plus the labelled contributions that produced it
/// (see [CpuScoreReason]) — used for logging/debugging only, never for
/// gameplay.
typedef CpuScoredAction = ({double score, List<CpuScoreReason> reasons});

/// Tunable weights that define a CPU thinking pattern.
///
/// All values are expressed on the same scale as the verdict bonus (1..9) so
/// that "locking a point now" and "scouting an unknown" can be compared
/// directly. Personalities are just different weightings of the same,
/// rules-accurate evaluation.
class CpuProfile {
  const CpuProfile({
    required this.eyeValue,
    required this.lockBonus,
    required this.giveawayPenalty,
    required this.progressValue,
    required this.setupBonus,
    required this.bonusWeight,
    required this.judgePremium,
    required this.judgeMinBonus,
    required this.reverseCost,
    required this.reverseKeyValue,
    required this.blindValue,
    required this.threatWeight,
    required this.jitter,
    this.selectionWeights = const [1],
  });

  /// Value of revealing an unknown attribute with EYE.
  final double eyeValue;

  /// Reward added on top of the bonus for an action that CONFIRMS a person who
  /// scores for us (points become locked and immune to the opponent).
  final double lockBonus;

  /// Magnitude subtracted when a move would confirm a person for the OPPONENT.
  final double giveawayPenalty;

  /// Value of a non-confirming move that pushes a known person toward a state
  /// that will eventually score for us.
  final double progressValue;

  /// Extra value when a progress move leaves the person one step from a
  /// same-state confirmation on our next turn.
  final double setupBonus;

  /// Multiplier applied to the current bonus for confirmations.
  final double bonusWeight;

  /// Premium for spending the one-shot JUDGE on a favourable known target.
  final double judgePremium;

  /// Only spend JUDGE eagerly once the bonus reaches this value.
  final double judgeMinBonus;

  /// Fixed cost of spending the one-shot reverse action.
  final double reverseCost;

  /// Value added back when the reverse action is the correct tool for a known
  /// target (e.g. a savior killing a revealed evil).
  final double reverseKeyValue;

  /// Value of a blind verdict on a still-unknown person.
  final double blindValue;

  /// Weight of the one-ply opponent-threat lookahead (0 disables it).
  final double threatWeight;

  /// Random spread used to break ties between near-equal moves.
  final double jitter;

  /// Difficulty-tiered choice variance (spec sections 14/15): probability of
  /// picking the 1st/2nd/3rd/... ranked candidate (by score, best first)
  /// instead of always taking the literal top score. `[1]` (the default,
  /// and every current profile's value) always takes the best. Values need
  /// not sum to 1 — any leftover probability mass falls back to the top
  /// candidate.
  ///
  /// An earlier tuning gave [balanced] only a 45% chance of taking the top
  /// move specifically to manufacture a difficulty gradient, but cross-play
  /// testing against the pre-evaluator-rewrite CPU showed that any amount of
  /// this variance costs real win rate against a deterministic opponent —
  /// every profile now takes the literal top move every time, matching the
  /// old CPU's selection behaviour, so the evaluator's own scoring quality
  /// is what has to carry both strength and any future difficulty spread.
  /// The mechanism is kept (rather than removed) since it's tested and the
  /// spec explicitly asks for it as a future difficulty-tuning knob — see
  /// [strengthLabel]-ordered tiers in [CpuLevel] for the current, purely
  /// weight-driven difficulty ladder.
  final List<double> selectionWeights;

  static const balanced = CpuProfile(
    eyeValue: 6.5,
    lockBonus: 5,
    giveawayPenalty: 6,
    progressValue: 3.5,
    setupBonus: 0.5,
    bonusWeight: 1,
    judgePremium: 4,
    judgeMinBonus: 6,
    reverseCost: 3,
    reverseKeyValue: 6,
    blindValue: 2,
    threatWeight: 0,
    jitter: 0.3,
    selectionWeights: [1],
  );

  static const aggressive = CpuProfile(
    eyeValue: 4.5,
    lockBonus: 6,
    giveawayPenalty: 6,
    progressValue: 4.5,
    setupBonus: 1,
    bonusWeight: 1.2,
    judgePremium: 6,
    judgeMinBonus: 4,
    reverseCost: 1.5,
    reverseKeyValue: 7,
    blindValue: 3,
    threatWeight: 0,
    jitter: 0.4,
    selectionWeights: [1],
  );

  static const defensive = CpuProfile(
    eyeValue: 8,
    lockBonus: 5,
    giveawayPenalty: 9,
    progressValue: 2.5,
    setupBonus: 0.5,
    bonusWeight: 1,
    judgePremium: 3,
    judgeMinBonus: 7,
    reverseCost: 4.5,
    reverseKeyValue: 6,
    blindValue: 1,
    threatWeight: 0.6,
    jitter: 0.3,
    selectionWeights: [1],
  );

  static const expert = CpuProfile(
    eyeValue: 6.5,
    lockBonus: 5,
    giveawayPenalty: 8,
    progressValue: 3.5,
    setupBonus: 1,
    bonusWeight: 1.1,
    judgePremium: 5,
    judgeMinBonus: 6,
    reverseCost: 3,
    reverseKeyValue: 6.5,
    blindValue: 1.5,
    threatWeight: 0.9,
    jitter: 0.15,
    selectionWeights: [1],
  );
}

abstract final class CpuEvaluator {
  /// The faction that scores if [attribute] finishes alive/dead.
  ///
  /// Mirrors [NineJudgesRules.scoringFaction] but works on a hypothetical
  /// outcome so we can reason about a move before committing it.
  static Faction scorerFor(PersonAttribute attribute, {required bool alive}) {
    final saviorScores =
        (attribute != PersonAttribute.evil && alive) ||
        (attribute == PersonAttribute.evil && !alive);
    return saviorScores ? Faction.savior : Faction.executor;
  }

  static bool isReverseAction(Faction faction, ActionType action) =>
      (faction == Faction.savior && action == ActionType.death) ||
      (faction == Faction.executor && action == ActionType.life);

  /// Every slot not yet confirmed — used to scale weights up as the game
  /// nears its end (section 13).
  static int remainingUnconfirmedCount(List<CpuSlotView> slots) =>
      slots.where((s) => !s.person.isConfirmed).length;

  /// How many of each attribute remain among slots this CPU cannot yet
  /// identify (neither publicly confirmed nor personally seen) — the fixed
  /// 3 good / 3 evil / 3 neutral composition (see RULES.md) minus every
  /// attribute already visible to THIS faction via [CpuSlotView.knownAttribute].
  /// Never reads a slot's real (hidden) attribute directly; only counts what
  /// this CPU could legitimately already know (section 8).
  static Map<PersonAttribute, int> residualAttributeCounts(
    List<CpuSlotView> slots,
  ) {
    final totals = {
      PersonAttribute.good: 3,
      PersonAttribute.evil: 3,
      PersonAttribute.neutral: 3,
    };
    for (final slot in slots) {
      final known = slot.knownAttribute;
      if (known != null) totals[known] = totals[known]! - 1;
    }
    return totals;
  }

  /// Immediate, rules-accurate value of [action] against [slot] for the CPU.
  /// Kept as a `double`-returning wrapper over [actionScoreDetailed] for
  /// existing callers/tests; production code uses the detailed form to get
  /// the reasons breakdown too.
  static double actionScore(
    CpuGameView view,
    ActionType action,
    CpuSlotView slot, {
    CpuProfile profile = CpuProfile.balanced,
  }) => actionScoreDetailed(view, action, slot, profile: profile).score;

  static CpuScoredAction actionScoreDetailed(
    CpuGameView view,
    ActionType action,
    CpuSlotView slot, {
    CpuProfile profile = CpuProfile.balanced,
  }) {
    final bonus = (view.currentBonus ?? 5).toDouble();
    return switch (action) {
      ActionType.eye => _eyeScore(view, slot, profile),
      ActionType.specialVerdict => _judgeScoreDetailed(view, slot, bonus, profile),
      ActionType.life ||
      ActionType.death => _verdictScoreDetailed(view, action, slot, bonus, profile),
    };
  }

  /// rulesVersion 1.2: with only a handful of EYE uses allowed all game,
  /// spending the very last one is slightly favoured over other options of
  /// similar value, since — unlike v1.1 — there is no "look later instead"
  /// option once it's gone.
  static double _eyeUrgency(int? remaining) =>
      remaining != null && remaining <= 1 ? 1.0 : 0.0;

  /// Section 7/8: EYE's value scales with how uncertain the target's
  /// identity still is, estimated only from [residualAttributeCounts] — a
  /// target is worth less to scout once the remaining pool makes its
  /// attribute nearly obvious (e.g. only one attribute left among the
  /// unknowns), and worth more while the pool is still close to an even
  /// three-way split. Also nudged up slightly for the very last EYE use
  /// available.
  static CpuScoredAction _eyeScore(
    CpuGameView view,
    CpuSlotView slot,
    CpuProfile profile,
  ) {
    final residual = residualAttributeCounts(view.slots);
    final unknownCount = residual.values.fold<int>(0, (a, b) => a + b);
    final maxShare = unknownCount == 0
        ? 1.0
        : residual.values.reduce((a, b) => a > b ? a : b) / unknownCount;
    // maxShare ranges from 1/3 (perfectly even split — most uncertain) to 1
    // (only one attribute possible — already fully determined).
    final uncertainty = unknownCount == 0
        ? 0.0
        : (1.0 - (maxShare - 1 / 3) / (2 / 3)).clamp(0.0, 1.0);
    // Kept close to the old flat multiplier (1.0) at the midpoint — a wider
    // swing measured out weaker than the pre-rewrite flat valuation in
    // cross-play testing — so only a target whose attribute is already
    // close to fully determined scores meaningfully below that baseline.
    final uncertaintyFactor = 0.9 + 0.3 * uncertainty; // in [0.9, 1.2]
    final infoValue = profile.eyeValue * uncertaintyFactor;
    final lastUseValue = _eyeUrgency(view.eyeUsesRemaining);
    return (
      score: infoValue + lastUseValue,
      reasons: [
        CpuScoreReason('infoValue', infoValue),
        if (lastUseValue > 0) CpuScoreReason('lastEyeUse', lastUseValue),
      ],
    );
  }

  /// Section 13: scales confirmation/JUDGE weights up as fewer people
  /// remain undecided, so the CPU doesn't drift passively into the endgame.
  static double _endgameMultiplier(int remainingUnconfirmed) =>
      switch (remainingUnconfirmed) {
        <= 2 => 1.5,
        <= 4 => 1.2,
        _ => 1.0,
      };

  static CpuScoredAction _verdictScoreDetailed(
    CpuGameView view,
    ActionType action,
    CpuSlotView slot,
    double bonus,
    CpuProfile profile,
  ) {
    final attr = slot.knownAttribute;
    final reverse = isReverseAction(view.faction, action);
    if (attr == null) {
      // Acting on someone we have not identified is a gamble.
      final reverseCost = reverse ? -profile.reverseCost : 0.0;
      return (
        score: profile.blindValue + reverseCost,
        reasons: [
          CpuScoreReason('blindGamble', profile.blindValue),
          if (reverse) CpuScoreReason('reverseCost', reverseCost),
        ],
      );
    }
    final after = NineJudgesRules.applyVerdictAction(
      person: slot.person,
      action: action,
      actor: view.faction,
    );
    final endgameMult = _endgameMultiplier(
      remainingUnconfirmedCount(view.slots),
    );
    if (after.isConfirmed) {
      final scorer = NineJudgesRules.scoringFaction(after);
      if (scorer != view.faction) {
        final penalty = -bonus - profile.giveawayPenalty;
        return (score: penalty, reasons: [CpuScoreReason('giveaway', penalty)]);
      }
      final baseLock = bonus * profile.bonusWeight + profile.lockBonus;
      final lockValue = baseLock * endgameMult;
      final reasons = [CpuScoreReason('lockBonus', baseLock)];
      if (endgameMult > 1) {
        reasons.add(CpuScoreReason('endgameBoost', lockValue - baseLock));
      }
      var value = lockValue;
      // The reverse action is often the only tool to lock this attribute
      // (a savior can only score a revealed evil by killing it), so the
      // payoff outweighs the one-shot cost when it actually confirms.
      if (reverse) {
        final reverseNet = profile.reverseKeyValue - profile.reverseCost;
        value += reverseNet;
        reasons.add(CpuScoreReason('reverseKey', reverseNet));
      }
      return (score: value, reasons: reasons);
    }
    // Non-confirming move: is it progress toward a point that scores for us?
    final dirScorer = scorerFor(attr, alive: action == ActionType.life);
    if (dirScorer != view.faction) {
      // Pushing a known person toward the opponent's point; only a denial.
      final denial = -profile.progressValue - (reverse ? profile.reverseCost : 0);
      return (score: denial, reasons: [CpuScoreReason('denyOpponent', denial)]);
    }
    final progressValue =
        profile.progressValue + bonus * 0.2 * profile.bonusWeight + profile.setupBonus;
    var value = progressValue;
    final reasons = [CpuScoreReason('progress', progressValue)];
    // Spending the one-shot reverse merely to progress (leaving the person
    // flippable) is worth far less than using it to finish.
    if (reverse) {
      final reverseNet = profile.reverseKeyValue * 0.4 - profile.reverseCost;
      value += reverseNet;
      reasons.add(CpuScoreReason('reverseProgress', reverseNet));
    }
    return (score: value, reasons: reasons);
  }

  static CpuScoredAction _judgeScoreDetailed(
    CpuGameView view,
    CpuSlotView slot,
    double bonus,
    CpuProfile profile,
  ) {
    final attr = slot.knownAttribute;
    if (attr == null) {
      // Never burn the one-shot on an unknown.
      return (score: 1, reasons: const [CpuScoreReason('unknownTarget', 1)]);
    }
    final finalAlive = view.faction == Faction.savior;
    final scorer = scorerFor(attr, alive: finalAlive);
    if (scorer != view.faction) {
      // Would hand the point away.
      return (score: -100, reasons: const [CpuScoreReason('wouldGiveAway', -100)]);
    }
    // JUDGE confirms an untouched person in a single move; hold it for a
    // worthwhile bonus unless the personality is impatient — or unless the
    // game is running out of people to spend it on (section 10: don't let
    // it sit unused as the board empties out).
    final remaining = remainingUnconfirmedCount(view.slots);
    final endgamePush = remaining <= 4 ? (4 - remaining).clamp(0, 4) * 1.5 : 0.0;
    final basePremium = bonus >= profile.judgeMinBonus
        ? profile.judgePremium
        : profile.judgePremium - 4;
    final bonusValue = bonus * profile.bonusWeight;
    return (
      score: bonusValue + basePremium + endgamePush,
      reasons: [
        CpuScoreReason('bonusValue', bonusValue),
        CpuScoreReason('judgePremium', basePremium),
        if (endgamePush > 0) CpuScoreReason('endgameUrgency', endgamePush),
      ],
    );
  }

  /// Largest point the opponent could lock on their very next turn, restricted
  /// to people whose attribute the CPU can see. Used by the expert lookahead.
  static double opponentThreat(
    List<CpuSlotView> slots,
    Faction cpu,
    double bonus,
  ) {
    final opponent = cpu.opponent;
    var worst = 0.0;
    for (final slot in slots) {
      final attr = slot.knownAttribute;
      if (attr == null || slot.person.isConfirmed) continue;
      for (final action in const [ActionType.life, ActionType.death]) {
        final after = NineJudgesRules.applyVerdictAction(
          person: slot.person,
          action: action,
          actor: opponent,
        );
        if (after.isConfirmed &&
            NineJudgesRules.scoringFaction(after) == opponent) {
          if (bonus > worst) worst = bonus;
        }
      }
    }
    return worst;
  }
}
