import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/screens/admin_analysis_screen.dart';
import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_feedback_tab.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_kpi_tab.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_logs_tab.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_overview_tab.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_settings_tab.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_tester_history_screen.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_firebase.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:dead_or_alive/features/nine_judges/admin/simulation/screens/admin_simulation_screen.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:flutter/material.dart';

enum _LoadState { idle, loading, error }

/// The admin dashboard shell shown once [AdminSessionStatus.admin] is
/// reached: header (section 5) + 5 tabs (section 5/6). Owns pagination
/// (section 9/23) and the shared [TesterAnonymizer] so a testerId maps to
/// the same "Player NNN" label everywhere in this session.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.userEmail,
    required this.onLogout,
    super.key,
    this.repository,
  });

  final String userEmail;
  final VoidCallback onLogout;

  /// Injectable for tests.
  final AdminPlaytestRepository? repository;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AdminPlaytestRepository _repository =
      widget.repository ?? AdminPlaytestRepository();
  final TesterAnonymizer anonymizer = TesterAnonymizer();
  late final TabController _tabController = TabController(
    length: 7,
    vsync: this,
  );

  final List<PlaytestRecord> records = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool hasMore = true;
  int malformedCount = 0;
  _LoadState _loadState = _LoadState.idle;
  String? _loadError;
  DateTime? lastUpdated;
  bool _refreshing = false;

  int? _tutorialCompletionCount;
  bool _tutorialCompletionFailed = false;
  int? _visitCount;
  bool _visitCountFailed = false;
  int? _playCount;
  bool _playCountFailed = false;
  List<MapEntry<String, int>>? _dailyVisitCounts;
  List<MapEntry<String, int>>? _dailyPlayCounts;
  bool _dailyCountsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    unawaited(_loadTutorialCompletionCount());
    unawaited(_loadVisitCount());
    unawaited(_loadPlayCount());
    unawaited(_loadDailyCounts());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    if (_loadState == _LoadState.loading) return;
    setState(() {
      _loadState = _LoadState.loading;
      _loadError = null;
    });
    try {
      final page = await _repository.fetchFirstPage();
      setState(() {
        records
          ..clear()
          ..addAll(page.records);
        _lastDocument = page.lastDocument;
        hasMore = page.hasMore;
        malformedCount = page.malformedCount;
        lastUpdated = DateTime.now();
        _loadState = _LoadState.idle;
      });
    } catch (exception) {
      setState(() {
        _loadState = _LoadState.error;
        _loadError = exception.toString();
      });
    }
  }

  Future<void> loadMore() async {
    final after = _lastDocument;
    if (after == null || !hasMore || _loadState == _LoadState.loading) return;
    setState(() => _loadState = _LoadState.loading);
    try {
      final page = await _repository.fetchNextPage(after);
      setState(() {
        records.addAll(page.records);
        _lastDocument = page.lastDocument ?? _lastDocument;
        hasMore = page.hasMore;
        malformedCount += page.malformedCount;
        lastUpdated = DateTime.now();
        _loadState = _LoadState.idle;
      });
    } catch (exception) {
      setState(() {
        _loadState = _LoadState.error;
        _loadError = exception.toString();
      });
    }
  }

  Future<void> refresh() async {
    // Section 23: refresh must not multi-fetch on repeat clicks.
    if (_refreshing) return;
    _refreshing = true;
    await Future.wait([
      _loadFirstPage(),
      _loadTutorialCompletionCount(),
      _loadVisitCount(),
      _loadPlayCount(),
      _loadDailyCounts(),
    ]);
    _refreshing = false;
  }

  /// Best-effort: a failure here (e.g. Firebase unavailable) must never
  /// affect the rest of the dashboard, mirroring _loadFirstPage's own
  /// try/catch — the KPI tab just keeps showing this one figure as
  /// unavailable instead.
  Future<void> _loadTutorialCompletionCount() async {
    try {
      final count = await _repository.fetchTutorialCompletionCount();
      if (mounted) {
        setState(() {
          _tutorialCompletionCount = count;
          _tutorialCompletionFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tutorialCompletionFailed = true);
    }
  }

  /// Best-effort, same shape as [_loadTutorialCompletionCount] — a failure
  /// here must never affect the rest of the dashboard.
  Future<void> _loadVisitCount() async {
    try {
      final count = await _repository.fetchVisitCount();
      if (mounted) {
        setState(() {
          _visitCount = count;
          _visitCountFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _visitCountFailed = true);
    }
  }

  Future<void> _loadPlayCount() async {
    try {
      final count = await _repository.fetchPlayCount();
      if (mounted) {
        setState(() {
          _playCount = count;
          _playCountFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _playCountFailed = true);
    }
  }

  /// Best-effort, same shape as [_loadTutorialCompletionCount] — both series
  /// are fetched together and share a single failure flag since the daily
  /// trend table always shows them zipped as one row per day.
  Future<void> _loadDailyCounts() async {
    try {
      final visits = await _repository.fetchDailyVisitCounts();
      final plays = await _repository.fetchDailyPlayCounts();
      if (mounted) {
        setState(() {
          _dailyVisitCounts = visits;
          _dailyPlayCounts = plays;
          _dailyCountsFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dailyCountsFailed = true);
    }
  }

  Future<void> fetchActionsFor(PlaytestRecord record) async {
    if (record.actions != null) return;
    final actions = await _repository.fetchActions(record.gameId);
    final index = records.indexWhere((r) => r.gameId == record.gameId);
    if (index != -1 && mounted) {
      setState(() => records[index] = records[index].withActions(actions));
    }
  }

  void _openTesterHistory(String testerId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminTesterHistoryScreen(
          repository: _repository,
          anonymizer: anonymizer,
          testerId: testerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15151C),
        title: const Text('9人の審判 / 外部テスト管理 / rules ${NineJudgesConfig.rulesVersion}'),
        actions: [
          IconButton(
            key: const Key('admin-refresh'),
            tooltip: '再読み込み',
            onPressed: _loadState == _LoadState.loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const Key('admin-header-logout'),
            tooltip: 'ログアウト',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '概要'),
            Tab(text: 'ゲームログ'),
            Tab(text: 'フィードバック'),
            Tab(text: 'KPI'),
            Tab(text: '分析レポート'),
            Tab(text: 'Simulation'),
            Tab(text: '設定・接続状況'),
          ],
        ),
      ),
      body: Column(
        children: [
          _StatusBar(
            userEmail: widget.userEmail,
            projectId: AdminFirebase.projectId,
            lastUpdated: lastUpdated,
            loading: _loadState == _LoadState.loading,
            loadError: _loadError,
            malformedCount: malformedCount,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AdminOverviewTab(
                  records: records,
                  visitCount: _visitCount,
                  playCount: _playCount,
                  visitCountFailed: _visitCountFailed,
                  playCountFailed: _playCountFailed,
                  dailyVisitCounts: _dailyVisitCounts,
                  dailyPlayCounts: _dailyPlayCounts,
                  dailyCountsFailed: _dailyCountsFailed,
                ),
                AdminLogsTab(
                  records: records,
                  anonymizer: anonymizer,
                  hasMore: hasMore,
                  loading: _loadState == _LoadState.loading,
                  onLoadMore: loadMore,
                  onOpenDetail: fetchActionsFor,
                  onViewTesterHistory: _openTesterHistory,
                ),
                AdminFeedbackTab(records: records, anonymizer: anonymizer),
                AdminKpiTab(
                  records: records,
                  tutorialCompletionCount: _tutorialCompletionCount,
                  tutorialCompletionFailed: _tutorialCompletionFailed,
                ),
                AdminAnalysisScreen(
                  repository: _repository,
                  anonymizer: anonymizer,
                  loadedRecords: records,
                  projectId: AdminFirebase.projectId,
                ),
                const AdminSimulationScreen(),
                AdminSettingsTab(
                  userEmail: widget.userEmail,
                  projectId: AdminFirebase.projectId,
                  lastUpdated: lastUpdated,
                  loadedCount: records.length,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.userEmail,
    required this.projectId,
    required this.lastUpdated,
    required this.loading,
    required this.loadError,
    required this.malformedCount,
  });

  final String userEmail;
  final String projectId;
  final DateTime? lastUpdated;
  final bool loading;
  final String? loadError;
  final int malformedCount;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'ログイン中: $userEmail',
      'projectId: $projectId',
      if (lastUpdated != null) '最終更新: ${_format(lastUpdated!)}',
    ];
    return Container(
      width: double.infinity,
      color: Colors.white10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final line in lines)
            Text(
              line,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (loading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (loadError != null)
            Text(
              _friendlyError(loadError!),
              key: const Key('admin-load-error'),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          if (malformedCount > 0)
            Text(
              '形式不正のため除外: $malformedCount件',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
        ],
      ),
    );
  }

  String _format(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';

  /// Section 21: distinguish permission-denied vs network vs unknown errors.
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission-denied') || lower.contains('permission_denied')) {
      return 'Firestoreの権限エラーです(permission-denied)';
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return 'ネットワークエラーが発生しました';
    }
    return 'データ取得エラー: $raw';
  }
}
