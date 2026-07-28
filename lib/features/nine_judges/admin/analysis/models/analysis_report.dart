import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_finding.dart';

/// Versioned JSON schema for the AI-analysis report (section 14). Bump
/// [AnalysisReport.schemaVersion] on any breaking structural change so a
/// consumer (a human pasting into ChatGPT/Claude, or a future script) can
/// tell which shape it's reading.
const String analysisReportSchemaVersion = '1.0';

/// One rating's average/median/n/1-5 distribution, with nulls excluded from
/// every statistic (section D).
class RatingDistribution {
  const RatingDistribution({
    required this.average,
    required this.median,
    required this.n,
    required this.counts,
  });

  final double? average;
  final double? median;
  final int n;

  /// Keys '1'..'5', values = response counts. 'null' key = missing-response
  /// count (section D's "null件数").
  final Map<String, int> counts;

  Map<String, Object?> toJson() => {
    'average': average,
    'median': median,
    'n': n,
    'distribution': counts,
  };
}

/// The full generated report (sections A-L of the admin-analysis-report
/// spec). Everything here is a plain, versioned, key-based structure
/// (mirroring [ExternalTestReport]'s existing `Map<String, Object?>`
/// convention in this codebase) so adding a new key later can't break an
/// existing consumer reading by key.
class AnalysisReport {
  const AnalysisReport({
    this.schemaVersion = analysisReportSchemaVersion,
    required this.generatedAt,
    required this.reportInfo,
    required this.filters,
    required this.summary,
    required this.balance,
    required this.ratings,
    required this.eyeAnalysis,
    required this.judgeAnalysis,
    required this.reverseAnalysis,
    required this.firstGameComparison,
    required this.cpuDifficultyAnalysis,
    required this.kpis,
    required this.findings,
    required this.feedback,
    required this.metadata,
  });

  final String schemaVersion;
  final DateTime generatedAt;

  /// Section A: report basic info (game/tester counts, rulesVersion list,
  /// mode, actions-loaded count, etc.) — never includes a raw testerId.
  final Map<String, Object?> reportInfo;
  final Map<String, Object?> filters;
  final Map<String, Object?> summary;
  final Map<String, Object?> balance;
  final Map<String, Object?> ratings;
  final Map<String, Object?> eyeAnalysis;
  final Map<String, Object?> judgeAnalysis;
  final Map<String, Object?> reverseAnalysis;
  final Map<String, Object?> firstGameComparison;

  /// Keyed by cpuDifficulty value; only difficulties actually present in
  /// the analyzed pool appear here (section I: "存在する難易度だけ出力").
  final Map<String, Object?> cpuDifficultyAnalysis;

  final List<Map<String, Object?>> kpis;
  final List<AnalysisFinding> findings;

  /// Section J: anonymized feedback entries — never a raw testerId/
  /// firebaseUid/email (section 9).
  final List<Map<String, Object?>> feedback;

  /// Admin-only technical info (section 15): failedActionGameCount /
  /// failedGameIds, so a partial detailed-analysis fetch never blocks
  /// report generation.
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'reportSchemaVersion': schemaVersion,
    'generatedAt': generatedAt.toIso8601String(),
    'reportInfo': reportInfo,
    'filters': filters,
    'summary': summary,
    'balance': balance,
    'ratings': ratings,
    'eyeAnalysis': eyeAnalysis,
    'judgeAnalysis': judgeAnalysis,
    'reverseAnalysis': reverseAnalysis,
    'firstGameComparison': firstGameComparison,
    'cpuDifficultyAnalysis': cpuDifficultyAnalysis,
    'kpis': kpis,
    'findings': findings.map((f) => f.toJson()).toList(),
    'feedback': feedback,
    'metadata': metadata,
  };
}
