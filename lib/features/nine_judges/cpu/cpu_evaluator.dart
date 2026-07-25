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

  static bool? knownStateIsFavorable(Faction faction, CpuSlotView slot) {
    final attribute = slot.knownAttribute;
    if (attribute == null) return null;
    return slot.person.isAlive == prefersAlive(faction, attribute);
  }

  static EyeInformation preferredEyeInformation(CpuSlotView slot) =>
      slot.eyeOptions.contains(EyeInformation.attribute)
      ? EyeInformation.attribute
      : EyeInformation.number;

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
        (slot.eyeOptions.contains(EyeInformation.attribute) ? 18 : 0) +
            value +
            person.rank +
            (person.rank == 3 ? 2 : 0) +
            (!person.isJudged ? 1 : 0) -
            (view.inventory.eye <= 1 ? 2 : 0),
      ActionType.judge =>
        favorable == true
            ? 20 + value
            : favorable == null
            ? 2
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
