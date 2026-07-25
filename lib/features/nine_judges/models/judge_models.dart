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
  eye('EYE'),
  judge('JUDGE');

  const ActionType(this.label);
  final String label;
}

enum TurnPhase {
  selectingAction,
  selectingActionTarget,
  selectingEyeInformation,
}

enum EyeInformation { attribute }

enum FactionSelection { savior, executor, random }

enum FirstPlayerSelection { human, cpu, random }

enum GameMode { hotseat, cpu }

enum CpuLevel {
  random('EASY', 'RANDOM'),
  basic('NORMAL', 'BASIC'),
  smart('HARD', 'SMART');

  const CpuLevel(this.uiLabel, this.strategyLabel);
  final String uiLabel;
  final String strategyLabel;
}

class NineJudgesGameSettings {
  const NineJudgesGameSettings({
    this.mode = GameMode.hotseat,
    this.cpuFaction = Faction.executor,
    this.firstPlayer = Faction.savior,
    this.factionSelection = FactionSelection.savior,
    this.firstPlayerSelection = FirstPlayerSelection.human,
    this.cpuLevel = CpuLevel.basic,
    this.skipCpuDelays = false,
    this.showCpuEvaluations = false,
  });

  final GameMode mode;
  final Faction cpuFaction;
  final Faction firstPlayer;
  final FactionSelection factionSelection;
  final FirstPlayerSelection firstPlayerSelection;
  final CpuLevel cpuLevel;
  final bool skipCpuDelays;
  final bool showCpuEvaluations;

  NineJudgesGameSettings copyWith({
    GameMode? mode,
    Faction? cpuFaction,
    Faction? firstPlayer,
    FactionSelection? factionSelection,
    FirstPlayerSelection? firstPlayerSelection,
    CpuLevel? cpuLevel,
    bool? skipCpuDelays,
    bool? showCpuEvaluations,
  }) => NineJudgesGameSettings(
    mode: mode ?? this.mode,
    cpuFaction: cpuFaction ?? this.cpuFaction,
    firstPlayer: firstPlayer ?? this.firstPlayer,
    factionSelection: factionSelection ?? this.factionSelection,
    firstPlayerSelection: firstPlayerSelection ?? this.firstPlayerSelection,
    cpuLevel: cpuLevel ?? this.cpuLevel,
    skipCpuDelays: skipCpuDelays ?? this.skipCpuDelays,
    showCpuEvaluations: showCpuEvaluations ?? this.showCpuEvaluations,
  );
}

class PersonCard {
  const PersonCard({
    required this.id,
    required this.attribute,
    required this.rank,
    required this.isAlive,
    this.isJudged = false,
    this.hasLifeShield = false,
  });

  final String id;
  final PersonAttribute attribute;
  final int rank;
  final bool isAlive;
  final bool isJudged;
  final bool hasLifeShield;

  bool get hidesAttributeWhenDead => rank == 3 && !isAlive;

  PersonCard copyWith({bool? isAlive, bool? isJudged, bool? hasLifeShield}) =>
      PersonCard(
        id: id,
        attribute: attribute,
        rank: rank,
        isAlive: isAlive ?? this.isAlive,
        isJudged: isJudged ?? this.isJudged,
        hasLifeShield: hasLifeShield ?? this.hasLifeShield,
      );
}

class BoardSlot {
  const BoardSlot({required this.person, this.hiddenNumber = 0});

  final PersonCard person;
  final int hiddenNumber;

  BoardSlot copyWith({PersonCard? person}) =>
      BoardSlot(person: person ?? this.person, hiddenNumber: hiddenNumber);
}

class ActionInventory {
  const ActionInventory({
    required this.life,
    required this.death,
    required this.eye,
    this.judge = 3,
  });

  final int life;
  final int death;
  final int eye;
  final int judge;

  int get total => life + death + eye + judge;

  int remaining(ActionType action) => switch (action) {
    ActionType.life => life,
    ActionType.death => death,
    ActionType.eye => eye,
    ActionType.judge => judge,
  };

  ActionInventory consume(ActionType action) => switch (action) {
    ActionType.life => ActionInventory(
      life: life - 1,
      death: death,
      eye: eye,
      judge: judge,
    ),
    ActionType.death => ActionInventory(
      life: life,
      death: death - 1,
      eye: eye,
      judge: judge,
    ),
    ActionType.eye => ActionInventory(
      life: life,
      death: death,
      eye: eye - 1,
      judge: judge,
    ),
    ActionType.judge => ActionInventory(
      life: life,
      death: death,
      eye: eye,
      judge: judge - 1,
    ),
  };

  Map<String, int> toJson() => {
    'life': life,
    'death': death,
    'eye': eye,
    'judge': judge,
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
