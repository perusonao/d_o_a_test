/// Rule toggles for the "ゲームバランス分析(Simulation)" admin tool only.
/// The real game screen/controller never reads this class — it always
/// plays under the fixed rules hardcoded in game_rules.dart regardless of
/// what's configured here. Every field defaults to reproduce today's actual
/// rules exactly, so a [SimulationConfig] that never sets `ruleFlags`
/// simulates nothing different from before this class existed.
class SimulationRuleFlags {
  const SimulationRuleFlags({
    this.judgeRequiresDeliberating = true,
    this.naturalConfirmationEnabled = true,
    this.judgeUsesPerPlayer = 1,
    this.reverseLifeEnabled = true,
    this.reverseDeathEnabled = true,
    this.eyeEnabled = true,
    this.bonusAlwaysPublic = false,
  });

  /// JUDGE — current rule: only usable while a person is still
  /// `deliberating` with zero LIFE/DEATH actions taken on them yet.
  final bool judgeRequiresDeliberating;

  /// "SPECIAL VERDICT" — whether LIFE/DEATH actions can ever confirm a
  /// verdict on their own (two matching actions in a row, or three total).
  /// Current rule: yes. When false, LIFE/DEATH only ever accumulate
  /// pending state/history and never confirm — JUDGE becomes the sole way
  /// any person is ever confirmed.
  final bool naturalConfirmationEnabled;

  /// Max JUDGE uses per faction for one game, or `null` for unlimited.
  /// Current rule: 1. Must be raised (typically to `null`) whenever
  /// [naturalConfirmationEnabled] is false, or a 9-person game can never
  /// finish with only 2 total JUDGE uses available.
  final int? judgeUsesPerPlayer;

  final bool reverseLifeEnabled;
  final bool reverseDeathEnabled;
  final bool eyeEnabled;

  /// Current rule: only the very first bonus is public; every one after it
  /// alternates hidden/revealed between factions. When true, every bonus is
  /// public to both factions the instant it becomes current.
  final bool bonusAlwaysPublic;

  /// Today's actual rules.
  static const current = SimulationRuleFlags();

  /// "② JUDGE自由": JUDGE usable in any state; SPECIAL VERDICT (natural
  /// confirmation) still enabled.
  static const judgeFreeWithNaturalConfirmation = SimulationRuleFlags(
    judgeRequiresDeliberating: false,
  );

  /// "③ JUDGE自由・SPECIAL VERDICTなし": JUDGE usable in any state, natural
  /// confirmation disabled entirely — JUDGE is the only way any person is
  /// ever confirmed, so its per-player cap must be lifted.
  static const judgeOnlyConfirmation = SimulationRuleFlags(
    judgeRequiresDeliberating: false,
    naturalConfirmationEnabled: false,
    judgeUsesPerPlayer: null,
  );

  /// [clearJudgeUsesPerPlayer] is the only way to set [judgeUsesPerPlayer]
  /// back to `null` (unlimited) — a plain `null` argument for that
  /// parameter means "leave unchanged", per Dart's usual copyWith
  /// convention, so an explicit escape hatch is needed to actually clear it.
  SimulationRuleFlags copyWith({
    bool? judgeRequiresDeliberating,
    bool? naturalConfirmationEnabled,
    int? judgeUsesPerPlayer,
    bool clearJudgeUsesPerPlayer = false,
    bool? reverseLifeEnabled,
    bool? reverseDeathEnabled,
    bool? eyeEnabled,
    bool? bonusAlwaysPublic,
  }) => SimulationRuleFlags(
    judgeRequiresDeliberating:
        judgeRequiresDeliberating ?? this.judgeRequiresDeliberating,
    naturalConfirmationEnabled:
        naturalConfirmationEnabled ?? this.naturalConfirmationEnabled,
    judgeUsesPerPlayer: clearJudgeUsesPerPlayer
        ? null
        : (judgeUsesPerPlayer ?? this.judgeUsesPerPlayer),
    reverseLifeEnabled: reverseLifeEnabled ?? this.reverseLifeEnabled,
    reverseDeathEnabled: reverseDeathEnabled ?? this.reverseDeathEnabled,
    eyeEnabled: eyeEnabled ?? this.eyeEnabled,
    bonusAlwaysPublic: bonusAlwaysPublic ?? this.bonusAlwaysPublic,
  );

  Map<String, Object?> toJson() => {
    'judgeRequiresDeliberating': judgeRequiresDeliberating,
    'naturalConfirmationEnabled': naturalConfirmationEnabled,
    'judgeUsesPerPlayer': judgeUsesPerPlayer,
    'reverseLifeEnabled': reverseLifeEnabled,
    'reverseDeathEnabled': reverseDeathEnabled,
    'eyeEnabled': eyeEnabled,
    'bonusAlwaysPublic': bonusAlwaysPublic,
  };
}
