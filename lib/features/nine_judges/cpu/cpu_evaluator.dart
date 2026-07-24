import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class CpuEvaluator {
  static double estimatedNumberValue(CpuGameView view, CpuSlotView slot) {
    if (slot.knownNumber case final value?) return value.toDouble();
    if (view.unknownNumberCandidates.isEmpty) return 5;
    return view.unknownNumberCandidates.reduce((a, b) => a + b) /
        view.unknownNumberCandidates.length;
  }

  static double personValue(CpuGameView view, CpuSlotView slot) =>
      slot.person.rank + estimatedNumberValue(view, slot);

  static bool prefersAlive(Faction faction, PersonAttribute attribute) {
    final saviorPrefersAlive =
        attribute == PersonAttribute.good ||
        attribute == PersonAttribute.neutral;
    return faction == Faction.savior ? saviorPrefersAlive : !saviorPrefersAlive;
  }

  static bool currentStateIsFavorable(Faction faction, PersonCard person) =>
      person.isAlive == prefersAlive(faction, person.attribute);

  static double actionScore(
    CpuGameView view,
    ActionType action,
    CpuSlotView slot,
  ) {
    final person = slot.person;
    final value = personValue(view, slot);
    final favorable = currentStateIsFavorable(view.faction, person);
    return switch (action) {
      ActionType.life when !person.isAlive =>
        prefersAlive(view.faction, person.attribute) ? 12 + value : 1,
      ActionType.life => favorable ? 6 + value : 0.5,
      ActionType.death when !person.isAlive => favorable ? 14 + value : 1,
      ActionType.death when person.hasLifeShield => !favorable ? 5 + value : 1,
      ActionType.death =>
        !prefersAlive(view.faction, person.attribute) ? 11 + value : 0.5,
      ActionType.eye =>
        value +
            person.rank +
            (person.rank == 3 ? 2 : 0) +
            (!person.isJudged ? 1 : 0) -
            (view.inventory.eye <= 1 ? 2 : 0),
    };
  }

  static double judgeScore(CpuGameView view, CpuSlotView slot) {
    final value = personValue(view, slot);
    return currentStateIsFavorable(view.faction, slot.person)
        ? 20 + value
        : -value;
  }
}
