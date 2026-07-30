import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/browser_download.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_exporter.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:flutter/material.dart';

/// Sections 4/5/6/10: aggregate results, per-card usage, per-bonus analysis,
/// and CSV/JSON export for one completed [SimulationRun].
class SimulationResultsView extends StatelessWidget {
  const SimulationResultsView({required this.run, super.key});

  final SimulationRun run;

  @override
  Widget build(BuildContext context) {
    final stats = run.statistics.toJson();
    final scores = [
      for (final result in run.results) ...[
        result.saviorScore,
        result.executorScore,
      ],
    ];
    final games = run.results.length;
    final draws = run.results.where((r) => r.winner == null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          title: '④ 集計結果',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('救済者勝率', _pct(stats['saviorWinRate'])),
              _statRow('執行者勝率', _pct(stats['executorWinRate'])),
              _statRow('引き分け率', _pct(draws / (games == 0 ? 1 : games))),
              _statRow('平均ターン数', _num(stats['averageTurns'])),
              _statRow(
                '平均得点(救済者/執行者)',
                '${_num(stats['averageSaviorScore'])} / '
                    '${_num(stats['averageExecutorScore'])}',
              ),
              _statRow(
                '最高得点/最低得点',
                scores.isEmpty
                    ? '-'
                    : '${scores.reduce((a, b) => a > b ? a : b)} / '
                          '${scores.reduce((a, b) => a < b ? a : b)}',
              ),
              _statRow(
                '平均計算時間(1戦あたり・実プレイ時間ではありません)',
                games == 0
                    ? '-'
                    : '${(run.elapsed.inMilliseconds / games).toStringAsFixed(1)}ms',
              ),
              if ((stats['turnLimitReachedRate']! as double) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠ ターン上限で打ち切られたゲーム: '
                    '${_pct(stats['turnLimitReachedRate'])}\n'
                    '未検証のルール組み合わせでは、既存CPUのロジックが'
                    '対応しきれず決着しないことがあります(ルール自体の'
                    'バランスではなくCPU側の限界を示しています)。',
                    key: const Key('simulation-timeout-warning'),
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: '⑤ カード使用率',
          child: _CardUsageTable(
            cardUsage: stats['cardUsage']! as Map<String, Object>,
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: '⑥ ボーナス分析',
          child: _BonusAnalysisTable(
            bonusAnalysis: stats['bonusAnalysis']! as Map<String, Object>,
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: '⑩ エクスポート',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('simulation-export-csv'),
                onPressed: () => downloadTextFile(
                  filename: 'simulation_results.csv',
                  content: SimulationExporter.resultsCsv(run),
                  mimeType: 'text/csv',
                ),
                icon: const Icon(Icons.table_chart),
                label: const Text('CSVをダウンロード'),
              ),
              OutlinedButton.icon(
                key: const Key('simulation-export-json'),
                onPressed: () => downloadTextFile(
                  filename: 'simulation_summary.json',
                  content: SimulationExporter.summaryJson(run),
                  mimeType: 'application/json',
                ),
                icon: const Icon(Icons.description),
                label: const Text('JSONをダウンロード'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  static String _pct(Object? value) =>
      '${((value! as num) * 100).toStringAsFixed(1)}%';

  static String _num(Object? value) => (value! as num).toStringAsFixed(2);
}

class _CardUsageTable extends StatelessWidget {
  const _CardUsageTable({required this.cardUsage});
  final Map<String, Object> cardUsage;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _TableHeader(['カード', '使用回数', '使用率', '使用時勝率']),
      for (final entry in cardUsage.entries)
        _CardUsageRow(name: entry.key, data: entry.value as Map<String, Object>),
    ],
  );
}

class _CardUsageRow extends StatelessWidget {
  const _CardUsageRow({required this.name, required this.data});
  final String name;
  final Map<String, Object> data;

  @override
  Widget build(BuildContext context) {
    final winRate = data['winRateWhenUsed']! as double;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  '${data['timesUsedTotal']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  '${(((data['gamesUsedRate']! as double)) * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  '${(winRate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _Bar(value: winRate, color: Colors.tealAccent),
        ],
      ),
    );
  }
}

class _BonusAnalysisTable extends StatelessWidget {
  const _BonusAnalysisTable({required this.bonusAnalysis});
  final Map<String, Object> bonusAnalysis;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _TableHeader(['ボーナス', '救済者/執行者獲得数', '獲得時勝率']),
      for (var bonus = 1; bonus <= 9; bonus++)
        _BonusRow(
          bonus: bonus,
          data: bonusAnalysis['$bonus']! as Map<String, Object>,
        ),
    ],
  );
}

class _BonusRow extends StatelessWidget {
  const _BonusRow({required this.bonus, required this.data});
  final int bonus;
  final Map<String, Object> data;

  @override
  Widget build(BuildContext context) {
    final winRate = data['winRateWhenCaptured']! as double;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$bonus',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${data['saviorCaptures']} / ${data['executorCaptures']}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              '${(winRate * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.labels);
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        for (final label in labels)
          Expanded(
            flex: label == labels.first ? 2 : 1,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Section 5's "可能であれば棒グラフ" — a plain proportional bar, no charting
/// dependency needed.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 4,
      backgroundColor: Colors.white12,
      color: color,
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
