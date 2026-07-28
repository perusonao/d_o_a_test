import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class NineJudgesConfig {
  static const String gameVersion = '1.3.0-external-test-beta';
  static const String rulesVersion = '1.2';

  /// Identifies this external-test round in logs/Firebase so results from
  /// different rounds are never silently mixed together in analysis.
  static const String testCohort = 'external_test_1_2';

  /// Git commit hash for this build, when the build pipeline provides one
  /// via `--dart-define=BUILD_COMMIT_HASH=...` (see deploy-pages.yml). Null
  /// for local/dev builds that don't pass it — intentionally optional.
  static const String _rawBuildCommitHash = String.fromEnvironment(
    'BUILD_COMMIT_HASH',
  );
  static String? get buildCommitHash =>
      _rawBuildCommitHash.isEmpty ? null : _rawBuildCommitHash;

  static const Faction defaultFirstPlayer = Faction.savior;
  static const int personCount = 9;
  static const int specialVerdictsPerPlayer = 1;
  static const List<int> verdictBonuses = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  /// The 3 board slots neither faction knows at game start (the "front rows"
  /// {0,1,2} and {6,7,8} are always split one-each between savior/executor;
  /// see [NineJudgesController.reset]). Fixed regardless of which faction the
  /// human plays in a CPU game.
  static const Set<int> centerIndices = {3, 4, 5};

  /// EYE uses allowed per player for one game, or `null` for no cap (v1.1).
  static int? eyeMaxUsesPerPlayer(NineJudgesRuleVersion ruleVersion) =>
      switch (ruleVersion) {
        NineJudgesRuleVersion.v1_1 => null,
        NineJudgesRuleVersion.v1_2 => 2,
      };

  /// Whether EYE is restricted to [centerIndices] under this ruleset.
  static bool eyeZoneRestricted(NineJudgesRuleVersion ruleVersion) =>
      ruleVersion == NineJudgesRuleVersion.v1_2;
}
