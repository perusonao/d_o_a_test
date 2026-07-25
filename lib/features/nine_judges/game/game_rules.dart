import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class NineJudgesRules {
  static List<BoardSlot> createBoard(
    Random random, {
    bool scoreVisible = true,
  }) {
    final columns = <List<PersonCard>>[
      for (var rank = 1; rank <= 3; rank++)
        [
          for (final attribute in PersonAttribute.values)
            PersonCard(
              id: '${attribute.name}-$rank',
              attribute: attribute,
              rank: rank,
              isAlive: NineJudgesConfig.initialAliveByRank[rank]!,
            ),
        ]..shuffle(random),
    ];
    final fixedColumns = [
      for (var row = 0; row < 3; row++)
        for (var column = 0; column < 3; column++)
          BoardSlot(person: columns[column][row]),
    ];
    if (scoreVisible) return fixedColumns;
    final shuffled = [...fixedColumns]..shuffle(random);
    return shuffled;
  }

  static bool isAttributeVisible(
    PersonCard person, {
    required bool revealAll,
  }) => revealAll || !person.hidesAttributeWhenDead;

  static bool canUseAction({
    required ActionType action,
    required PersonCard person,
    required bool viewerKnowsNumber,
    bool viewerKnowsAttribute = false,
    bool viewerKnowsRank = true,
    int currentTurn = 0,
    Faction? viewer,
  }) {
    if (person.isJudged) return false;
    return switch (action) {
      ActionType.life => !person.isAlive || !person.hasLifeShield,
      ActionType.death => true,
      ActionType.eye => !viewerKnowsAttribute || !viewerKnowsRank,
      ActionType.judge =>
        person.isUnderReview &&
            (person.lastStateChangedBy != viewer ||
                currentTurn >= person.judgeAvailableFromTurn),
    };
  }

  static PersonAttribute? inferRank3Attribute({
    required List<PersonCard> rankThreePeople,
    required Set<String> knownPersonIds,
    required String targetPersonId,
  }) {
    if (knownPersonIds.contains(targetPersonId)) {
      return rankThreePeople
          .firstWhere((person) => person.id == targetPersonId)
          .attribute;
    }
    final known = rankThreePeople
        .where((person) => knownPersonIds.contains(person.id))
        .map((person) => person.attribute)
        .toSet();
    if (known.length != 2) return null;
    return PersonAttribute.values.firstWhere(
      (attribute) => !known.contains(attribute),
    );
  }

  static Faction scoringFaction(PersonCard person) {
    final saviorScores =
        (person.attribute == PersonAttribute.good && person.isAlive) ||
        (person.attribute == PersonAttribute.neutral && person.isAlive) ||
        (person.attribute == PersonAttribute.evil && !person.isAlive);
    return saviorScores ? Faction.savior : Faction.executor;
  }

  static ScoreResult calculateScore(List<BoardSlot> board) {
    var savior = 0;
    var executor = 0;
    final details = <String, ({Faction faction, int points})>{};
    for (final slot in board) {
      final faction = scoringFaction(slot.person);
      final points = slot.person.rank;
      details[slot.person.id] = (faction: faction, points: points);
      if (faction == Faction.savior) {
        savior += points;
      } else {
        executor += points;
      }
    }
    return ScoreResult(savior: savior, executor: executor, slotScores: details);
  }
}
