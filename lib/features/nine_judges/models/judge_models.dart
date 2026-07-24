enum Faction {
  savior('救済者'),
  executor('執行者');

  const Faction(this.label);
  final String label;

  Faction get opponent =>
      this == Faction.savior ? Faction.executor : Faction.savior;
}

enum PersonAttribute {
  good('GOOD'),
  evil('EVIL'),
  neutral('NEUTRAL');

  const PersonAttribute(this.label);
  final String label;
}

enum ActionType {
  life('LIFE'),
  death('DEATH'),
  judge('JUDGE');

  const ActionType(this.label);
  final String label;
}

enum TurnPhase { selectingAction, selectingTarget, awaitingSave, selectingSave }

class PersonCard {
  const PersonCard({
    required this.id,
    required this.attribute,
    required this.rank,
    required this.isAlive,
    this.isJudged = false,
  });

  final String id;
  final PersonAttribute attribute;
  final int rank;
  final bool isAlive;
  final bool isJudged;

  bool get hidesAttributeWhenDead => rank == 3 && !isAlive;

  PersonCard copyWith({bool? isAlive, bool? isJudged}) => PersonCard(
    id: id,
    attribute: attribute,
    rank: rank,
    isAlive: isAlive ?? this.isAlive,
    isJudged: isJudged ?? this.isJudged,
  );
}

class BoardSlot {
  const BoardSlot({required this.person, required this.hiddenNumber});

  final PersonCard person;
  final int hiddenNumber;

  BoardSlot copyWith({PersonCard? person}) =>
      BoardSlot(person: person ?? this.person, hiddenNumber: hiddenNumber);
}

class ActionInventory {
  const ActionInventory({
    required this.life,
    required this.death,
    required this.judge,
  });

  final int life;
  final int death;
  final int judge;

  int remaining(ActionType action) => switch (action) {
    ActionType.life => life,
    ActionType.death => death,
    ActionType.judge => judge,
  };

  ActionInventory consume(ActionType action) => switch (action) {
    ActionType.life => ActionInventory(
      life: life - 1,
      death: death,
      judge: judge,
    ),
    ActionType.death => ActionInventory(
      life: life,
      death: death - 1,
      judge: judge,
    ),
    ActionType.judge => ActionInventory(
      life: life,
      death: death,
      judge: judge - 1,
    ),
  };
}

class GameLogEntry {
  const GameLogEntry({
    required this.turn,
    required this.player,
    required this.message,
  });

  final int turn;
  final Faction player;
  final String message;
}

class ScoreResult {
  const ScoreResult({
    required this.savior,
    required this.executor,
    required this.slotScores,
  });

  final int savior;
  final int executor;
  final Map<String, ({Faction faction, int points})> slotScores;

  Faction? get winner {
    if (savior == executor) return null;
    return savior > executor ? Faction.savior : Faction.executor;
  }
}
