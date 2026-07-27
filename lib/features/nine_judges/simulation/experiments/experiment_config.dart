import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

/// How the final (9th) confirmation is scored.
///
/// [doubleBonus] keeps the normal 1..9 bonus deck but doubles the value of
/// whichever bonus lands on the 9th confirmation (Experiment A).
/// [tenthPerson] leaves the 9-person board untouched and appends a hidden
/// 10th "FINAL JUDGE" person worth a flat 10 points, resolved by a
/// simultaneous LIFE/DEATH guess after the board is fully confirmed
/// (Experiment B).
enum FinalJudgeMode { none, doubleBonus, tenthPerson }

/// [reverseConfirmed] replaces the standard JUDGE (confirm an untouched,
/// deliberating person) with a special action that flips the final state of
/// an already-confirmed person, recomputing which faction scores that
/// person's existing bonus (Experiment C).
enum JudgeVariant { standard, reverseConfirmed }

/// Restricts which board slots EYE may target (Experiment D).
enum EyeZoneMode { unrestricted, centerOnly }

/// Extra one-shot action granted only to the player who moves first
/// (Experiment F).
enum FirstPlayerBonusAction { none, specialVerdict, reverseAction }

/// Replaces the standard shared-but-delayed bonus visibility and per-side
/// starting knowledge with a strict split: one faction always knows every
/// person's attribute (and never the bonus), the other always knows the
/// current bonus (and never any attribute except through EYE) (Experiment G).
enum InformationMode {
  standard,
  firstPlayerIsAttributeViewer,
  firstPlayerIsBonusViewer,
}

/// Toggleable rule variant used only by the simulation harness. Every field
/// defaults to the current production rule, so combining experiments is just
/// setting more than one non-default field rather than hand-wiring a new
/// code path per combination.
class SimulationExperimentConfig {
  const SimulationExperimentConfig({
    required this.name,
    this.finalJudgeMode = FinalJudgeMode.none,
    this.judgeVariant = JudgeVariant.standard,
    this.eyeZoneMode = EyeZoneMode.unrestricted,
    this.eyeSharedSingleUse = false,
    this.eyeScoreCost = 0,
    this.eyeMaxUsesPerPlayer,
    this.eyeFreeFirstUse = false,
    this.firstPlayerBonusAction = FirstPlayerBonusAction.none,
    this.informationMode = InformationMode.standard,
    this.revokeBudgetFirstPlayer = 0,
    this.revokeBudgetSecondPlayer = 0,
  });

  final String name;
  final FinalJudgeMode finalJudgeMode;
  final JudgeVariant judgeVariant;
  final EyeZoneMode eyeZoneMode;
  final bool eyeSharedSingleUse;
  final int eyeScoreCost;

  /// Caps how many times each player may use EYE in one game (0..3). `null`
  /// means no cap beyond whatever [eyeZoneMode]/[eyeSharedSingleUse] already
  /// forbid.
  final int? eyeMaxUsesPerPlayer;

  /// When true, each player's *first* EYE use in the game is free; only the
  /// 2nd and later uses pay [eyeScoreCost].
  final bool eyeFreeFirstUse;

  final FirstPlayerBonusAction firstPlayerBonusAction;
  final InformationMode informationMode;

  /// One-shot-per-game REVOKE budget (remove the most recent LIFE/DEATH mark
  /// from a still-undecided person), keyed by turn order rather than faction
  /// so it composes with [SimulationFirstPlayer.alternate]. 0 disables it.
  final int revokeBudgetFirstPlayer;
  final int revokeBudgetSecondPlayer;

  bool get isControl =>
      finalJudgeMode == FinalJudgeMode.none &&
      judgeVariant == JudgeVariant.standard &&
      eyeZoneMode == EyeZoneMode.unrestricted &&
      !eyeSharedSingleUse &&
      eyeScoreCost == 0 &&
      eyeMaxUsesPerPlayer == null &&
      !eyeFreeFirstUse &&
      firstPlayerBonusAction == FirstPlayerBonusAction.none &&
      informationMode == InformationMode.standard &&
      revokeBudgetFirstPlayer == 0 &&
      revokeBudgetSecondPlayer == 0;

