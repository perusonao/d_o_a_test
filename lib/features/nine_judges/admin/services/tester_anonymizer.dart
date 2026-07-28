/// Maps raw `testerId` values to stable "Player 001"-style labels (section
/// 9): the raw id must never be shown directly. Uses the same
/// first-seen-order numbering scheme as
/// tool/run_external_test_analysis.dart's feedback-comment anonymization, so
/// the two tools read consistently. One instance is shared across a single
/// admin session's loaded pages, so a given testerId always maps to the same
/// label for as long as that data stays loaded.
class TesterAnonymizer {
  final Map<String, int> _index = {};

  String label(String? testerId) {
    final id = (testerId == null || testerId.isEmpty) ? 'unknown' : testerId;
    final index = _index.putIfAbsent(id, () => _index.length + 1);
    return 'Player ${index.toString().padLeft(3, '0')}';
  }

  /// For the individual game detail screen only (section 11), which may show
  /// a shortened — never full — testerId alongside the anonymized label.
  static String shortId(String? testerId) {
    if (testerId == null || testerId.isEmpty) return '-';
    return testerId.length <= 8 ? testerId : '${testerId.substring(0, 8)}…';
  }
}
