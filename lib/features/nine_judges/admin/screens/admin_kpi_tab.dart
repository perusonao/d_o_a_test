import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_kpi.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/eye_judge_reverse_analysis.dart';
import 'package:dead_or_alive/features/nine_judges/analysis/external_test_report.dart';
import 'package:flutter/material.dart';

/// Section 17 (KPI, reusing tool/run_external_test_analysis.dart's exact
/// logic) plus, to the extent computable without violating section 12/23's
/// "never bulk-fetch actions" rule, sections 14-16's EYE/JUDGE/reverse
/// analysis (see eye_judge_reverse_analysis.dart's doc comments for exactly
/// which figures need actions to already be loaded vs. which don't).
class AdminKpiTab extends StatelessWidget {
  const AdminKpiTab({
    required this.records,
    this.tutorialCompletionCount,
    this.tutorialCompletionFailed = false,
    super.key,
  });

  final List<PlaytestRecord> records;

  /// A durable, cross-device count of users who completed the tutorial
  /// (see AdminPlaytestRepository.fetchTutorialCompletionCount) — null
  /// while still loading (or if the caller never fetches it).
  final int? tutorialCompletionCount;

  /// True once a fetch for [tutorialCompletionCount] has failed — shown
  /// distinctly from "still loading" so this KPI can't be misread as 0.
  final bool tutorialCompletionFailed;

  @override
  Widget build(BuildContext context) {
    // Section (this round): a durable, cross-device count of users who
    // completed the tutorial, independent of whether they ever submitted a
    // playtest — so it's always shown, even when [records] is empty.
    final tutorialCard = Card(
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.school_outlined, color: Colors.white38),
        title: const Text(
          'チュートリアル完了ユーザー数',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        subtitle: Text(
          tutorialCompletionFailed
              ? '取得に失敗しました'
              : (tutorialCompletionCount == null
                    ? '取得中…'
                    : '$tutorialCompletionCount 人が完了'),
          key: const Key('tutorial-completion-count'),
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ),
    );

    if (records.isEmpty) {
      return ListView(
        key: const Key('admin-kpi-list'),
        padding: const EdgeInsets.all(12),
        children: [
          tutorialCard,
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'データがありません(0件)',
              key: Key('admin-kpi-empty'),
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }
    final report = buildAdminKpiReport(records);
    final eye = EyeAnalysis.compute(records);
    final judge = JudgeAnalysis.compute(records);
    final reverse = ReverseAnalysis.compute(records);

    String pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';
    String fixed(double? v) => v == null ? '-' : v.toStringAsFixed(2);

    return ListView(
      key: const Key('admin-kpi-list'),
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          kpiSampleSizeGuidance(report.uniqueTesterCount),
          style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final kpi in report.kpis)
          Card(
            color: Colors.white10,
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: _VerdictBadge(verdict: kpi.verdict),
              title: Text(kpi.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text(
                '値: ${kpi.value}  目標: ${kpi.target}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          ),
        const SizedBox(height: 8),
        tutorialCard,
        const SizedBox(height: 16),
        const _SectionTitle('EYE分析'),
        Text(
          'actions取得済みのゲームのみ集計対象(現在${eye.sampleSize}/${records.length}件)',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        _row('平均EYE使用回数/ゲーム', fixed(eye.avgUsesPerGame)),
        _row('平均EYE使用回数(プレイヤー側)', fixed(eye.avgUsesPerGamePlayerSide)),
        _row('平均EYE使用回数(CPU側)', fixed(eye.avgUsesPerGameCpuSide)),
        _row('上限まで使用した割合(rules1.2)', pct(eye.usedUpToCapRate)),
        _row('平均EYE候補数', fixed(eye.avgCandidateCount)),
        _row('候補数=1の割合', pct(eye.candidateCountOneRate)),
        _row('平均決定時間(ms)', fixed(eye.avgDecisionTimeMs)),
        _row(
          '中央3マスの選択数',
          eye.selectionCountByCenterPosition.isEmpty
              ? 'データ不足'
              : eye.selectionCountByCenterPosition.entries
                    .map((e) => '位置${e.key + 1}:${e.value}')
                    .join(' / '),
        ),
        _row('両陣営が同一対象をEYEしたゲーム数', '${eye.bothFactionsSameTargetGames}'),
        const SizedBox(height: 16),
        const _SectionTitle('JUDGE分析'),
        _row('savior使用率', pct(judge.saviorUsageRate)),
        _row('executor使用率', pct(judge.executorUsageRate)),
        _row('両者未使用率', pct(judge.bothUnusedRate)),
        _row('使用ゲーム数', '${judge.usedGamesCount}'),
        _row('未使用ゲーム数', '${judge.unusedGamesCount}'),
        _row('平均JUDGE機会数(savior)', fixed(judge.avgOpportunityCountSavior)),
        _row('平均JUDGE機会数(executor)', fixed(judge.avgOpportunityCountExecutor)),
        _row('平均可視ボーナス最大値', fixed(judge.avgMaxVisibleBonusWhileAvailable)),
        _row(
          '高ボーナス到達率(閾値${JudgeAnalysis.highBonusThreshold}以上)',
          pct(judge.highBonusRate),
        ),
        _row(
          '使用時の平均ターン',
          judge.turnOfUseSampleSize == 0 ? '記録なし' : fixed(judge.avgTurnOfUse),
        ),
        _row(
          '使用時の平均決定時間(ms)',
          judge.avgDecisionTimeMsOfUse == null ? '記録なし' : fixed(judge.avgDecisionTimeMsOfUse),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('逆転の一手 分析'),
        _row('savior使用率', pct(reverse.saviorUsageRate)),
        _row('executor使用率', pct(reverse.executorUsageRate)),
        _row('両者未使用率', pct(reverse.neitherUsedRate)),
        _row('勝者側の使用率', pct(reverse.winnerSideUsageRate)),
        _row('敗者側の使用率', pct(reverse.loserSideUsageRate)),
        _row(
          '使用時の平均ターン',
          reverse.avgTurnUsedSampleSize == 0 ? '記録なし' : fixed(reverse.avgTurnUsed),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
    ),
  );
}

class _VerdictBadge extends StatelessWidget {
  const _VerdictBadge({required this.verdict});
  final KpiVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (verdict) {
      KpiVerdict.pass => (Colors.greenAccent, 'PASS'),
      KpiVerdict.watch => (Colors.amberAccent, 'WATCH'),
      KpiVerdict.fail => (Colors.redAccent, 'FAIL'),
      KpiVerdict.noData => (Colors.white38, 'N/A'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
