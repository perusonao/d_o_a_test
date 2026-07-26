import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class NineJudgesRules {
  static List<BoardSlot> createBoard(Random random) {
    final people = [
      for (final attribute in PersonAttribute.values)
        for (var number = 1; number <= 3; number++)
          PersonCard(id: '${attribute.name}-$number', attribute: attribute),
    ]..shuffle(random);
    return [for (final person in people) BoardSlot(person: person)];
  }

  static List<int> createBonusDeck(Random random) =>
      List<int>.generate(9, (index) => index + 1)..shuffle(random);

  static bool canUseAction({
    required ActionType action,
    required PersonCard person,
    required Faction actor,
    required bool actorKnowsAttribute,
    required bool specialVerdictUsed,
  }) {
    if (person.isConfirmed) return false;
    return switch (action) {
      ActionType.life => actor == Faction.savior,
      ActionType.death => actor == Faction.executor,
      ActionType.eye => !actorKnowsAttribute,
      ActionType.specialVerdict =>
        !specialVerdictUsed &&
            person.verdictState == VerdictState.deliberating &&
            person.verdictActionCount == 0,
    };
  }

  static PersonCard applyVerdictAction({
    required PersonCard person,
    required ActionType action,
    required Faction actor,
  }) {
    assert(action == ActionType.life || action == ActionType.death);
    final desired = action == ActionType.life
        ? VerdictState.alive
        : VerdictState.dead;
    final sameState = person.verdictState == desired;
    final count = person.verdictActionCount + 1;
    final history = [
      ...person.verdictHistory,
      action == ActionType.life
          ? VerdictActionType.life
          : VerdictActionType.death,
    ];
    final confirm = sameState || count >= 3;
    return person.copyWith(
      verdictState: confirm
          ? (desired == VerdictState.alive
                ? VerdictState.aliveConfirmed
                : VerdictState.deadConfirmed)
          : desired,
      verdictActionCount: count,
      verdictHistory: history,
      confirmedBy: confirm ? actor : null,
    );
  }

  static PersonCard applySpecialVerdict({
    required PersonCard person,
    required Faction actor,
  }) => person.copyWith(
    verdictState: actor == Faction.savior
        ? VerdictState.aliveConfirmed
        : VerdictState.deadConfirmed,
    confirmedBy: actor,
  );

  static Faction scoringFaction(PersonCard person) {
    assert(person.isConfirmed);
    final saviorScores =
        (person.attribute != PersonAttribute.evil && person.isAlive) ||
        (person.attribute == PersonAttribute.evil && !person.isAlive);
    return saviorScores ? Faction.savior : Faction.executor;
  }
}
