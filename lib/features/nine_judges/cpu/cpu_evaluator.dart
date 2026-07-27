import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

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

  /// Immediate, rules-accurate value of [action] against [slot] for the CPU.
  static double actionScore(
    CpuGameView view,
    ActionType action,
    CpuSlotView slot, {
    CpuProfile profile = CpuProfile.balanced,
  }) {
    final bonus = (view.currentBonus ?? 5).toDouble();
    return switch (action) {
      ActionType.eye => profile.eyeValue,
      ActionType.specialVerdict => _judgeScore(view, slot, bonus, profile),
      ActionType.life ||
      ActionType.death => _verdictScore(view, action, slot, bonus, profile),
    };
  }

  static double _verdictScore(
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
      return profile.blindValue - (reverse ? profile.reverseCost : 0);
    }
    final after = NineJudgesRules.applyVerdictAction(
      person: slot.person,
      action: action,
      actor: view.faction,
    );
    if (after.isConfirmed) {
      final scorer = NineJudgesRules.scoringFaction(after);
      if (scorer != view.faction) return -bonus - profile.giveawayPenalty;
      var value = bonus * profile.bonusWeight + profile.lockBonus;
      // The reverse action is often the only tool to lock this attribute
      // (a savior can only score a revealed evil by killing it), so the
      // payoff outweighs the one-shot cost when it actually confirms.
      if (reverse) value += profile.reverseKeyValue - profile.reverseCost;
      return value;
    }
    // Non-confirming move: is it progress toward a point that scores for us?
    final dirScorer = scorerFor(attr, alive: action == ActionType.life);
    if (dirScorer != view.faction) {
      // Pushing a known person toward the opponent's point; only a denial.
      return -profile.progressValue - (reverse ? profile.reverseCost : 0);
    }
    var value =
        profile.progressValue +
        bonus * 0.2 * profile.bonusWeight +
        profile.setupBonus;
    // Spending the one-shot reverse merely to progress (leaving the person
    // flippable) is worth far less than using it to finish.
    if (reverse) value += profile.reverseKeyValue * 0.4 - profile.reverseCost;
    return value;
  }

  static double _judgeScore(
    CpuGameView view,
    CpuSlotView slot,
    double bonus,
    CpuProfile profile,
  ) {
    final attr = slot.knownAttribute;
    if (attr == null) return 1; // never burn the one-shot on an unknown.
    final finalAlive = view.faction == Faction.savior;
    final scorer = scorerFor(attr, alive: finalAlive);
    if (scorer != view.faction) return -100; // would hand the point away.
    // JUDGE confirms an untouched person in a single move; hold it for a
    // worthwhile bonus unless the personality is impatient.
    final premium = bonus >= profile.judgeMinBonus
        ? profile.judgePremium
        : profile.judgePremium - 4;
    return bonus * profile.bonusWeight + premium;
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
