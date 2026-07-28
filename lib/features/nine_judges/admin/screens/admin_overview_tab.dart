import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_overview_stats.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/cohort_comparison.dart';
import 'package:flutter/material.dart';

/// Section 6/7/8: overview dashboard cards + first-time vs experienced
/// comparison. Purely derived from currently-loaded [records] — never
/// issues its own Firestore reads.
class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({required this.records, super.key});

  final List<PlaytestRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Text(
          'データがありません(0件)',
          key: Key('admin-overview-empty'),
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final stats = AdminOverviewStats.compute(
      records.map((r) => r.session).toList(),
    );
    final cohorts = FirstTimeVsExperienced.compute(records);

    String pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';
    String fixed(double? v) => v == null ? '-' : v.toStringAsFixed(2);

    final cards = <_Card>[
      _Card('総ゲーム数', '${stats.totalGames}'),
      _Card('ユニークtesterId数', '${stats.uniqueTesterCount}'),
      _Card('初回プレイヤー数', '${stats.firstTimePlayerCount}'),
      _Card('リピーター数', '${stats.repeaterCount}'),
      _Card('平均playNumber', fixed(stats.avgPlayNumber)),
      _Card('平均ターン数', fixed(stats.avgTurns)),
      _Card('平均スコア差', fixed(stats.avgScoreDiff)),
      _Card('救済者(savior)勝率', pct(stats.saviorWinRate)),
      _Card('執行者(executor)勝率', pct(stats.executorWinRate)),
      _Card('先手勝率', pct(stats.firstPlayerWinRate)),
      _Card('後手勝率', pct(stats.secondPlayerWinRate)),
      _Card('平均プレイ時間(分)', fixed(stats.avgGameDurationMinutes)),
      _Card(
        '離脱率',
        stats.abandonmentSampleSize == 0
            ? 'データ不足'
            : '${pct(stats.abandonmentRate)} (n=${stats.abandonmentSampleSize})',
      ),
    ];

    return ListView(
      key: const Key('admin-overview-list'),
      padding: const EdgeInsets.all(12),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [for (final c in cards) c],
            );
          },
        ),
        const SizedBox(height: 16),
        const _SectionTitle('評価アンケート平均(nullは分母から除外)'),
        for (final key in AdminOverviewStats.ratingKeys)
          _RatingRow(
            label: AdminOverviewStats.ratingLabels[key]!,
            rating: stats.ratings[key]!,
          ),
        const SizedBox(height: 16),
        const _SectionTitle('初回プレイヤー vs 経験者の比較'),
        _CohortComparisonTable(cohorts: cohorts),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.label, required this.rating});
  final String label;
  final RatingAverage rating;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(
          child: Text(
            rating.average == null
                ? 'データ不足'
                : '${rating.average!.toStringAsFixed(1)}/5  n=${rating.n}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _CohortComparisonTable extends StatelessWidget {
  const _CohortComparisonTable({required this.cohorts});
  final FirstTimeVsExperienced cohorts;

  @override
  Widget build(BuildContext context) {
    String pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';
    String fixed(double? v) => v == null ? '-' : v.toStringAsFixed(2);
    String ratingText(RatingAverage r) =>
        r.average == null ? 'データ不足' : '${r.average!.toStringAsFixed(1)} (n=${r.n})';

    Widget row(String label, String first, String experienced) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white60)),
          ),
          Expanded(child: Text(first, style: const TextStyle(color: Colors.white))),
          Expanded(
            child: Text(experienced, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    final f = cohorts.firstTime;
    final e = cohorts.experienced;
    if (!f.hasEnoughData && !e.hasEnoughData) {
      return const Text('データ不足', style: TextStyle(color: Colors.white70));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('', '初回 (n=${f.sampleSize})', '経験者 (n=${e.sampleSize})'),
        const Divider(color: Colors.white24),
        row('楽しさ', ratingText(f.fun), ratingText(e.fun)),
        row('ルール理解度', ratingText(f.ruleUnderstanding), ratingText(e.ruleUnderstanding)),
        row('EYEの緊張感', ratingText(f.eyeTension), ratingText(e.eyeTension)),
        row('戦略の深さ', ratingText(f.strategicDepth), ratingText(e.strategicDepth)),
        row('再プレイ意向', ratingText(f.replayIntent), ratingText(e.replayIntent)),
        row('平均ターン数', fixed(f.avgTurns), fixed(e.avgTurns)),
        row('平均スコア差', fixed(f.avgScoreDiff), fixed(e.avgScoreDiff)),
        row('プレイヤー勝率', pct(f.playerWinRate), pct(e.playerWinRate)),
        row('JUDGE使用率', pct(f.judgeUsageRate), pct(e.judgeUsageRate)),
        row(
          '平均EYE使用回数',
          f.avgEyeUsage == null ? 'データ不足' : '${fixed(f.avgEyeUsage)} (n=${f.avgEyeUsageSampleSize})',
          e.avgEyeUsage == null ? 'データ不足' : '${fixed(e.avgEyeUsage)} (n=${e.avgEyeUsageSampleSize})',
        ),
      ],
    );
  }
}
