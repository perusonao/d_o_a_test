import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_finding.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_report.dart';

/// Section 6: builds the Markdown report meant to be pasted directly into
/// ChatGPT/Claude — a human-readable rendering of the same [AnalysisReport]
/// [AnalysisReport.toJson] produces, ending with the fixed analysis-request
/// prompt the task specifies verbatim.
String buildMarkdownReport(AnalysisReport report) {
  String pct(Object? v) => v == null ? '-' : '${((v as num) * 100).toStringAsFixed(1)}%';
  String fixed(Object? v) => v == null ? '-' : (v as num).toStringAsFixed(2);
  String text(Object? v) => v == null ? '-' : '$v';

  final info = report.reportInfo;
  final summary = report.summary;
  final balance = report.balance;
  final ratings = report.ratings['overall']! as Map<String, Object?>;
  final eye = report.eyeAnalysis;
  final judge = report.judgeAnalysis;
  final reverse = report.reverseAnalysis;
  final firstGame = report.firstGameComparison;

  final buffer = StringBuffer()
    ..writeln('# Nine Verdicts 外部テスト分析')
    ..writeln()
    ..writeln('生成日時: ${report.generatedAt.toIso8601String()}')
    ..writeln()
    ..writeln('レポートはこの端末内で生成されます。外部AIへ自動送信されません。')
    ..writeln();

  buffer
    ..writeln('## 分析条件')
    ..writeln('- 対象ゲーム数: ${info['gameCount']}')
    ..writeln('- 対象ユニークtesterId数: ${info['uniqueTesterCount']}')
    ..writeln('- 対象期間: ${text(info['periodStart'])} 〜 ${text(info['periodEnd'])}')
    ..writeln('- rulesVersion: ${(info['rulesVersions'] as List).join(', ')}')
    ..writeln('- gameVersion: ${(info['gameVersions'] as List).join(', ')}')
    ..writeln('- testCohort: ${(info['testCohorts'] as List).join(', ')}')
    ..writeln('- 分析モード: ${info['analysisMode']}')
    ..writeln('- actions取得済みゲーム数: ${info['actionsLoadedGameCount']}')
    ..writeln('- 欠損データ件数: ${info['missingDataCount']}')
    ..writeln(
      '- ワンサイドゲームの定義: 得点差${balance['oneSidedThreshold']}点以上'
      '(tool/run_external_test_analysis.dartの既定値を再利用)',
    )
    ..writeln();

  buffer
    ..writeln('## エグゼクティブサマリー')
    ..writeln('- 総ゲーム数: ${summary['totalGames']} / '
        'ユニークプレイヤー数: ${summary['uniqueTesterCount']}')
    ..writeln(
      '- 初回プレイヤー ${summary['firstTimePlayerCount']} / '
      'リピーター ${summary['repeaterCount']}',
    )
    ..writeln(
      '- 救済者勝率 ${pct(balance['saviorWinRate'])} / '
      '執行者勝率 ${pct(balance['executorWinRate'])} / '
      '先手勝率 ${pct(balance['firstPlayerWinRate'])}',
    )
    ..writeln(
      '- 平均ターン ${fixed(summary['avgTurns'])} / '
      '平均得点差 ${fixed(summary['avgScoreDiff'])} / '
      'ワンサイド率 ${pct(balance['oneSidedRate'])}',
    )
    ..writeln();

  buffer
    ..writeln('## 全体統計')
    ..writeln('| 指標 | 値 |')
    ..writeln('|---|---|')
    ..writeln('| 総ゲーム数 | ${summary['totalGames']} |')
    ..writeln('| ユニークプレイヤー数 | ${summary['uniqueTesterCount']} |')
    ..writeln('| 初回プレイヤー数 | ${summary['firstTimePlayerCount']} |')
    ..writeln('| リピーター数 | ${summary['repeaterCount']} |')
    ..writeln('| 平均playNumber | ${fixed(summary['avgPlayNumber'])} |')
    ..writeln('| 平均ゲーム時間(分) | ${fixed(summary['avgGameDurationMinutes'])} |')
    ..writeln('| 平均ターン数 | ${fixed(summary['avgTurns'])} |')
    ..writeln('| 平均得点差 | ${fixed(summary['avgScoreDiff'])} |')
    ..writeln('| 中央値得点差 | ${fixed(summary['medianScoreDiff'])} |')
    ..writeln('| 最大得点差 | ${text(summary['maxScoreDiff'])} |')
    ..writeln(
      '| abandonment率 | ${pct(summary['abandonmentRate'])} (n=${summary['abandonmentSampleSize']}) |',
    )
    ..writeln('| allConfirmed率 | ${pct(summary['allConfirmedRate'])} |')
    ..writeln();
  buffer.writeln('endReason別件数:');
  (summary['endReasonCounts'] as Map).forEach((key, value) {
    buffer.writeln('- $key: $value件');
  });
  buffer.writeln();

  buffer
    ..writeln('## ゲームバランス')
    ..writeln('| 指標 | 値 |')
    ..writeln('|---|---|')
    ..writeln('| 救済者勝率 | ${pct(balance['saviorWinRate'])} |')
    ..writeln('| 執行者勝率 | ${pct(balance['executorWinRate'])} |')
    ..writeln('| 引き分け率 | ${pct(balance['drawRate'])} |')
    ..writeln('| 先手勝率 | ${pct(balance['firstPlayerWinRate'])} |')
    ..writeln('| 後手勝率 | ${pct(balance['secondPlayerWinRate'])} |')
    ..writeln('| プレイヤー勝率 | ${pct(balance['playerWinRate'])} |')
    ..writeln('| CPU勝率 | ${pct(balance['cpuWinRate'])} |')
    ..writeln('| 勝者平均得点 | ${fixed(balance['avgWinnerScore'])} |')
    ..writeln('| 救済者平均得点 | ${fixed(balance['avgSaviorScore'])} |')
    ..writeln('| 執行者平均得点 | ${fixed(balance['avgExecutorScore'])} |')
    ..writeln(
      '| ワンサイド率(${balance['oneSidedThreshold']}点以上) | ${pct(balance['oneSidedRate'])} |',
    )
    ..writeln();
  buffer.writeln('playerFaction別勝率:');
  (balance['winRateByPlayerFaction'] as Map).forEach((k, v) {
    buffer.writeln('- $k: ${pct(v)}');
  });
  buffer.writeln();
  buffer.writeln('cpuDifficulty別勝率(プレイヤー視点):');
  (balance['winRateByCpuDifficulty'] as Map).forEach((k, v) {
    buffer.writeln('- $k: ${pct(v)}');
  });
  buffer.writeln();

  buffer.writeln('## 評価結果');
  buffer.writeln('| 項目 | 平均 | 中央値 | n |');
  buffer.writeln('|---|---|---|---|');
  const ratingLabels = {
    'fun': '楽しさ',
    'reading': '読み合い',
    'luck': '運要素',
    'tempo': 'テンポ',
    'eyeChoice': 'EYEの選択',
    'ruleUnderstanding': 'ルール理解度',
    'judgeUsefulness': 'JUDGEの有用性',
    'eyeTension': 'EYEの緊張感',
    'strategicDepth': '戦略の深さ',
    'replayIntent': '再プレイ意向',
  };
  for (final entry in ratingLabels.entries) {
    final dist = ratings[entry.key]! as Map<String, Object?>;
    buffer.writeln(
      '| ${entry.value} | ${fixed(dist['average'])} | ${fixed(dist['median'])} | ${dist['n']} |',
    );
  }
  buffer.writeln();

  final ft = firstGame['firstTime']! as Map<String, Object?>;
  final ex = firstGame['experienced']! as Map<String, Object?>;
  buffer
    ..writeln('## 初回プレイヤーと経験者')
    ..writeln('| 指標 | 初回 | 経験者 |')
    ..writeln('|---|---|---|')
    ..writeln('| サンプル数 | ${ft['sampleSize']} | ${ex['sampleSize']} |')
    ..writeln(
      '| プレイヤー勝率 | ${pct(ft['playerWinRate'])} | ${pct(ex['playerWinRate'])} |',
    )
    ..writeln('| 平均ターン数 | ${fixed(ft['avgTurns'])} | ${fixed(ex['avgTurns'])} |')
    ..writeln(
      '| 平均ゲーム時間(分) | ${fixed(ft['avgGameDurationMinutes'])} | ${fixed(ex['avgGameDurationMinutes'])} |',
    )
    ..writeln(
      '| 平均得点差 | ${fixed(ft['avgScoreDiff'])} | ${fixed(ex['avgScoreDiff'])} |',
    )
    ..writeln(
      '| fun | ${fixed((ft['fun'] as Map)['average'])} | ${fixed((ex['fun'] as Map)['average'])} |',
    )
    ..writeln(
      '| ruleUnderstanding | ${fixed((ft['ruleUnderstanding'] as Map)['average'])} | '
      '${fixed((ex['ruleUnderstanding'] as Map)['average'])} |',
    )
    ..writeln(
      '| replayIntent | ${fixed((ft['replayIntent'] as Map)['average'])} | '
      '${fixed((ex['replayIntent'] as Map)['average'])} |',
    )
    ..writeln(
      '| abandonment率 | ${pct(ft['abandonmentRate'])} | ${pct(ex['abandonmentRate'])} |',
    )
    ..writeln();

  buffer
    ..writeln('## EYE分析')
    ..writeln('(actions取得済み ${eye['sampleSize']}件を対象)')
    ..writeln('- 平均EYE使用回数/ゲーム: ${fixed(eye['avgUsesPerGame'])}')
    ..writeln('- プレイヤー側平均: ${fixed(eye['avgUsesPerGamePlayerSide'])}')
    ..writeln('- CPU側平均: ${fixed(eye['avgUsesPerGameCpuSide'])}')
    ..writeln('- 上限まで使い切った率: ${pct(eye['usedUpToCapRate'])}')
    ..writeln('- 平均候補数: ${fixed(eye['avgCandidateCount'])}')
    ..writeln('- 候補数=1の率: ${pct(eye['candidateCountOneRate'])}')
    ..writeln('- 平均決定時間(ms): ${fixed(eye['avgDecisionTimeMs'])}')
    ..writeln('- EYE使用者の勝率: ${pct(eye['eyeUserWinRate'])}')
    ..writeln('- 両陣営が同一対象をEYEした件数: ${eye['bothFactionsSameTargetGames']}')
    ..writeln();

  buffer
    ..writeln('## JUDGE分析')
    ..writeln('- savior使用率: ${pct(judge['saviorUsageRate'])}')
    ..writeln('- executor使用率: ${pct(judge['executorUsageRate'])}')
    ..writeln('- 両者未使用率: ${pct(judge['bothUnusedRate'])}')
    ..writeln('- プレイヤー使用率: ${pct(judge['playerUsageRate'])}')
    ..writeln('- CPU使用率: ${pct(judge['cpuUsageRate'])}')
    ..writeln('- 使用時平均ターン: ${fixed(judge['avgTurnOfUse'])}')
    ..writeln('- 使用時平均決定時間(ms): ${fixed(judge['avgDecisionTimeMsOfUse'])}')
    ..writeln(
      '- 高得点ボーナス(${judge['highBonusThreshold']}以上)を知りながら未使用: ${judge['highBonusUnusedCount']}件',
    )
    ..writeln('- JUDGE使用者の勝率: ${pct(judge['judgeUserWinRate'])}')
    ..writeln('- JUDGE未使用者の勝率: ${pct(judge['judgeNonUserWinRate'])}')
    ..writeln();

  buffer
    ..writeln('## reverse分析')
    ..writeln('- savior使用率: ${pct(reverse['saviorUsageRate'])}')
    ..writeln('- executor使用率: ${pct(reverse['executorUsageRate'])}')
    ..writeln('- 勝者側使用率: ${pct(reverse['winnerSideUsageRate'])}')
    ..writeln('- 敗者側使用率: ${pct(reverse['loserSideUsageRate'])}')
    ..writeln('- 両方未使用率: ${pct(reverse['neitherUsedRate'])}')
    ..writeln();

  buffer.writeln('## CPU難易度別');
  buffer.writeln('| 難易度 | ゲーム数 | プレイヤー勝率 | 平均ターン | fun |');
  buffer.writeln('|---|---|---|---|---|');
  report.cpuDifficultyAnalysis.forEach((key, value) {
    final v = value! as Map<String, Object?>;
    buffer.writeln(
      '| $key | ${v['gameCount']} | ${pct(v['playerWinRate'])} | '
      '${fixed(v['avgTurns'])} | ${fixed((v['fun'] as Map)['average'])} |',
    );
  });
  buffer.writeln();

  buffer.writeln('## KPI');
  buffer.writeln('| 指標 | 値 | サンプル数 | 目標 | 判定 |');
  buffer.writeln('|---|---|---|---|---|');
  for (final kpi in report.kpis) {
    buffer.writeln(
      '| ${kpi['metric']} | ${kpi['value']} | ${kpi['sampleSize']} | '
      '${kpi['target']} | ${kpi['status']}${kpi['reason'] != null ? ' (${kpi['reason']})' : ''} |',
    );
  }
  buffer.writeln();

  buffer.writeln('## 自由記述');
  if (report.feedback.isEmpty) {
    buffer.writeln('_自由記述はありません。_');
  } else {
    for (final f in report.feedback) {
      buffer
        ..writeln(
          '- **${f['anonymousPlayerLabel']}** (#${f['playNumber']}, '
          'fun=${f['fun'] ?? '-'}, rule=${f['ruleUnderstanding'] ?? '-'}, '
          'replay=${f['replayIntent'] ?? '-'})',
        )
        ..writeln('  > ${(f['feedbackComment'] ?? f['notes'] ?? '').toString().replaceAll('\n', '\n  > ')}');
    }
  }
  buffer.writeln();

  buffer.writeln('## 自動検出された注目点');
  if (report.findings.isEmpty) {
    buffer.writeln('_自動検出された注目点はありません。_');
  } else {
    for (final finding in report.findings) {
      buffer.writeln(
        '- **[${_severityLabel(finding.severity)}] ${finding.title}** — ${finding.description}',
      );
    }
  }
  buffer.writeln();

  buffer
    ..writeln('## AIに分析してほしいこと')
    ..writeln()
    ..writeln('---')
    ..writeln('以下のデータをNine Verdictsのゲームデザイナー視点で分析してください。')
    ..writeln()
    ..writeln('特に確認したい点:')
    ..writeln()
    ..writeln('1. 救済者と執行者のバランス')
    ..writeln('2. 先手・後手バランス')
    ..writeln('3. EYEの使用感と戦略性')
    ..writeln('4. JUDGEが適切に使われているか')
    ..writeln('5. reverseカードの価値')
    ..writeln('6. 初回プレイヤーの理解度')
    ..writeln('7. ゲームテンポ')
    ..writeln('8. リプレイ意欲')
    ..writeln('9. CPU難易度')
    ..writeln('10. 次に優先して改善すべき点')
    ..writeln()
    ..writeln('回答では以下を分けてください。')
    ..writeln()
    ..writeln('- データから確認できる事実')
    ..writeln('- 推測')
    ..writeln('- 改善候補')
    ..writeln('- すぐ変更すべきでない要素')
    ..writeln('- 追加で収集すべきデータ')
    ..writeln()
    ..writeln('サンプル数が少ない場合は、')
    ..writeln('断定せず暫定傾向として扱ってください。')
    ..writeln('---');

  return buffer.toString();
}

String _severityLabel(FindingSeverity severity) => switch (severity) {
  FindingSeverity.info => 'INFO',
  FindingSeverity.watch => 'WATCH',
  FindingSeverity.warning => 'WARNING',
  FindingSeverity.critical => 'CRITICAL',
};
