import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_game_detail_view.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_export_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_log_filters.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Section 9/10/11/19: paginated, filterable game log list with individual
/// game detail (side pane on wide screens, full-screen push on phones) and
/// JSON export of whatever is currently loaded.
class AdminLogsTab extends StatefulWidget {
  const AdminLogsTab({
    required this.records,
    required this.anonymizer,
    required this.hasMore,
    required this.loading,
    required this.onLoadMore,
    required this.onOpenDetail,
    this.onViewTesterHistory,
    super.key,
  });

  final List<PlaytestRecord> records;
  final TesterAnonymizer anonymizer;
  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;
  final Future<void> Function(PlaytestRecord record) onOpenDetail;

  /// Opens a tester's complete match history. Null hides the button on
  /// [AdminGameDetailView].
  final ValueChanged<String>? onViewTesterHistory;

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
  AdminLogFilters _filters = const AdminLogFilters();
  String? _selectedGameId;
  bool _detailLoading = false;

  List<PlaytestRecord> get _filtered => widget.records
      .where((r) => _filters.matches(r, widget.anonymizer.label(r.session.testerId)))
      .toList();

  Future<void> _openDetail(PlaytestRecord record) async {
    setState(() {
      _selectedGameId = record.gameId;
      _detailLoading = record.actions == null;
    });
    await widget.onOpenDetail(record);
    if (mounted) setState(() => _detailLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final list = _ListColumn(
          filtered: filtered,
          allCount: widget.records.length,
          anonymizer: widget.anonymizer,
          filters: _filters,
          onFiltersChanged: (f) => setState(() => _filters = f),
          hasMore: widget.hasMore,
          loading: widget.loading,
          onLoadMore: widget.onLoadMore,
          onOpenDetail: (record) async {
            if (wide) {
              await _openDetail(record);
              return;
            }
            await _openDetail(record);
            if (!context.mounted) return;
            final record0 = widget.records.firstWhere(
              (r) => r.gameId == record.gameId,
              orElse: () => record,
            );
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  backgroundColor: const Color(0xFF0B0B10),
                  appBar: AppBar(title: const Text('ゲーム詳細')),
                  body: AdminGameDetailView(
                    record: record0,
                    anonymizer: widget.anonymizer,
                    actionsLoading: false,
                    onViewTesterHistory: widget.onViewTesterHistory,
                  ),
                ),
              ),
            );
          },
          exportRecords: filtered,
        );
        if (!wide) return list;
        final selected = _selectedGameId == null
            ? null
            : widget.records.where((r) => r.gameId == _selectedGameId).firstOrNull;
        return Row(
          children: [
            SizedBox(width: constraints.maxWidth * 0.42, child: list),
            const VerticalDivider(width: 1, color: Colors.white24),
            Expanded(
              child: selected == null
                  ? const Center(
                      child: Text(
                        'ゲームを選択してください',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : AdminGameDetailView(
                      record: selected,
                      anonymizer: widget.anonymizer,
                      actionsLoading: _detailLoading,
                      onViewTesterHistory: widget.onViewTesterHistory,
                    ),
            ),
          ],
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ListColumn extends StatelessWidget {
  const _ListColumn({
    required this.filtered,
    required this.allCount,
    required this.anonymizer,
    required this.filters,
    required this.onFiltersChanged,
    required this.hasMore,
    required this.loading,
    required this.onLoadMore,
    required this.onOpenDetail,
    required this.exportRecords,
  });

  final List<PlaytestRecord> filtered;
  final int allCount;
  final TesterAnonymizer anonymizer;
  final AdminLogFilters filters;
  final ValueChanged<AdminLogFilters> onFiltersChanged;
  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;
  final ValueChanged<PlaytestRecord> onOpenDetail;
  final List<PlaytestRecord> exportRecords;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            OutlinedButton.icon(
              key: const Key('admin-open-filters'),
              onPressed: () => _openFilterSheet(context),
              icon: const Icon(Icons.filter_list, size: 18),
              label: const Text('フィルター'),
            ),
            const SizedBox(width: 8),
            if (filters.isActive)
              TextButton(
                key: const Key('admin-clear-filters'),
                onPressed: () => onFiltersChanged(const AdminLogFilters()),
                child: const Text('フィルターを解除'),
              ),
            const Spacer(),
            IconButton(
              key: const Key('admin-export-json'),
              tooltip: 'JSONを書き出す',
              onPressed: () => _export(context),
              icon: const Icon(Icons.file_download_outlined),
            ),
          ],
        ),
      ),
      if (filters.isActive)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '現在読み込み済みのデータ内で絞り込み中です',
              key: Key('admin-filter-scope-notice'),
              style: TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${filtered.length}/$allCount 件を表示',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ),
      Expanded(
        child: filtered.isEmpty
            ? const Center(
                child: Text('該当するログがありません', style: TextStyle(color: Colors.white38)),
              )
            : ListView.builder(
                key: const Key('admin-logs-list'),
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == filtered.length) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: hasMore
                            ? OutlinedButton(
                                key: const Key('admin-load-more'),
                                onPressed: loading ? null : onLoadMore,
                                child: Text(loading ? '読み込み中…' : 'さらに読み込む(+20)'),
                              )
                            : const Text(
                                '全件読み込み済みです',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                      ),
                    );
                  }
                  return _LogRow(
                    record: filtered[index],
                    label: anonymizer.label(filtered[index].session.testerId),
                    onTap: () => onOpenDetail(filtered[index]),
                  );
                },
              ),
      ),
    ],
  );

  Future<void> _export(BuildContext context) async {
    final message = AdminExportService.warningMessage(exportRecords);
    final json = AdminExportService.buildJson(exportRecords);
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$message ${AdminExportService.fileName(DateTime.now())} としてクリップボードへコピーしました',
          ),
        ),
      );
    }
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15151C),
      isScrollControlled: true,
      builder: (context) => _FilterSheet(filters: filters, onApply: onFiltersChanged),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record, required this.label, required this.onTap});

  final PlaytestRecord record;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = record.session;
    String date(DateTime? d) => d == null
        ? '-'
        : '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final hasComment = (s.feedbackComment ?? '').trim().isNotEmpty;
    return Card(
      key: Key('admin-log-row-${s.gameId}'),
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          '${date(s.finishedAt)}  $label  #${s.playNumber ?? '-'}  '
          '${s.playerFaction} vs ${s.cpuFaction}(${s.cpuDifficulty})',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        subtitle: Text(
          '先手:${s.firstPlayer} 勝者:${s.winner ?? '-'} '
          'S${s.saviorScore ?? '-'}-E${s.executorScore ?? '-'} '
          '${s.totalTurns}T ${s.endReason ?? '-'}\n'
          'rules${s.rulesVersion} / ${s.gameVersion}  '
          'fun:${s.funRating ?? '-'} rule:${s.ruleUnderstandingRating ?? '-'} '
          'replay:${s.replayIntentRating ?? '-'}',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        isThreeLine: true,
        trailing: hasComment ? const Icon(Icons.comment, color: Colors.white38, size: 18) : null,
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters, required this.onApply});
  final AdminLogFilters filters;
  final ValueChanged<AdminLogFilters> onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late AdminLogFilters _draft = widget.filters;
  late final _gameIdController = TextEditingController(text: widget.filters.gameId);
  late final _testerController = TextEditingController(text: widget.filters.testerLabel);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('フィルター', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('filter-game-id'),
            controller: _gameIdController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'gameId'),
            onChanged: (v) => _draft = _draft.copyWith(gameId: v),
          ),
          TextField(
            key: const Key('filter-tester-label'),
            controller: _testerController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Player番号 (例: 001)'),
            onChanged: (v) => _draft = _draft.copyWith(testerLabel: v),
          ),
          _dropdown('rulesVersion', _draft.rulesVersion, const ['1.0', '1.1', '1.2'],
              (v) => setState(() => _draft = _draft.copyWith(rulesVersion: v, clearRulesVersion: v == null))),
          _dropdown('playerFaction', _draft.playerFaction, const ['savior', 'executor'],
              (v) => setState(() => _draft = _draft.copyWith(playerFaction: v, clearPlayerFaction: v == null))),
          _dropdown('winner', _draft.winner, const ['savior', 'executor', 'draw'],
              (v) => setState(() => _draft = _draft.copyWith(winner: v, clearWinner: v == null))),
          _dropdown('firstPlayer', _draft.firstPlayer, const ['savior', 'executor'],
              (v) => setState(() => _draft = _draft.copyWith(firstPlayer: v, clearFirstPlayer: v == null))),
          _dropdown(
            'cpuDifficulty',
            _draft.cpuDifficulty,
            const ['random', 'balanced', 'aggressive', 'defensive', 'hard'],
            (v) => setState(
              () => _draft = _draft.copyWith(cpuDifficulty: v, clearCpuDifficulty: v == null),
            ),
          ),
          _boolTri('初回プレイのみ', _draft.isFirstGame,
              (v) => setState(() => _draft = _draft.copyWith(isFirstGame: v, clearIsFirstGame: v == null))),
          _boolTri(
            '自由記述あり',
            _draft.hasFeedbackComment,
            (v) => setState(
              () => _draft = _draft.copyWith(hasFeedbackComment: v, clearHasFeedbackComment: v == null),
            ),
          ),
          _boolTri(
            '評価入力あり',
            _draft.hasAnyRating,
            (v) => setState(
              () => _draft = _draft.copyWith(hasAnyRating: v, clearHasAnyRating: v == null),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                key: const Key('filter-sheet-clear'),
                onPressed: () {
                  widget.onApply(const AdminLogFilters());
                  Navigator.of(context).pop();
                },
                child: const Text('すべて解除'),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('filter-sheet-apply'),
                onPressed: () {
                  widget.onApply(_draft);
                  Navigator.of(context).pop();
                },
                child: const Text('適用'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _dropdown(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: DropdownButtonFormField<String?>(
      key: Key('filter-$label'),
      initialValue: value,
      dropdownColor: const Color(0xFF15151C),
      decoration: InputDecoration(labelText: label),
      style: const TextStyle(color: Colors.white),
      items: [
        const DropdownMenuItem(value: null, child: Text('指定なし')),
        for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    ),
  );

  Widget _boolTri(String label, bool? value, ValueChanged<bool?> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: DropdownButtonFormField<bool?>(
      key: Key('filter-tri-$label'),
      initialValue: value,
      dropdownColor: const Color(0xFF15151C),
      decoration: InputDecoration(labelText: label),
      style: const TextStyle(color: Colors.white),
      items: const [
        DropdownMenuItem(value: null, child: Text('指定なし')),
        DropdownMenuItem(value: true, child: Text('はい')),
        DropdownMenuItem(value: false, child: Text('いいえ')),
      ],
      onChanged: onChanged,
    ),
  );
}
