import 'dart:async';
import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/admin/simulation/widgets/simulation_results_view.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_rule_flags.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:flutter/material.dart';

enum _RunState { idle, running, done, cancelled }

/// One togglable rule, declared once so adding a future rule (section 11:
/// "今後ルール追加しても簡単に増やせる構造") is a single new entry in
/// [_ruleToggles] below — never a new widget or new branch anywhere else.
class _RuleToggle {
  const _RuleToggle({
    required this.label,
    required this.isOn,
    required this.apply,
  });

  final String label;
  final bool Function(SimulationRuleFlags flags) isOn;
  final SimulationRuleFlags Function(SimulationRuleFlags flags, bool value)
  apply;
}

final List<_RuleToggle> _ruleToggles = [
  _RuleToggle(
    label: 'JUDGEは全状態で使用可能（現行: 審議中のみ）',
    isOn: (f) => !f.judgeRequiresDeliberating,
    apply: (f, v) => f.copyWith(judgeRequiresDeliberating: !v),
  ),
  _RuleToggle(
    label: 'SPECIAL VERDICT（LIFE/DEATHの自然確定）を無効化',
    isOn: (f) => !f.naturalConfirmationEnabled,
    apply: (f, v) => f.copyWith(naturalConfirmationEnabled: !v),
  ),
  _RuleToggle(
    label: 'Reverse LIFE（執行者のLIFE）を無効化',
    isOn: (f) => !f.reverseLifeEnabled,
    apply: (f, v) => f.copyWith(reverseLifeEnabled: !v),
  ),
  _RuleToggle(
    label: 'Reverse DEATH（救済者のDEATH）を無効化',
    isOn: (f) => !f.reverseDeathEnabled,
    apply: (f, v) => f.copyWith(reverseDeathEnabled: !v),
  ),
  _RuleToggle(
    label: 'EYEを無効化',
    isOn: (f) => !f.eyeEnabled,
    apply: (f, v) => f.copyWith(eyeEnabled: !v),
  ),
  _RuleToggle(
    label: 'ボーナスを常時両者に公開',
    isOn: (f) => f.bonusAlwaysPublic,
    apply: (f, v) => f.copyWith(bonusAlwaysPublic: v),
  ),
];

class _RulePreset {
  const _RulePreset(this.label, this.flags);
  final String label;
  final SimulationRuleFlags flags;
}

const _rulePresets = [
  _RulePreset('① 現行ルール', SimulationRuleFlags.current),
  _RulePreset(
    '② JUDGE自由（SPECIAL VERDICTあり）',
    SimulationRuleFlags.judgeFreeWithNaturalConfirmation,
  ),
  _RulePreset(
    '③ JUDGE自由（SPECIAL VERDICTなし）',
    SimulationRuleFlags.judgeOnlyConfirmation,
  ),
];

const _gameCountOptions = [100, 500, 1000, 5000, 10000];

/// "Simulation" admin tab (ゲームバランス分析): configures and runs
/// CPU-vs-CPU batches entirely client-side (see
/// [SimulationRunner.runWithProgress]) so ルール変更の効果を勝率・ターン
/// 数・カード使用率などの数値で比較できるようにする。Never touches the real
/// game screen/controller — see [SimulationRuleFlags]'s own doc comment.
class AdminSimulationScreen extends StatefulWidget {
  const AdminSimulationScreen({super.key});

  @override
  State<AdminSimulationScreen> createState() => _AdminSimulationScreenState();
}

class _AdminSimulationScreenState extends State<AdminSimulationScreen> {
  int _gameCount = 1000;
  CpuLevel _cpuLevel = CpuLevel.balanced;
  SimulationFirstPlayer _firstPlayer = SimulationFirstPlayer.random;
  bool _randomSeed = true;
  int _fixedSeed = 1000;
  SimulationRuleFlags _ruleFlags = SimulationRuleFlags.current;

  _RunState _state = _RunState.idle;
  int _done = 0;
  int _total = 0;
  DateTime? _startedAt;
  List<SimulationResult> _soFar = const [];
  bool _cancelRequested = false;
  SimulationRun? _run;
  String? _error;

  bool get _running => _state == _RunState.running;

