import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayLogScreen extends StatefulWidget {
  const PlayLogScreen({required this.repository, super.key});
  final GameLogRepository repository;

  @override
  State<PlayLogScreen> createState() => _PlayLogScreenState();
}

class _PlayLogScreenState extends State<PlayLogScreen> {
  late Future<List<GameSession>> _games = widget.repository.listGames();

  void _reload() => setState(() => _games = widget.repository.listGames());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('プレイログ'),
      actions: [
        IconButton(
          key: const Key('export-all-logs'),
          tooltip: '全ログJSONを書き出す',
          onPressed: () async {
            final json = await widget.repository.exportAllGames();
            await Clipboard.setData(ClipboardData(text: json));
            if (mounted) _message('全ログJSONをクリップボードへ書き出しました');
          },
          icon: const Icon(Icons.file_download_outlined),
        ),
        IconButton(
          tooltip: '全件削除',
          onPressed: _confirmDeleteAll,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
    ),
    body: FutureBuilder<List<GameSession>>(
      future: _games,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final games = snapshot.data!;
        if (games.isEmpty) return const Center(child: Text('保存済みログはありません'));
        return Column(
          children: [
            _Statistics(games: games),
            Expanded(
              child: ListView.builder(
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  return ListTile(
                    key: Key('game-log-${game.gameId}'),
                    title: Text(
                      '${_date(game.startedAt)}  ${game.mode.toUpperCase()} '
                      '${game.cpuDifficulty}',
                    ),
                    subtitle: Text(
                      '${game.playerFaction} / 先攻 ${game.firstPlayer}\n'
                      '${game.winner?.toUpperCase()}  '
                      '${game.saviorScore ?? '-'} - ${game.executorScore ?? '-'}  '
                      '${game.totalTurns}ターン  ${game.endReason ?? ''}',
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayLogDetailScreen(
                          session: game,
                          repository: widget.repository,
                        ),
                      ),
                    ).then((_) => _reload()),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await widget.repository.deleteGame(game.gameId);
                        _reload();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全ログを削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('全件削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteAllGames();
      _reload();
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class PlayLogDetailScreen extends StatelessWidget {
  const PlayLogDetailScreen({
    required this.session,
    required this.repository,
    super.key,
  });
  final GameSession session;
  final GameLogRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ログ詳細'),
      actions: [
        IconButton(
          key: const Key('export-single-log-text'),
          tooltip: 'TXTをコピー',
          onPressed: () async {
            final text = await repository.exportGameText(session.gameId);
            await Clipboard.setData(ClipboardData(text: text));
          },
          icon: const Icon(Icons.text_snippet_outlined),
        ),
        IconButton(
          key: const Key('export-single-log'),
          tooltip: 'JSONを書き出す',
          onPressed: () async {
            final json = await repository.exportGame(session.gameId);
            await Clipboard.setData(ClipboardData(text: json));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSONをクリップボードへ書き出しました')),
              );
            }
          },
          icon: const Icon(Icons.data_object),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'rules ${session.rulesVersion} / game ${session.gameVersion}\n'
          '${session.winner?.toUpperCase()}  '
          '${session.saviorScore} - ${session.executorScore}  '
          '${session.totalTurns}ターン\n'
          '終了: ${session.endReason} / seed: ${session.seed}',
        ),
        _GameAnalysis(session: session),
        const Divider(),
        const Text('初期盤面', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          session.initialBoard
              .map(
                (p) => session.rulesVersion == '1.0'
                    ? '${p.positionIndex + 1}: ${p.personId} / ${p.attribute} / 審議中'
                    : '${p.positionIndex + 1}: ${p.attribute}${p.rank} '
                          '${p.initialAlive ? '生' : '死'}',
              )
              .join('\n'),
        ),
        const Divider(),
        const Text('最終盤面', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          session.finalBoard
              .map(
                (p) => session.rulesVersion == '1.0'
                    ? '${p.attribute} ${p.verdictState} '
                          '履歴[${p.verdictHistory.join(' → ')}] / '
                          '${p.scoringFaction} +${p.awardedBonus}'
                    : '${p.attribute}${p.rank} ${p.finalAlive == true ? '生' : '死'} '
                          '${p.judged == true ? '判決済み' : '未判決'} '
                          '${p.scoringFaction} +${p.scoreValue}',
              )
              .join('\n'),
        ),
        const Divider(),
        const Text('アクション履歴', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final action in session.actions)
          ListTile(
            dense: true,
            title: Text(
              'Turn ${action.turnNumber} ${action.faction} '
              '${action.actionType.toUpperCase()} → ${action.targetPersonId}',
            ),
            subtitle: Text(
              '${action.stateBefore} → ${action.stateAfter}'
              '${action.eyeResult == null ? '' : ' / EYE: ${action.eyeResult}'}',
            ),
          ),
        if (session.notes.isNotEmpty) ...[
          const Divider(),
          Text('メモ\n${session.notes}'),
        ],
      ],
    ),
  );
}

class _GameAnalysis extends StatelessWidget {
  const _GameAnalysis({required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    int uses(String type) =>
        session.actions.where((a) => a.actionType == type).length;
    if (session.rulesVersion == '1.0') {
      final confirmations = session.actions
          .where((action) => action.judgedAfter && !action.judgedBefore)
          .toList();
      final eyeFollowUps = session.actions.where((eye) {
        if (eye.actionType != 'eye') return false;
        return session.actions.any(
          (action) =>
              action.actionIndex > eye.actionIndex &&
              action.targetPersonId == eye.targetPersonId &&
              action.actionType != 'eye',
        );
      }).length;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(8),
        color: Colors.white10,
        child: Text(
          '使用 LIFE ${uses('life')} / DEATH ${uses('death')} / '
          'EYE ${uses('eye')} / 審判 ${uses('specialVerdict')}\n'
          '確定 ${confirmations.length}/9 / EYE後の介入 $eyeFollowUps\n'
          '獲得ボーナス合計 '
          '${(session.saviorScore ?? 0) + (session.executorScore ?? 0)}/45',
          style: const TextStyle(fontSize: 11),
        ),
      );
    }
    final judges = session.actions
        .where((a) => a.actionType == 'judge')
        .toList();
    final firstJudge = judges.isEmpty ? null : judges.first.turnNumber;
    final averageJudge = judges.isEmpty
        ? 0
        : judges.map((a) => a.turnNumber).reduce((a, b) => a + b) /
              judges.length;
    int judgedAtRank(int rank) => session.finalBoard
        .where((p) => p.rank == rank && p.judged == true)
        .length;
    var eyeFollowUps = 0;
    for (final eye in session.actions.where((a) => a.actionType == 'eye')) {
      if (session.actions.any(
        (a) =>
            a.actionIndex > eye.actionIndex &&
            a.targetPersonId == eye.targetPersonId &&
            a.actionType != 'eye',
      )) {
        eyeFollowUps++;
      }
    }
    final instantDeaths = session.actions
        .where(
          (a) =>
              a.actionType == 'death' &&
              a.stateBefore == 'dead' &&
              a.judgedAfter,
        )
        .length;
    final judgeContacts = <int>[
      for (final judge in judges)
        session.actions
            .where(
              (action) =>
                  action.actionIndex < judge.actionIndex &&
                  action.targetPersonId == judge.targetPersonId &&
                  action.actionType != 'judge',
            )
            .length,
    ];
    final averageContacts = judgeContacts.isEmpty
        ? 0
        : judgeContacts.reduce((a, b) => a + b) / judgeContacts.length;
    final reviewed = session.finalBoard
        .where(
          (person) => session.actions.any(
            (action) =>
                action.targetPersonId == person.personId &&
                action.underReviewAfter,
          ),
        )
        .length;
    final remaining = session.actions.isEmpty
        ? const {'life': 4, 'death': 4, 'eye': 4, 'judge': 6}
        : {
            for (final type in ['life', 'death', 'eye', 'judge'])
              type:
                  (session.actions.last.actorHandAfter[type] ?? 0) +
                  (session.actions.last.opponentHandAfter[type] ?? 0),
          };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      color: Colors.white10,
      child: Text(
        '使用 L${uses('life')} D${uses('death')} E${uses('eye')} J${uses('judge')}\n'
        '残り L${remaining['life']} D${remaining['death']} '
        'E${remaining['eye']} J${remaining['judge']}\n'
        '最初のJUDGE ${firstJudge == null ? '-' : 'Turn $firstJudge'} / '
        '平均 ${averageJudge.toStringAsFixed(1)}\n'
        '判決率 R1 ${judgedAtRank(1)}/3  R2 ${judgedAtRank(2)}/3  '
        'R3 ${judgedAtRank(3)}/3\n'
        'EYE後の操作 $eyeFollowUps / 死+DEATH即判決 $instantDeaths\n'
        'JUDGEまでの平均接触 ${averageContacts.toStringAsFixed(1)}回 / '
        '審議経験 $reviewed人 / 未判決 ${9 - session.finalBoard.where((p) => p.judged == true).length}人',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class _Statistics extends StatelessWidget {
  const _Statistics({required this.games});
  final List<GameSession> games;

  @override
  Widget build(BuildContext context) {
    final versions = games.map((game) => game.rulesVersion).toSet().toList()
      ..sort();
    int wins(String faction) => games.where((g) => g.winner == faction).length;
    double averageUses(String action) => games.isEmpty
        ? 0
        : games
                  .map(
                    (g) =>
                        g.actions.where((a) => a.actionType == action).length,
                  )
                  .reduce((a, b) => a + b) /
              games.length;
    final averageTurns =
        games.map((g) => g.totalTurns).reduce((a, b) => a + b) / games.length;
    final decisive = games.where((g) => g.winner != 'draw').toList();
    int firstWins = decisive.where((g) => g.winner == g.firstPlayer).length;
    int combinationWins(String faction, bool first) => games.where((g) {
      final factionFirst = g.firstPlayer == faction;
      return factionFirst == first && g.winner == faction;
    }).length;
    double averageRemaining(String action) {
      if (games.isEmpty) return 0;
      int remaining(GameSession game) {
        if (game.actions.isEmpty) return 9;
        final last = game.actions.last;
        return (last.actorHandAfter[action] ?? 0) +
            (last.opponentHandAfter[action] ?? 0);
      }

      return games.map(remaining).reduce((a, b) => a + b) / games.length;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: Colors.white10,
      child: Text(
        '総ゲーム ${games.length} / 救済者 ${wins('savior')} / '
        '執行者 ${wins('executor')} / 引分 ${wins('draw')}\n'
        '先手勝 ${decisive.isEmpty ? 0 : firstWins} / '
        '後手勝 ${decisive.length - firstWins}  '
        '救先 ${combinationWins('savior', true)} 救後 ${combinationWins('savior', false)} '
        '執先 ${combinationWins('executor', true)} 執後 ${combinationWins('executor', false)}\n'
        '平均 ${averageTurns.toStringAsFixed(1)}ターン  '
        'L ${averageUses('life').toStringAsFixed(1)}  '
        'D ${averageUses('death').toStringAsFixed(1)}  '
        'E ${averageUses('eye').toStringAsFixed(1)}  '
        'J ${averageUses('judge').toStringAsFixed(1)}\n'
        '平均残り L${averageRemaining('life').toStringAsFixed(1)} '
        'D${averageRemaining('death').toStringAsFixed(1)} '
        'E${averageRemaining('eye').toStringAsFixed(1)} '
        'J${averageRemaining('judge').toStringAsFixed(1)}\n'
        'ルール別: ${versions.map((v) => '$v=${games.where((g) => g.rulesVersion == v).length}件').join(' / ')}  '
        'ターン制限 ${games.where((g) => g.endReason == 'turnLimit').length}件  '
        'EYE未使用 ${games.where((g) => g.actions.every((a) => a.actionType != 'eye')).length}件',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
