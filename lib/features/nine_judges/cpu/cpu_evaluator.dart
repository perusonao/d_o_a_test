import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class CpuEvaluator {
  static double personValue(CpuGameView view, CpuSlotView slot) =>
      slot.person.rank.toDouble();

  static bool prefersAlive(Faction faction, PersonAttribute attribute) {
    final saviorPrefersAlive =
        attribute == PersonAttribute.good ||
        attribute == PersonAttribute.neutral;
    return faction == Faction.savior ? saviorPrefersAlive : !saviorPrefersAlive;
  }

  static bool currentStateIsFavorable(Faction faction, PersonCard person) =>
      person.isAlive == prefersAlive(faction, person.attribute);

  static bool? knownStateIsFavorable(Faction faction, CpuSlotView slot) {
    final attribute = slot.knownAttribute;
    if (attribute == null) return null;
    return slot.person.isAlive == prefersAlive(faction, attribute);
  }

  static EyeInformation preferredEyeInformation(CpuSlotView slot) =>
      EyeInformation.attribute;

  static double actionScore(
    CpuGameView view,
    ActionType action,
    CpuSlotView slot,
  ) {
    final person = slot.person;
    final value = personValue(view, slot);
    final favorable = knownStateIsFavorable(view.faction, slot);
    return switch (action) {
      ActionType.life when !person.isAlive =>
        slot.knownAttribute == null
            ? 5 + value / 2
            : prefersAlive(view.faction, slot.knownAttribute!)
            ? 12 + value
            : 1,
      ActionType.life => favorable == true ? 6 + value : 1,
      ActionType.death when !person.isAlive =>
        favorable == true ? 14 + value : 2,
      ActionType.death when person.hasLifeShield =>
        favorable == false ? 5 + value : 1,
      ActionType.death =>
        slot.knownAttribute == null
            ? 5 + value / 2
            : !prefersAlive(view.faction, slot.knownAttribute!)
            ? 11 + value
            : 0.5,
      ActionType.eye =>
        (slot.eyeOptions.contains(EyeInformation.attribute) ? 15 : -100) +
            value -
            (view.inventory.eye <= 1 ? 1 : 0),
      ActionType.judge =>
        favorable == true
            ? 10 +
                  value * 3 +
                  (person.isAlive
                      ? view.opponentInventory.death * 1.5
                      : view.opponentInventory.life * 1.5) -
                  (view.inventory.judge <= 1 ? (4 - person.rank) * 3 : 0)
            : favorable == null
            ? -2
            : -value,
    };
  }

  static double judgeScore(CpuGameView view, CpuSlotView slot) {
    final value = personValue(view, slot);
    return knownStateIsFavorable(view.faction, slot) == true
        ? 20 + value
        : -value;
  }
}