  Future<void> _start() async {
    if (_running) return;
    _cancelRequested = false;
    final seed = _randomSeed ? Random().nextInt(1 << 31) : _fixedSeed;
    final config = SimulationConfig(
      gameCount: _gameCount,
      baseSeed: seed,
      saviorDifficulty: _cpuLevel,
      executorDifficulty: _cpuLevel,
      firstPlayer: _firstPlayer,
      ruleFlags: _ruleFlags,
    );
    setState(() {
      _state = _RunState.running;
      _done = 0;
      _total = _gameCount;
      _startedAt = DateTime.now();
      _soFar = const [];
      _run = null;
      _error = null;
    });
    try {
      final run = await const SimulationRunner().runWithProgress(
        config,
        onProgress: (done, total, soFar) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
            _soFar = soFar;
          });
        },
        isCancelled: () => _cancelRequested,
      );
      if (!mounted) return;
      setState(() {
        _run = run;
        _state = run == null ? _RunState.cancelled : _RunState.done;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _error = 'シミュレーション中にエラーが発生しました: $exception';
        _state = _RunState.idle;
      });
    }
  }

  void _cancel() => _cancelRequested = true;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      const Text(
        'ゲームバランス分析 (Simulation)',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'ルール変更時にCPU同士で大量対戦を行い、勝率・カード使用率・ボーナス分析を'
        '数値で比較するためのツールです。この端末内で完結し、実際のゲーム画面/'
        'ルールには一切影響しません。',
        style: TextStyle(color: Colors.white60, fontSize: 12),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: '① Simulation設定',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RadioGroup<int>(
              label: '試行回数',
              value: _gameCount,
              options: [
                for (final n in _gameCountOptions) (n, '$n'),
              ],
              onChanged: _running
                  ? null
                  : (v) => setState(() => _gameCount = v),
            ),
            const SizedBox(height: 10),
            _RadioGroup<CpuLevel>(
              label: 'CPUレベル（両陣営同一 — ルール差そのものを見るため）',
              value: _cpuLevel,
              options: [
                for (final level in CpuLevel.values)
                  (level, '${level.uiLabel}(${level.strengthLabel})'),
              ],
              onChanged: _running
                  ? null
                  : (v) => setState(() => _cpuLevel = v),
            ),
            const SizedBox(height: 10),
            _RadioGroup<SimulationFirstPlayer>(
              label: '先攻',
              value: _firstPlayer,
              options: const [
                (SimulationFirstPlayer.random, 'ランダム'),
                (SimulationFirstPlayer.savior, '救済者'),
                (SimulationFirstPlayer.executor, '執行者'),
              ],
              onChanged: _running
                  ? null
                  : (v) => setState(() => _firstPlayer = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Seed',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('ランダム'),
                  selected: _randomSeed,
                  onSelected: _running
                      ? null
                      : (_) => setState(() => _randomSeed = true),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('固定'),
                  selected: !_randomSeed,
                  onSelected: _running
                      ? null
                      : (_) => setState(() => _randomSeed = false),
                ),
                if (!_randomSeed) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      key: const Key('simulation-seed-field'),
                      enabled: !_running,
                      initialValue: '$_fixedSeed',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(isDense: true),
                      keyboardType: TextInputType.number,
                      onChanged: (text) {
                        final parsed = int.tryParse(text);
                        if (parsed != null) _fixedSeed = parsed;
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: '② ルール設定',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '検証したい3パターンをワンタップで切り替えられます。個別のON/OFFは'
              '下のチェックボックスから調整できます。',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _rulePresets)
                  OutlinedButton(
                    key: Key('simulation-preset-${preset.label}'),
                    onPressed: _running
                        ? null
                        : () => setState(() => _ruleFlags = preset.flags),
                    child: Text(preset.label),
                  ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            // Material(transparency): CheckboxListTile paints its ink/
            // background on the nearest Material ancestor, and the enclosing
            // _SectionCard's decorated Container would otherwise hide it.
            Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final toggle in _ruleToggles)
                    CheckboxListTile(
                      key: Key('simulation-toggle-${toggle.label}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        toggle.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      value: toggle.isOn(_ruleFlags),
                      onChanged: _running
                          ? null
                          : (v) => setState(
                              () => _ruleFlags = toggle.apply(
                                _ruleFlags,
                                v ?? false,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                const Text(
                  'JUDGE使用回数上限',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 12),
                for (final cap in const [1, 2, 3, null])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cap == null ? '無制限' : '$cap'),
                      selected: _ruleFlags.judgeUsesPerPlayer == cap,
                      onSelected: _running
                          ? null
                          : (_) => setState(
                              () => _ruleFlags = cap == null
                                  ? _ruleFlags.copyWith(
                                      clearJudgeUsesPerPlayer: true,
                                    )
                                  : _ruleFlags.copyWith(
                                      judgeUsesPerPlayer: cap,
                                    ),
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: '③ Simulation実行',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  key: const Key('simulation-start'),
                  onPressed: _running ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Simulation開始'),
                ),
                const SizedBox(width: 8),
                if (_running)
                  OutlinedButton(
                    key: const Key('simulation-cancel'),
                    onPressed: _cancel,
                    child: const Text('キャンセル'),
                  ),
              ],
            ),
            if (_running) ...[
              const SizedBox(height: 12),
              _ProgressPanel(
                done: _done,
                total: _total,
                startedAt: _startedAt!,
                soFar: _soFar,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('simulation-error'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            if (_state == _RunState.cancelled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '1試合も完了する前にキャンセルされました',
                  key: Key('simulation-cancelled-empty'),
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      if (_run != null) ...[
        const SizedBox(height: 12),
        SimulationResultsView(run: _run!),
      ],
    ],
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
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

class _RadioGroup<T> extends StatelessWidget {
  const _RadioGroup({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (optionValue, optionLabel) in options)
            ChoiceChip(
              label: Text(optionLabel),
              selected: value == optionValue,
              onSelected: onChanged == null
                  ? null
                  : (_) => onChanged!(optionValue),
            ),
        ],
      ),
    ],
  );
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.done,
    required this.total,
    required this.startedAt,
    required this.soFar,
  });

  final int done;
  final int total;
  final DateTime startedAt;
  final List<SimulationResult> soFar;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = done == 0
        ? null
        : Duration(
            milliseconds:
                (elapsed.inMilliseconds / done * (total - done)).round(),
          );
    final decided = soFar.where((r) => r.winner != null).length;
    final saviorWins = soFar
        .where((r) => r.winner == Faction.savior)
        .length;
    final saviorWinRate = decided == 0 ? null : saviorWins / decided;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$done / $total',
          key: const Key('simulation-progress-count'),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total == 0 ? 0 : done / total,
          minHeight: 8,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          children: [
            if (remaining != null)
              Text(
                '残り時間目安: ${_formatDuration(remaining)}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            if (saviorWinRate != null)
              Text(
                '現在の救済者勝率: ${(saviorWinRate * 100).toStringAsFixed(1)}%',
                key: const Key('simulation-running-win-rate'),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) return '約${d.inMinutes}分';
    return '約${d.inSeconds}秒';
  }
}
