import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/analysis/external_test_report.dart';
import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_record.dart';

/// Section 17: builds the same [ExternalTestReport] the offline CLI
/// (tool/run_external_test_analysis.dart) produces, from currently-loaded
/// [PlaytestRecord]s, so the admin dashboard's KPI tab can never disagree
/// with the CLI's numbers — both call the exact same
/// `ExternalTestReport.build`.
///
/// Tutorial telemetry (section 18) is Hive-local-only and never reaches
/// Firestore, so [tutorialEvents] is always empty here — the KPI tab must
/// show the tutorial-completion KPI as "N/A" and say so explicitly, never
/// fabricate a value.
ExternalTestReport buildAdminKpiReport(
  List<PlaytestRecord> records, {
  int oneSidedThreshold = 15,
}) => ExternalTestReport.build(
  sessions: records.map((r) => r.session).toList(),
  tutorialEvents: const <TutorialEventRecord>[],
  oneSidedThreshold: oneSidedThreshold,
);

/// Section 17's sample-size guidance, keyed by unique tester count — reused
/// verbatim from [ExternalTestReport.sampleSizeCaveat] wording style.
String kpiSampleSizeGuidance(int uniqueTesterCount) => switch (uniqueTesterCount) {
  0 => 'データがありません。',
  >= 1 && <= 4 => '参考値（ユニークプレイヤー $uniqueTesterCount 人）。',
  >= 5 && <= 9 => '初期傾向（ユニークプレイヤー $uniqueTesterCount 人）。',
  >= 10 && <= 19 => '改善候補抽出に利用可能（ユニークプレイヤー $uniqueTesterCount 人）。',
  _ => '一定の傾向評価が可能（ユニークプレイヤー $uniqueTesterCount 人）。',
};
