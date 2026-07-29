import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

/// Maps each faction to its navigator/symbol character portrait, cropped
/// from the official key visual. Shared by the intro, SPECIAL VERDICT and
/// result overlays so all three moments read as the same character.
abstract final class CharacterAssets {
  static const _saviorPortrait = 'assets/branding/savior_portrait.png';
  static const _executorPortrait = 'assets/branding/executor_portrait.png';

  static String portrait(Faction faction) =>
      faction == Faction.savior ? _saviorPortrait : _executorPortrait;
}
