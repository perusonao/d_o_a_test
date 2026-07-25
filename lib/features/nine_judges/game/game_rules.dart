import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class NineJudgesRules {
  static List<BoardSlot> createBoard(Random random) {
    final people = [
      for (final attribute in PersonAttribute.values)
        for (var rank = 1; rank <= 3; rank++)
          PersonCard(
            id: '${attribute.name}-$rank',
            attribute: attribute,
            rank: rank,
            isAlive: NineJudgesConfig.initialAliveByRank[rank]!,
          ),
    ]..shuffle(random);
    final numbers = List.generate(9, (index) => index + 1)..shuffle(random);
    return List.generate(
      9,
      (index) => BoardSlot(person: people[index], hiddenNumber: numbers[index]),
    );
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
  }) {
    if (person.isJudged) return false;
    return switch (action) {
      ActionType.life => !person.isAlive || !person.hasLifeShield,
      ActionType.death => true,
      ActionType.eye =>
        !viewerKnowsNumber ||
            (person.hidesAttributeWhenDead && !viewerKnowsAttribute),
      ActionType.judge => true,
    };
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
      final points = slot.person.rank + slot.hiddenNumber;
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
