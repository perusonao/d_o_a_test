enum Faction {
  savior('救済者'),
  executor('執行者');

  const Faction(this.label);
  final String label;

  Faction get opponent =>
      this == Faction.savior ? Faction.executor : Faction.savior;
}

enum PersonAttribute {
  good('善人'),
  evil('悪人'),
  neutral('中立');

  const PersonAttribute(this.label);
  final String label;
}

enum VerdictState {
  deliberating('審議中'),
  alive('生'),
  dead('死'),
  aliveConfirmed('生確定'),
  deadConfirmed('死確定');

  const VerdictState(this.label);
  final String label;

  bool get isConfirmed =>
      this == VerdictState.aliveConfirmed || this == VerdictState.deadConfirmed;
  bool get isAlive =>
      this == VerdictState.alive || this == VerdictState.aliveConfirmed;
}

enum ActionType {
  life('LIFE'),
  death('DEATH'),
  eye('EYE'),
  specialVerdict('審判');

  const ActionType(this.label);
  final String label;
}

enum TurnPhase { selectingAction, selectingActionTarget }

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
    this.verdictState = VerdictState.deliberating,
    this.verdictActionCount = 0,
    this.confirmedBy,
    this.scoringFaction,
    this.awardedBonus,
  });

  final String id;
  final PersonAttribute attribute;
  final VerdictState verdictState;
  final int verdictActionCount;
  final Faction? confirmedBy;
  final Faction? scoringFaction;
  final int? awardedBonus;

  bool get isConfirmed => verdictState.isConfirmed;
  bool get isAlive => verdictState.isAlive;

  PersonCard copyWith({
    VerdictState? verdictState,
    int? verdictActionCount,
    Faction? confirmedBy,
    Faction? scoringFaction,
    int? awardedBonus,
  }) => PersonCard(
    id: id,
    attribute: attribute,
    verdictState: verdictState ?? this.verdictState,
    verdictActionCount: verdictActionCount ?? this.verdictActionCount,
    confirmedBy: confirmedBy ?? this.confirmedBy,
    scoringFaction: scoringFaction ?? this.scoringFaction,
    awardedBonus: awardedBonus ?? this.awardedBonus,
  );
}

class BoardSlot {
  const BoardSlot({required this.person});
  final PersonCard person;

  BoardSlot copyWith({PersonCard? person}) =>
      BoardSlot(person: person ?? this.person);
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
