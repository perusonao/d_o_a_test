import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_filter.dart';
import 'package:flutter/material.dart';

/// Section 3/4/16: analysis-target selection, collapsible on phones (an
/// `ExpansionTile` collapses naturally on narrow screens without any
/// width-based branching needed).
class AnalysisFilterPanel extends StatelessWidget {
  const AnalysisFilterPanel({
    required this.filter,
    required this.onChanged,
    required this.onReset,
    super.key,
  });

  final AnalysisFilter filter;
  final ValueChanged<AnalysisFilter> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white10,
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: ExpansionTile(
      key: const Key('analysis-filter-panel'),
      title: const Text(
        '分析対象の選択',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${filter.source.label} / ${filter.mode.label}'
        '${filter.hasFieldFilters ? ' (絞り込みあり)' : ''}',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        const _SectionLabel('対象ソース'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final source in AnalysisSource.values)
              ChoiceChip(
                key: Key('analysis-source-${source.name}'),
                label: Text(source.label),
                selected: filter.source == source,
                onSelected: (_) => onChanged(filter.copyWith(source: source)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const _SectionLabel('分析モード'),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in AnalysisMode.values)
              ChoiceChip(
                key: Key('analysis-mode-${mode.name}'),
                label: Text(mode.label),
                selected: filter.mode == mode,
                onSelected: (_) => onChanged(filter.copyWith(mode: mode)),
              ),
          ],
        ),
        if (filter.mode == AnalysisMode.detailed)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '詳細分析ではactionsも追加取得するため、Firestoreの読み取り数が増加します。',
              key: Key('analysis-detailed-warning'),
              style: TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
          ),
        const Divider(color: Colors.white24, height: 24),
        const _SectionLabel('絞り込み(現在読み込み済み/取得済みのデータ内)'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _dropdown('rulesVersion', filter.rulesVersion, const ['1.0', '1.1', '1.2'],
                (v) => onChanged(filter.copyWith(rulesVersion: v, clearRulesVersion: v == null))),
            _dropdown(
              'playerFaction',
              filter.playerFaction,
              const ['savior', 'executor'],
              (v) => onChanged(
                filter.copyWith(playerFaction: v, clearPlayerFaction: v == null),
              ),
            ),
            _dropdown('winner', filter.winner, const ['savior', 'executor', 'draw'],
                (v) => onChanged(filter.copyWith(winner: v, clearWinner: v == null))),
            _dropdown(
              'firstPlayer',
              filter.firstPlayer,
              const ['savior', 'executor'],
              (v) => onChanged(
                filter.copyWith(firstPlayer: v, clearFirstPlayer: v == null),
              ),
            ),
            _dropdown(
              'cpuDifficulty',
              filter.cpuDifficulty,
              const ['random', 'balanced', 'aggressive', 'defensive', 'hard'],
              (v) => onChanged(
                filter.copyWith(cpuDifficulty: v, clearCpuDifficulty: v == null),
              ),
            ),
            _triState(
              '初回プレイのみ',
              filter.isFirstGame,
              (v) => onChanged(
                filter.copyWith(isFirstGame: v, clearIsFirstGame: v == null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          key: const Key('analysis-filter-rated-only'),
          value: filter.ratedOnly,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('評価入力済みのみ', style: TextStyle(color: Colors.white70, fontSize: 13)),
          onChanged: (v) => onChanged(filter.copyWith(ratedOnly: v ?? false)),
        ),
        CheckboxListTile(
          key: const Key('analysis-filter-commented-only'),
          value: filter.commentedOnly,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('コメントありのみ', style: TextStyle(color: Colors.white70, fontSize: 13)),
          onChanged: (v) => onChanged(filter.copyWith(commentedOnly: v ?? false)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('analysis-filter-reset'),
            onPressed: onReset,
            child: const Text('条件をリセット'),
          ),
        ),
      ],
    ),
  );

  Widget _dropdown(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: 160,
    child: DropdownButtonFormField<String?>(
      key: Key('analysis-filter-$label'),
      initialValue: value,
      isDense: true,
      dropdownColor: const Color(0xFF15151C),
      decoration: InputDecoration(labelText: label, isDense: true),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      items: [
        const DropdownMenuItem(value: null, child: Text('指定なし')),
        for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    ),
  );

  Widget _triState(String label, bool? value, ValueChanged<bool?> onChanged) => SizedBox(
    width: 160,
    child: DropdownButtonFormField<bool?>(
      key: Key('analysis-filter-tri-$label'),
      initialValue: value,
      isDense: true,
      dropdownColor: const Color(0xFF15151C),
      decoration: InputDecoration(labelText: label, isDense: true),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      items: const [
        DropdownMenuItem(value: null, child: Text('指定なし')),
        DropdownMenuItem(value: true, child: Text('はい')),
        DropdownMenuItem(value: false, child: Text('いいえ')),
      ],
      onChanged: onChanged,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}