  SimulationExperimentConfig copyWith({
    String? name,
    FinalJudgeMode? finalJudgeMode,
    JudgeVariant? judgeVariant,
    EyeZoneMode? eyeZoneMode,
    bool? eyeSharedSingleUse,
    int? eyeScoreCost,
    Object? eyeMaxUsesPerPlayer = _unset,
    bool? eyeFreeFirstUse,
    FirstPlayerBonusAction? firstPlayerBonusAction,
    InformationMode? informationMode,
    int? revokeBudgetFirstPlayer,
    int? revokeBudgetSecondPlayer,
  }) => SimulationExperimentConfig(
    name: name ?? this.name,
    finalJudgeMode: finalJudgeMode ?? this.finalJudgeMode,
    judgeVariant: judgeVariant ?? this.judgeVariant,
    eyeZoneMode: eyeZoneMode ?? this.eyeZoneMode,
    eyeSharedSingleUse: eyeSharedSingleUse ?? this.eyeSharedSingleUse,
    eyeScoreCost: eyeScoreCost ?? this.eyeScoreCost,
    eyeMaxUsesPerPlayer: identical(eyeMaxUsesPerPlayer, _unset)
        ? this.eyeMaxUsesPerPlayer
        : eyeMaxUsesPerPlayer as int?,
    eyeFreeFirstUse: eyeFreeFirstUse ?? this.eyeFreeFirstUse,
    firstPlayerBonusAction:
        firstPlayerBonusAction ?? this.firstPlayerBonusAction,
    informationMode: informationMode ?? this.informationMode,
    revokeBudgetFirstPlayer:
        revokeBudgetFirstPlayer ?? this.revokeBudgetFirstPlayer,
    revokeBudgetSecondPlayer:
        revokeBudgetSecondPlayer ?? this.revokeBudgetSecondPlayer,
  );

  static const _unset = Object();

  static const control = SimulationExperimentConfig(name: 'CONTROL');

  static final finalJudgeDouble = control.copyWith(
    name: 'A_FINAL_JUDGE_x2',
    finalJudgeMode: FinalJudgeMode.doubleBonus,
  );

  static final tenthPersonFinalJudge = control.copyWith(
    name: 'B_10TH_FINAL_JUDGE',
    finalJudgeMode: FinalJudgeMode.tenthPerson,
  );

  static final reverseJudge = control.copyWith(
    name: 'C_REVERSE_JUDGE',
    judgeVariant: JudgeVariant.reverseConfirmed,
  );

  static final centerEyeOnly = control.copyWith(
    name: 'D_CENTER_EYE_ONLY',
    eyeZoneMode: EyeZoneMode.centerOnly,
    eyeSharedSingleUse: true,
  );

  static final eyeCost = control.copyWith(
    name: 'E_EYE_MINUS1',
    eyeScoreCost: 1,
  );

  static final centerEyeOnlyWithCost = centerEyeOnly.copyWith(
    name: 'D_PLUS_E',
    eyeScoreCost: 1,
  );

  static final firstPlayerExtraSpecial = control.copyWith(
    name: 'F_FIRST_SPECIAL_VERDICT_PLUS1',
    firstPlayerBonusAction: FirstPlayerBonusAction.specialVerdict,
  );

  static final firstPlayerExtraReverse = control.copyWith(
    name: 'F_FIRST_REVERSE_ACTION_PLUS1',
    firstPlayerBonusAction: FirstPlayerBonusAction.reverseAction,
  );

  static final infoFirstIsAttributeViewer = control.copyWith(
    name: 'G_FIRST_ATTRIBUTE_SECOND_BONUS',
    informationMode: InformationMode.firstPlayerIsAttributeViewer,
  );

  static final infoFirstIsBonusViewer = control.copyWith(
    name: 'G_FIRST_BONUS_SECOND_ATTRIBUTE',
    informationMode: InformationMode.firstPlayerIsBonusViewer,
  );

  /// The primary single-toggle experiments requested for screening, plus a
  /// handful of combinations worth checking once a base experiment looks
  /// promising. Combinations are built by chaining [copyWith] calls, never by
  /// adding a new hardcoded code path in the runner.
  static final List<SimulationExperimentConfig> primarySet = [
    control,
    finalJudgeDouble,
    tenthPersonFinalJudge,
    reverseJudge,
    centerEyeOnly,
    eyeCost,
    centerEyeOnlyWithCost,
    firstPlayerExtraSpecial,
    firstPlayerExtraReverse,
    infoFirstIsAttributeViewer,
    infoFirstIsBonusViewer,
  ];

  static final List<SimulationExperimentConfig> combinationSet = [
    finalJudgeDouble.copyWith(
      name: 'A_PLUS_D',
      eyeZoneMode: EyeZoneMode.centerOnly,
      eyeSharedSingleUse: true,
    ),
    finalJudgeDouble.copyWith(
      name: 'A_PLUS_D_PLUS_E',
      eyeZoneMode: EyeZoneMode.centerOnly,
      eyeSharedSingleUse: true,
      eyeScoreCost: 1,
    ),
    tenthPersonFinalJudge.copyWith(
      name: 'B_PLUS_D',
      eyeZoneMode: EyeZoneMode.centerOnly,
      eyeSharedSingleUse: true,
    ),
    tenthPersonFinalJudge.copyWith(
      name: 'B_PLUS_D_PLUS_E',
      eyeZoneMode: EyeZoneMode.centerOnly,
      eyeSharedSingleUse: true,
      eyeScoreCost: 1,
    ),
    reverseJudge.copyWith(
      name: 'C_PLUS_D',
      eyeZoneMode: EyeZoneMode.centerOnly,
      eyeSharedSingleUse: true,
    ),
    reverseJudge.copyWith(
      name: 'C_PLUS_D_PLUS_G_FIRST_ATTRIBUTE',
      eyeZoneMode: EyeZoneMode.centerOnly,
      eyeSharedSingleUse: true,
      informationMode: InformationMode.firstPlayerIsAttributeViewer,
    ),
  ];

