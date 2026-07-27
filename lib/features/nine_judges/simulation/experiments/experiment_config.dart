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
    this.firstPlayerBonusAction = FirstPlayerBonusAction.none,
    this.informationMode = InformationMode.standard,
  });

  final String name;
  final FinalJudgeMode finalJudgeMode;
  final JudgeVariant judgeVariant;
  final EyeZoneMode eyeZoneMode;
  final bool eyeSharedSingleUse;
  final int eyeScoreCost;
  final FirstPlayerBonusAction firstPlayerBonusAction;
  final InformationMode informationMode;

  bool get isControl =>
      finalJudgeMode == FinalJudgeMode.none &&
      judgeVariant == JudgeVariant.standard &&
      eyeZoneMode == EyeZoneMode.unrestricted &&
      !eyeSharedSingleUse &&
      eyeScoreCost == 0 &&
      firstPlayerBonusAction == FirstPlayerBonusAction.none &&
      informationMode == InformationMode.standard;

  SimulationExperimentConfig copyWith({
    String? name,
    FinalJudgeMode? finalJudgeMode,
    JudgeVariant? judgeVariant,
    EyeZoneMode? eyeZoneMode,
    bool? eyeSharedSingleUse,
    int? eyeScoreCost,
    FirstPlayerBonusAction? firstPlayerBonusAction,
    InformationMode? informationMode,
  }) => SimulationExperimentConfig(
    name: name ?? this.name,
    finalJudgeMode: finalJudgeMode ?? this.finalJudgeMode,
    judgeVariant: judgeVariant ?? this.judgeVariant,
    eyeZoneMode: eyeZoneMode ?? this.eyeZoneMode,
    eyeSharedSingleUse: eyeSharedSingleUse ?? this.eyeSharedSingleUse,
    eyeScoreCost: eyeScoreCost ?? this.eyeScoreCost,
    firstPlayerBonusAction:
        firstPlayerBonusAction ?? this.firstPlayerBonusAction,
    informationMode: informationMode ?? this.informationMode,
  );

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
