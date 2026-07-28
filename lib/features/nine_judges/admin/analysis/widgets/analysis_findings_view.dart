import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_finding.dart';
import 'package:flutter/material.dart';

/// Section 8/L: the "注目点" preview tab — each auto-detected finding shown
/// with a severity badge (never color alone: the label text always says
/// INFO/WATCH/WARNING/CRITICAL too).
class AnalysisFindingsView extends StatelessWidget {
  const AnalysisFindingsView({required this.findings, super.key});

  final List<AnalysisFinding> findings;

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) {
      return const Center(
        child: Text(
          '自動検出された注目点はありません',
          key: Key('analysis-findings-empty'),
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      key: const Key('analysis-findings-list'),
      padding: const EdgeInsets.all(12),
      itemCount: findings.length,
      itemBuilder: (context, index) {
        final finding = findings[index];
        return Card(
          color: Colors.white10,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: _SeverityBadge(severity: finding.severity),
            title: Text(
              finding.title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              '${finding.description}\nカテゴリ: ${finding.category} / n=${finding.sampleSize}'
              '${finding.comparison != null ? ' / ${finding.comparison}' : ''}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});
  final FindingSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (severity) {
      FindingSeverity.info => (Colors.white54, 'INFO'),
      FindingSeverity.watch => (Colors.amberAccent, 'WATCH'),
      FindingSeverity.warning => (Colors.orangeAccent, 'WARNING'),
      FindingSeverity.critical => (Colors.redAccent, 'CRITICAL'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9)),
    );
  }
}