  /// The fixed 3x3 knowledge split this round's whole study is built on: own
  /// row known from the start, opponent's row never EYE-able even though
  /// it's unknown, center row is the only legal EYE zone. Unlike the first
  /// round's [centerEyeOnly] (which also shared a single use across both
  /// players), this base has no cross-player restriction — [eyeMaxUsesPerPlayer]
  /// is the lever this round instead.
  static final eyeZoneBase = control.copyWith(
    name: 'D_ZONE_BASE',
    eyeZoneMode: EyeZoneMode.centerOnly,
  );

  /// One cell of the EYE-limit × EYE-cost × first-player-SPECIAL grid.
  /// [eyeMax] is 0..3 (3 == every center slot, since a slot can only ever be
  /// EYE'd once per player anyway). [eyeCost] is 0 or 1 (flat per-use point
  /// cost). [freeFirstUse] downgrades a flat cost to "first use free, 2nd+
  /// costs [eyeCost]" (Experiment 2's stretch candidate C).
  static SimulationExperimentConfig eyeGridCell({
    required int eyeMax,
    required int eyeCost,
    bool freeFirstUse = false,
    bool firstPlayerSpecial = false,
  }) {
    final parts = [
      'EYE$eyeMax',
      if (eyeCost == 0)
        'COST0'
      else if (freeFirstUse)
        'COST_FREE1ST'
      else
        'COST-1',
      if (firstPlayerSpecial) 'FSPECIAL',
    ];
    return eyeZoneBase.copyWith(
      name: parts.join('_'),
      eyeMaxUsesPerPlayer: eyeMax,
      eyeScoreCost: eyeCost,
      eyeFreeFirstUse: freeFirstUse,
      firstPlayerBonusAction: firstPlayerSpecial
          ? FirstPlayerBonusAction.specialVerdict
          : FirstPlayerBonusAction.none,
    );
  }

  /// The full 4 (EYE limit) × 2 (cost) × 2 (first-player SPECIAL) = 16-cell
  /// grid requested for Experiments 1-3, all built on [eyeZoneBase] via
  /// [eyeGridCell] rather than one hardcoded config per cell.
  static final List<SimulationExperimentConfig> eyeGrid = [
    for (final eyeMax in [0, 1, 2, 3])
      for (final eyeCost in [0, 1])
        for (final firstPlayerSpecial in [false, true])
          eyeGridCell(
            eyeMax: eyeMax,
            eyeCost: eyeCost,
            firstPlayerSpecial: firstPlayerSpecial,
          ),
  ];

  /// Experiment 2's stretch candidate C ("1st EYE free, 2nd+ costs 1") for
  /// eyeMax 2 and 3 — the only limits where a 2nd EYE use is even possible.
  static final List<SimulationExperimentConfig> eyeFreeFirstUseGrid = [
    for (final eyeMax in [2, 3])
      for (final firstPlayerSpecial in [false, true])
        eyeGridCell(
          eyeMax: eyeMax,
          eyeCost: 1,
          freeFirstUse: true,
          firstPlayerSpecial: firstPlayerSpecial,
        ),
  ];

  /// REVOKE budget presets layered on top of a base (normally one of the
  /// promising [eyeGrid] cells) for Experiment 4 / the second screening
  /// stage. Budgets are keyed by turn order, so "first-only" and "first
  /// gets more" compose the same way [firstPlayerBonusAction] does.
  static List<SimulationExperimentConfig> revokeVariants(
    SimulationExperimentConfig base,
  ) => [
    base.copyWith(name: '${base.name}_REVOKE_NONE'),
    base.copyWith(
      name: '${base.name}_REVOKE_BOTH1',
      revokeBudgetFirstPlayer: 1,
      revokeBudgetSecondPlayer: 1,
    ),
    base.copyWith(
      name: '${base.name}_REVOKE_FIRST1',
      revokeBudgetFirstPlayer: 1,
      revokeBudgetSecondPlayer: 0,
    ),
    base.copyWith(
      name: '${base.name}_REVOKE_FIRST2_SECOND1',
      revokeBudgetFirstPlayer: 2,
      revokeBudgetSecondPlayer: 1,
    ),
  ];

  /// First player is "attribute-only" viewer for this game's information
  /// mode, or null when [informationMode] is [InformationMode.standard].
  Faction? attributeViewer(Faction firstPlayer) => switch (informationMode) {
    InformationMode.standard => null,
    InformationMode.firstPlayerIsAttributeViewer => firstPlayer,
    InformationMode.firstPlayerIsBonusViewer => firstPlayer.opponent,
  };

  Faction? bonusViewer(Faction firstPlayer) =>
      attributeViewer(firstPlayer)?.opponent;
}
