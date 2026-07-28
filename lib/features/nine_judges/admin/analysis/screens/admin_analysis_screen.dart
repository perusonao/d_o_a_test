import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_filter.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_report.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/analysis_actions_loader.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/external_test_analysis_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/widgets/analysis_filter_panel.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/widgets/analysis_report_preview.dart';
import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter/material.dart';

enum _Stage { idle, fetchingBase, fetchingActions, aggregating, done, error }

/// Section 2-11: "分析レポート" tab. Generates an AI-analysis report from
/// whichever games [AnalysisFilter] resolves to — never fetches anything on
/// its own until "レポート生成" is pressed (section 11: no automatic bulk
/// fetch on first display).
class AdminAnalysisScreen extends StatefulWidget {
  const AdminAnalysisScreen({
    required this.repository,
    required this.anonymizer,
    required this.loadedRecords,
    required this.projectId,
    super.key,
  });

  final AdminPlaytestRepository repository;
  final TesterAnonymizer anonymizer;

  /// Whatever the ゲームログ tab has already paginated in — the source for
  /// [AnalysisSource.allLoaded] (never a fresh Firestore query).
  final List<PlaytestRecord> loadedRecords;
  final String projectId;

  @override
  State<AdminAnalysisScreen> createState() => _AdminAnalysisScreenState();
}

class _AdminAnalysisScreenState extends State<AdminAnalysisScreen> {
  AnalysisFilter _filter = const AnalysisFilter();
  late final AnalysisActionsLoader _actionsLoader = AnalysisActionsLoader(
    repository: widget.repository,
  );

  _Stage _stage = _Stage.idle;
  int _progressDone = 0;
  int _progressTotal = 0;
  String? _errorMessage;
  int _malformedSkipped = 0;
  AnalysisReport? _report;
  bool _cancelRequested = false;
  bool _generating = false;

  Future<void> _generate() async {
    // Section 11: multi-execution guard.
    if (_generating) return;
    _generating = true;
    _cancelRequested = false;
    setState(() {
      _stage = _Stage.fetchingBase;
      _errorMessage = null;
      _malformedSkipped = 0;
      _progressDone = 0;
      _progressTotal = 0;
    });

    try {
      var pool = await _resolvePool();
      pool = pool.where(_filter.matches).toList();

      if (_filter.mode == AnalysisMode.detailed && pool.isNotEmpty) {
        setState(() => _stage = _Stage.fetchingActions);
        _actionsLoader.seedFromLoadedRecords(widget.loadedRecords);
        final result = await _actionsLoader.ensureLoaded(
          pool,
          onProgress: (done, total) {
            if (!mounted) return;
            setState(() {
              _progressDone = done;
              _progressTotal = total;
            });
          },
          isCancelled: () => _cancelRequested,
        );
        pool = result.records;
        if (!mounted) return;
        setState(() => _stage = _Stage.aggregating);
        final report = buildAnalysisReport(
          pool: pool,
          filter: _filter,
          projectId: widget.projectId,
          anonymizer: widget.anonymizer,
          failedActionGameCount: result.failedGameIds.length,
          failedGameIds: result.failedGameIds,
        );
        if (!mounted) return;
        setState(() {
          _report = report;
          _stage = _Stage.done;
        });
      } else {
        setState(() => _stage = _Stage.aggregating);
        final report = buildAnalysisReport(
          pool: pool,
          filter: _filter,
          projectId: widget.projectId,
          anonymizer: widget.anonymizer,
        );
        if (!mounted) return;
        setState(() {
          _report = report;
          _stage = _Stage.done;
        });
      }
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = _friendlyError(exception.toString());
      });
    } finally {
      _generating = false;
    }
  }

  Future<List<PlaytestRecord>> _resolvePool() async {
    final source = _filter.source;
    if (source == AnalysisSource.allLoaded) {
      return List.of(widget.loadedRecords);
    }
    final page = await widget.repository.fetchFirstPage(limit: source.limit!);
    _malformedSkipped = page.malformedCount;
    return page.records;
  }

  void _cancel() {
    _cancelRequested = true;
  }

  void _reset() {
    setState(() {
      _filter = const AnalysisFilter();
      _report = null;
      _stage = _Stage.idle;
      _errorMessage = null;
    });
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission-denied') || lower.contains('permission_denied')) {
      return 'Firestoreの権限エラーです(permission-denied)';
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return 'ネットワークエラーが発生しました';
    }
    return 'レポート生成中にエラーが発生しました: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final generating = _stage == _Stage.fetchingBase ||
        _stage == _Stage.fetchingActions ||
        _stage == _Stage.aggregating;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nine Verdicts\nExternal Test Analysis Report',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 6),
              Text(
                '選択したプレイログを集計し、ChatGPTやClaudeへ貼り付けられる分析レポートを生成します。'
                'データが外部AIへ自動送信されることはありません。'
                'レポートはこの端末内で生成されます。',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        AnalysisFilterPanel(
          filter: _filter,
          onChanged: (f) => setState(() => _filter = f),
          onReset: _reset,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilledButton.icon(
                key: const Key('analysis-generate'),
                onPressed: generating ? null : _generate,
                icon: const Icon(Icons.auto_graph),
                label: Text(_report == null ? 'レポート生成' : '再生成'),
              ),
              const SizedBox(width: 8),
              if (generating)
                OutlinedButton(
                  key: const Key('analysis-cancel'),
                  onPressed: _cancel,
                  child: const Text('キャンセル'),
                ),
            ],
          ),
        ),
        if (generating) _ProgressBanner(stage: _stage, done: _progressDone, total: _progressTotal),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _errorMessage!,
              key: const Key('analysis-error'),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        if (_malformedSkipped > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '形式不正のため除外: $_malformedSkipped件',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ),
        if (_report != null && _report!.reportInfo['gameCount'] == 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '対象となるゲームが0件です(フィルター条件をご確認ください)',
              key: Key('analysis-empty-pool'),
              style: TextStyle(color: Colors.amberAccent, fontSize: 12),
            ),
          ),
        if (_report != null && (_report!.reportInfo['gameCount']! as int) > 100)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '現在${_report!.reportInfo['gameCount']}件を分析対象にしています(100件超)',
              key: const Key('analysis-large-pool-warning'),
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
            ),
          )
        else if (_report != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '現在${_report!.reportInfo['gameCount']}ゲームを分析対象にしています',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        Expanded(
          child: _report == null
              ? const Center(
                  child: Text(
                    '「レポート生成」を押すと分析レポートを作成します',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : AnalysisReportPreview(report: _report!),
        ),
      ],
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.stage, required this.done, required this.total});

  final _Stage stage;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      _Stage.fetchingBase => '基本データ取得中',
      _Stage.fetchingActions => 'アクションログ取得中\n$done / $total ゲーム',
      _Stage.aggregating => '集計中',
      _ => 'レポート生成完了',
    };
    return Container(
      key: const Key('analysis-progress-banner'),
      width: double.infinity,
      color: Colors.white10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
