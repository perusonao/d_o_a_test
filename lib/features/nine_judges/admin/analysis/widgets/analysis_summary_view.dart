import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_report.dart';
import 'package:flutter/material.dart';

/// Section 8's "サマリー" preview tab — a compact read of the same data
/// the JSON/Markdown exports contain, for quickly sanity-checking a
/// generated report without leaving the app.
class AnalysisSummaryView extends StatelessWidget {
  const AnalysisSummaryView({required this.report, super.key});

  final AnalysisReport report;

  @override
  Widget build(BuildContext context) {
    String pct(Object? v) => v == null ? '-' : '${((v as num) * 100).toStringAsFixed(1)}%';
    String fixed(Object? v) => v == null ? '-' : (v as num).toStringAsFixed(2);

    final info = report.reportInfo;
    final summary = report.summary;
    final balance = report.balance;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );

    return ListView(
      key: const Key('analysis-summary-view'),
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          '対象ゲーム数 ${info['gameCount']} / '
          'ユニークプレイヤー ${info['uniqueTesterCount']} / '
          'モード: ${info['analysisMode']}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        row('平均ターン数', fixed(summary['avgTurns'])),
        row('平均得点差', fixed(summary['avgScoreDiff'])),
        row('中央値得点差', fixed(summary['medianScoreDiff'])),
        row('救済者勝率', pct(balance['saviorWinRate'])),
        row('執行者勝率', pct(balance['executorWinRate'])),
        row('先手勝率', pct(balance['firstPlayerWinRate'])),
        row('プレイヤー勝率', pct(balance['playerWinRate'])),
        row('ワンサイド率', pct(balance['oneSidedRate'])),
        row(
          'abandonment率',
          '${pct(summary['abandonmentRate'])} (n=${summary['abandonmentSampleSize']})',
        ),
        const SizedBox(height: 12),
        Text(
          'KPI: ${report.kpis.where((k) => k['status'] == 'PASS').length} PASS / '
          '${report.kpis.where((k) => k['status'] == 'WATCH').length} WATCH / '
          '${report.kpis.where((k) => k['status'] == 'FAIL').length} FAIL / '
          '${report.kpis.where((k) => k['status'] == 'DATA_INSUFFICIENT').length} 判定不可',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          '自動検出された注目点: ${report.findings.length}件 / '
          '自由記述: ${report.feedback.length}件',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
