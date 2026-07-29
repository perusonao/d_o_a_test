import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter/material.dart';

/// One user's complete match history — faction played, first-or-second, and
/// win/loss/draw per game — fetched directly by `testerId` (see
/// AdminPlaytestRepository.fetchByTester) rather than filtering whatever the
/// dashboard's own pagination happens to have loaded so far.
class AdminTesterHistoryScreen extends StatefulWidget {
  const AdminTesterHistoryScreen({
    required this.repository,
    required this.anonymizer,
    required this.testerId,
    super.key,
  });

  final AdminPlaytestRepository repository;
  final TesterAnonymizer anonymizer;
  final String testerId;

  @override
  State<AdminTesterHistoryScreen> createState() =>
      _AdminTesterHistoryScreenState();
}

enum _LoadState { loading, loaded, error }

class _AdminTesterHistoryScreenState extends State<AdminTesterHistoryScreen> {
  _LoadState _state = _LoadState.loading;
  List<PlaytestRecord> _records = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final records = await widget.repository.fetchByTester(widget.testerId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _state = _LoadState.loaded;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = exception.toString();
        _state = _LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.anonymizer.label(widget.testerId);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(title: Text('$label の戦歴')),
      body: switch (_state) {
        _LoadState.loading => const Center(
          key: Key('tester-history-loading'),
          child: CircularProgressIndicator(),
        ),
        _LoadState.error => Center(
          child: Text(
            'データ取得エラー: $_error',
            key: const Key('tester-history-error'),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        _LoadState.loaded => _records.isEmpty
            ? const Center(
                child: Text(
                  '記録がありません(0件)',
                  key: Key('tester-history-empty'),
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : _HistoryList(
                records: _records,
                testerIdShort: TesterAnonymizer.shortId(widget.testerId),
              ),
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.records, required this.testerIdShort});

  final List<PlaytestRecord> records;
  final String testerIdShort;

  @override
  Widget build(BuildContext context) {
    final wins = records
        .where((r) => r.session.winner == r.session.playerFaction)
        .length;
    return ListView(
      key: const Key('tester-history-list'),
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'testerId(短縮): $testerIdShort　全${records.length}戦　勝ち$wins',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        for (final record in records) _HistoryRow(record: record),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final PlaytestRecord record;

  @override
  Widget build(BuildContext context) {
    final s = record.session;
    final factionLabel = s.playerFaction == 'savior' ? '救済者' : '執行者';
    final wentFirst = s.firstPlayer == s.playerFaction;
    final result = s.winner == null
        ? '未終了/引き分け'
        : (s.winner == s.playerFaction ? '勝ち' : '負け');
    final date = s.finishedAt ?? s.startedAt;

    return Card(
      key: Key('tester-history-row-${s.gameId}'),
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Text(
          '#${s.playNumber ?? '-'}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        title: Text(
          '$factionLabel　${wentFirst ? '先攻' : '後攻'}　$result',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        subtitle: Text(
          '${date.year}/${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}　'
          'スコア ${s.saviorScore ?? '-'} - ${s.executorScore ?? '-'}　'
          '${s.gameId}',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ),
    );
  }
}
