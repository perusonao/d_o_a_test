import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class CpuEvaluator {
  static bool prefersAlive(Faction faction, PersonAttribute attribute) {
    final saviorPrefersAlive =
        attribute == PersonAttribute.good ||
        attribute == PersonAttribute.neutral;
    return faction == Faction.savior ? saviorPrefersAlive : !saviorPrefersAlive;
  }

  static double actionScore(
    CpuGameView view,
    ActionType action,
    CpuSlotView slot,
  ) {
    final known = slot.knownAttribute;
    final wantsAlive = known == null ? null : prefersAlive(view.faction, known);
    final bonus = (view.currentBonus ?? 5).toDouble();
    final base = switch (action) {
      ActionType.eye => known == null ? 12 : -100,
      ActionType.specialVerdict =>
        wantsAlive == null
            ? 2
            : wantsAlive == (view.faction == Faction.savior)
            ? 8 + bonus
            : -5,
      ActionType.life =>
        wantsAlive == null
            ? 4
            : wantsAlive
            ? 7 + bonus / 2
            : 1,
      ActionType.death =>
        wantsAlive == null
            ? 4
            : !wantsAlive
            ? 7 + bonus / 2
            : 1,
    };
    final reverse =
        (view.faction == Faction.savior && action == ActionType.death) ||
        (view.faction == Faction.executor && action == ActionType.life);
    if (!reverse) return base.toDouble();
    final nearConfirmation = slot.person.verdictActionCount >= 1;
    final tacticalPremium = known != null && nearConfirmation && bonus >= 6
        ? 3.0
        : 0.0;
    return base.toDouble() - 3 + tacticalPremium;
  }
}
