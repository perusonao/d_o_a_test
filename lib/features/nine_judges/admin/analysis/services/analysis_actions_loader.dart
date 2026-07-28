import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';

/// Result of a [AnalysisActionsLoader.ensureLoaded] call: the (possibly
/// partially-updated) records plus which games' `actions` fetch failed, so
/// report generation can continue with whatever succeeded (section 15).
class ActionsLoadResult {
  const ActionsLoadResult({
    required this.records,
    required this.failedGameIds,
    this.cancelled = false,
  });

  final List<PlaytestRecord> records;
  final List<String> failedGameIds;
  final bool cancelled;
}

/// Section 4/11: fetches each selected game's `actions` subcollection only
/// when "詳細分析" mode is chosen, reusing a session-scoped cache so
/// re-generating the report (or switching between basic/detailed) never
/// re-fetches a game whose actions are already known, and limiting how many
/// fetches run at once (section 11's "適切な並列数制限").
class AnalysisActionsLoader {
  AnalysisActionsLoader({
    required this.repository,
    this.concurrency = 5,
  });

  final AdminPlaytestRepository repository;
  final int concurrency;

  /// gameId -> actions. Shared across report (re-)generations within one
  /// admin session so previously-opened/fetched games are never re-read.
  final Map<String, List<GameActionLog>> _cache = {};

  /// Seeds the cache with actions the dashboard's ゲームログ tab has already
  /// fetched for a record's detail view, so this loader never re-fetches
  /// those either.
  void seedFromLoadedRecords(List<PlaytestRecord> records) {
    for (final record in records) {
      final actions = record.actions;
      if (actions != null) _cache[record.gameId] = actions;
    }
  }

  Future<ActionsLoadResult> ensureLoaded(
    List<PlaytestRecord> records, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final result = List<PlaytestRecord>.from(records);
    final failedGameIds = <String>[];
    final pending = <int>[
      for (var i = 0; i < result.length; i++)
        if (result[i].actions == null) i,
    ];

    // Anything already cached from a prior generation/detail-view open can
    // be filled in immediately without a Firestore read.
    for (final i in pending.toList()) {
      final cached = _cache[result[i].gameId];
      if (cached != null) {
        result[i] = result[i].withActions(cached);
        pending.remove(i);
      }
    }

    var done = records.length - pending.length;
    onProgress?.call(done, records.length);
    if (pending.isEmpty) {
      return ActionsLoadResult(records: result, failedGameIds: failedGameIds);
    }

    var cancelled = false;
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) {
          cancelled = true;
          return;
        }
        int index;
        if (cursor >= pending.length) return;
        index = pending[cursor];
        cursor++;
        try {
          final actions = await repository.fetchActions(result[index].gameId);
          _cache[result[index].gameId] = actions;
          result[index] = result[index].withActions(actions);
        } catch (_) {
          failedGameIds.add(result[index].gameId);
        }
        done++;
        onProgress?.call(done, records.length);
      }
    }

    final workerCount = concurrency.clamp(1, pending.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    return ActionsLoadResult(
      records: result,
      failedGameIds: failedGameIds,
      cancelled: cancelled,
    );
  }
}
