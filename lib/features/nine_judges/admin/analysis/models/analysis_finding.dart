/// Section L: rule-based, automatically-detected notable points. Never a
/// substitute for human judgement — [severity]/[description] deliberately
/// hedge when [sampleSize] is small (see the callers in
/// external_test_analysis_service.dart).
enum FindingSeverity { info, watch, warning, critical }

class AnalysisFinding {
  const AnalysisFinding({
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    required this.metric,
    this.value,
    this.comparison,
    required this.sampleSize,
  });

  final FindingSeverity severity;
  final String category;
  final String title;
  final String description;
  final String metric;
  final Object? value;

  /// e.g. "45-55%が目安" — what [value] is being compared against.
  final String? comparison;
  final int sampleSize;

  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'category': category,
    'title': title,
    'description': description,
    'metric': metric,
    'value': value,
    'comparison': comparison,
    'sampleSize': sampleSize,
  };
}
