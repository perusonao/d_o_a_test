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
  specialVerdict('JUDGE');

  const ActionType(this.label);
  final String label;
}

enum VerdictActionType {
  life('生'),
  death('死');

  const VerdictActionType(this.label);
  final String label;
}

/// Which ruleset a game is played under. v1.1 is kept in full (never
/// deleted) so the two remain directly comparable; v1.2 is the version
/// players get by default.
///
/// v1.2 changes exactly one thing versus v1.1: EYE may only target the
/// center row (the 3 slots neither side knows at game start), capped at 2
/// uses per player, at most once per player per person. Everything else
/// (LIFE/DEATH, JUDGE, the one-shot reverse action, scoring, the bonus deck)
/// is untouched.
enum NineJudgesRuleVersion {
  v1_1('1.1'),
  v1_2('1.2');

  const NineJudgesRuleVersion(this.label);
  final String label;
}

enum TurnPhase { selectingAction, selectingActionTarget }

enum FactionSelection { savior, executor, random }

enum FirstPlayerSelection { human, cpu, random }

enum GameMode { hotseat, cpu }

/// CPU の思考パターン。強さと性格を兼ねた1軸として提示する。
///
/// Declaration order is the actual measured strength order (weakest to
/// strongest — see cross-play round-robin testing), not alphabetical or
/// historical order, so that UI simply iterating [CpuLevel.values] lists
/// difficulties correctly without a separate ranking table. This order does
/// not match each entry's Japanese persona name in an intuitive way (e.g.
/// "熟練"/EXPERT plays a more cautious, threat-aware style that nets a
/// slightly lower measured win rate than "バランス"/BALANCED's more direct
/// play) — [strengthLabel] communicates the actual tier to players
/// regardless of the persona name. Only [strengthLabel] is new; [uiLabel],
/// [strategyLabel] (persisted in game logs), and [description] are
/// unchanged, so nothing about existing saves/logs is affected by the
/// reordering (nothing serializes enum index/order, only [strategyLabel]).
enum CpuLevel {
  random('ランダム', 'RANDOM', '合法手から無作為に選びます', 'EASY'),
  aggressive('攻撃的', 'AGGRESSIVE', '確定と得点を急ぎ、審判も早めに切ります', 'NORMAL'),
  expert('熟練', 'EXPERT', '相手の応手まで先読みして最善手を選びます', 'HARD'),
  defensive('守備的', 'DEFENSIVE', '有利な確定を守り、危険な人物を先に処理します', 'HARDER'),
  balanced('バランス', 'BALANCED', '人物価値と陣営目的を釣り合わせて評価します', 'HARDEST');

  const CpuLevel(
    this.uiLabel,
    this.strategyLabel,
    this.description,
    this.strengthLabel,
  );
  final String uiLabel;
  final String strategyLabel;
  final String description;

  /// Difficulty tier label shown alongside [uiLabel] in the CPU-strength
  /// picker, in increasing order of actual measured strength.
  final String strengthLabel;
}

class NineJudgesGameSettings {
  const NineJudgesGameSettings({
    this.mode = GameMode.hotseat,
    this.cpuFaction = Faction.executor,
    this.firstPlayer = Faction.savior,
    this.factionSelection = FactionSelection.savior,
    this.firstPlayerSelection = FirstPlayerSelection.human,
    this.cpuLevel = CpuLevel.balanced,
    this.skipCpuDelays = false,
    this.showCpuEvaluations = false,
    this.ruleVersion = NineJudgesRuleVersion.v1_2,
  });

  final GameMode mode;
  final Faction cpuFaction;
  final Faction firstPlayer;
  final FactionSelection factionSelection;
  final FirstPlayerSelection firstPlayerSelection;
  final CpuLevel cpuLevel;
  final bool skipCpuDelays;
  final bool showCpuEvaluations;

  /// Which ruleset this game plays under. Defaults to the current, normal
  /// ruleset (v1.2); pass [NineJudgesRuleVersion.v1_1] to play/simulate the
  /// previous ruleset for comparison.
  final NineJudgesRuleVersion ruleVersion;

  NineJudgesGameSettings copyWith({
    GameMode? mode,
    Faction? cpuFaction,
    Faction? firstPlayer,
    FactionSelection? factionSelection,
    FirstPlayerSelection? firstPlayerSelection,
    CpuLevel? cpuLevel,
    bool? skipCpuDelays,
    bool? showCpuEvaluations,
    NineJudgesRuleVersion? ruleVersion,
  }) => NineJudgesGameSettings(
    mode: mode ?? this.mode,
    cpuFaction: cpuFaction ?? this.cpuFaction,
    firstPlayer: firstPlayer ?? this.firstPlayer,
    factionSelection: factionSelection ?? this.factionSelection,
    firstPlayerSelection: firstPlayerSelection ?? this.firstPlayerSelection,
    cpuLevel: cpuLevel ?? this.cpuLevel,
    skipCpuDelays: skipCpuDelays ?? this.skipCpuDelays,
    showCpuEvaluations: showCpuEvaluations ?? this.showCpuEvaluations,
    ruleVersion: ruleVersion ?? this.ruleVersion,
  );
}

class PersonCard {
  const PersonCard({
    required this.id,
    required this.attribute,
    this.verdictState = VerdictState.deliberating,
    this.verdictActionCount = 0,
    this.verdictHistory = const [],
    this.confirmedBy,
    this.scoringFaction,
    this.awardedBonus,
  });

  final String id;
  final PersonAttribute attribute;
  final VerdictState verdictState;
  final int verdictActionCount;
  final List<VerdictActionType> verdictHistory;
  final Faction? confirmedBy;
  final Faction? scoringFaction;
  final int? awardedBonus;

  bool get isConfirmed => verdictState.isConfirmed;
  bool get isAlive => verdictState.isAlive;

  PersonCard copyWith({
    VerdictState? verdictState,
    int? verdictActionCount,
    List<VerdictActionType>? verdictHistory,
    Faction? confirmedBy,
    Faction? scoringFaction,
    int? awardedBonus,
  }) => PersonCard(
    id: id,
    attribute: attribute,
    verdictState: verdictState ?? this.verdictState,
    verdictActionCount: verdictActionCount ?? this.verdictActionCount,
    verdictHistory: verdictHistory ?? this.verdictHistory,
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
    required this.action,
    required this.targetIndex,
    this.confirmedAttribute,
    this.confirmedState,
    this.verdictBonus,
    this.scoringFaction,
  });

  final int turn;
  final Faction player;
  final String message;
  final ActionType action;
  final int targetIndex;
  final PersonAttribute? confirmedAttribute;
  final VerdictState? confirmedState;
  final int? verdictBonus;
  final Faction? scoringFaction;
}

class VerdictBonusResult {
  const VerdictBonusResult({
    required this.order,
    required this.bonus,
    required this.scoringFaction,
    required this.personId,
    required this.targetIndex,
    required this.attribute,
    required this.finalState,
    required this.confirmedBy,
  });

  final int order;
  final int bonus;
  final Faction scoringFaction;
  final String personId;
  final int targetIndex;
  final PersonAttribute attribute;
  final VerdictState finalState;
  final Faction confirmedBy;
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
