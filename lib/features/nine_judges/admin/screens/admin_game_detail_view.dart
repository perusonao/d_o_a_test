import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/action_log_formatter.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter/material.dart';

/// Section 11/12: individual game detail, including the lazily-fetched
/// action log (section 12). Only ever shows fields that actually exist on
/// [PlaytestRecord]/`GameSession` — nothing here is guessed.
class AdminGameDetailView extends StatelessWidget {
  const AdminGameDetailView({
    required this.record,
    required this.anonymizer,
    required this.actionsLoading,
    this.onViewTesterHistory,
    super.key,
  });

  final PlaytestRecord record;
  final TesterAnonymizer anonymizer;
  final bool actionsLoading;

  /// Opens this game's tester's complete match history (faction/first-or-
  /// second/result across every game, not just currently-loaded pages).
  /// Null (the default) hides the button entirely — used by callers that
  /// don't wire up navigation for it.
  final ValueChanged<String>? onViewTesterHistory;

  @override
  Widget build(BuildContext context) {
    final s = record.session;
    String date(DateTime? d) => d == null
        ? '-'
        : '${d.year}/${d.month.toString().padLeft(2, '0')}/'
              '${d.day.toString().padLeft(2, '0')} '
              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final duration = s.finishedAt?.difference(s.startedAt);

    return ListView(
      key: Key('admin-detail-${s.gameId}'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          s.gameId,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _kv('プレイヤー', anonymizer.label(s.testerId)),
        _kv('testerId(短縮)', TesterAnonymizer.shortId(s.testerId)),
        if (onViewTesterHistory != null && (s.testerId?.isNotEmpty ?? false))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('view-tester-history'),
              onPressed: () => onViewTesterHistory!(s.testerId!),
              icon: const Icon(Icons.history, size: 16),
              label: const Text('この人の全戦歴を見る'),
            ),
          ),
        _kv('playNumber', '${s.playNumber ?? '-'}'),
        _kv('isFirstGame', '${s.isFirstGame ?? '-'}'),
        _kv('testCohort', s.testCohort ?? '-'),
        _kv('buildCommitHash', s.buildCommitHash ?? '-'),
        const Divider(color: Colors.white24),
        _kv('開始', date(s.startedAt)),
        _kv('終了', date(s.finishedAt)),
        _kv(
          '所要時間',
          duration == null ? '-' : '${duration.inMinutes}分${duration.inSeconds % 60}秒',
        ),
        _kv('gameVersion', s.gameVersion),
        _kv('rulesVersion', s.rulesVersion),
        _kv('mode', s.mode),
        const Divider(color: Colors.white24),
        _kv('playerFaction', s.playerFaction),
        _kv('cpuFaction', s.cpuFaction),
        _kv('firstPlayer', s.firstPlayer),
        _kv('cpuDifficulty', s.cpuDifficulty),
        _kv('winner', s.winner ?? '-'),
        _kv('saviorScore', '${s.saviorScore ?? '-'}'),
        _kv('executorScore', '${s.executorScore ?? '-'}'),
        _kv('totalTurns', '${s.totalTurns}'),
        _kv('endReason', s.endReason ?? '-'),
        _kv('seed', '${s.seed}'),
        _kv('gameAbandoned', '${s.gameAbandoned ?? '記録なし'}'),
        const Divider(color: Colors.white24),
        const _SubTitle('評価アンケート'),
        _kv('楽しさ(fun)', '${s.funRating ?? '-'}'),
        _kv('読み合い(reading)', '${s.readingRating ?? '-'}'),
        _kv('運要素(luck)', '${s.luckRating ?? '-'}'),
        _kv('テンポ(tempo)', '${s.tempoRating ?? '-'}'),
        _kv('EYEの選択(eyeChoice)', '${s.eyeChoiceRating ?? '-'}'),
        _kv('ルール理解度', '${s.ruleUnderstandingRating ?? '-'}'),
        _kv('JUDGEの有用性', '${s.judgeUsefulnessRating ?? '-'}'),
        _kv('EYEの緊張感', '${s.eyeTensionRating ?? '-'}'),
        _kv('戦略の深さ', '${s.strategicDepthRating ?? '-'}'),
        _kv('再プレイ意向', '${s.replayIntentRating ?? '-'}'),
        if (s.notes.isNotEmpty) _kv('メモ', s.notes),
        if ((s.feedbackComment ?? '').isNotEmpty)
          _kv('自由記述', s.feedbackComment!),
        const Divider(color: Colors.white24),
        const _SubTitle('EYE/JUDGE/逆転の一手 (このゲームのみ)'),
        _kv(
          'JUDGE使用(savior/executor)',
          '${s.saviorSpecialVerdictUsed ?? '記録なし'} / ${s.executorSpecialVerdictUsed ?? '記録なし'}',
        ),
        _kv(
          'JUDGE機会数(savior/executor)',
          '${s.judgeOpportunityCountSavior ?? '記録なし'} / ${s.judgeOpportunityCountExecutor ?? '記録なし'}',
        ),
        _kv(
          '可視ボーナス最大(savior/executor)',
          '${s.maxVisibleBonusWhileJudgeAvailableSavior ?? '記録なし'} / '
              '${s.maxVisibleBonusWhileJudgeAvailableExecutor ?? '記録なし'}',
        ),
        _kv(
          '逆転の一手使用(savior/executor)',
          '${s.saviorReverseActionUsed ?? '記録なし'} / ${s.executorReverseActionUsed ?? '記録なし'}',
        ),
        _kv(
          '初期把握位置(savior)',
          s.initialKnownPositionsBySavior.isEmpty
              ? '-'
              : s.initialKnownPositionsBySavior.join(', '),
        ),
        _kv(
          '初期把握位置(executor)',
          s.initialKnownPositionsByExecutor.isEmpty
              ? '-'
              : s.initialKnownPositionsByExecutor.join(', '),
        ),
        const Divider(color: Colors.white24),
        const _SubTitle('初期盤面'),
        Text(
          s.initialBoard
              .map(
                (p) =>
                    '${p.positionIndex + 1}: ${p.attribute}${p.rank} '
                    '${p.initialAlive ? '生' : '死'}',
              )
              .join('\n'),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const _SubTitle('最終盤面'),
        s.finalBoard.isEmpty
            ? const Text('データなし', style: TextStyle(color: Colors.white38))
            : Text(
                s.finalBoard
                    .map(
                      (p) =>
                          '${p.attribute}${p.rank} '
                          '${p.finalAlive == true ? '生' : '死'} '
                          '${p.judged == true ? '判決済み' : '未判決'} '
                          '${p.scoringFaction ?? '-'} +${p.scoreValue ?? 0}',
                    )
                    .join('\n'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
        const Divider(color: Colors.white24),
        _SubTitle(
          'アクション履歴${record.actions == null ? '' : ' (${record.actions!.length}件)'}',
        ),
        if (actionsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (record.actions == null)
          const Text(
            'actions未取得です',
            style: TextStyle(color: Colors.white38),
          )
        else if (record.actions!.isEmpty)
          const Text('アクションがありません', style: TextStyle(color: Colors.white38))
        else
          for (final action in record.actions!)
            Card(
              key: Key('admin-action-${s.gameId}-${action.actionIndex}'),
              color: Colors.white10,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  ActionLogFormatter.icon(action),
                  color: Colors.white70,
                ),
                title: Text(
                  ActionLogFormatter.header(action),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                subtitle: Text(
                  ActionLogFormatter.detailLines(action).join('\n'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                isThreeLine: true,
              ),
            ),
      ],
    );
  }

  Widget _kv(String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(key, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );
}
