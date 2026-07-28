import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/analysis_actions_loader.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// Simulates a Firestore read failure for one specific game only, without
/// relying on mock_exceptions matching an internal chained Query object
/// (fetchActions calls `.orderBy(...)` before `.get()`, which returns a new
/// Query instance the test has no handle on).
class _PartiallyFailingRepository extends AdminPlaytestRepository {
  _PartiallyFailingRepository({required super.firestore, required this.failingGameId});

  final String failingGameId;

  @override
  Future<List<GameActionLog>> fetchActions(String gameId) {
    if (gameId == failingGameId) {
      throw Exception('simulated fetch failure');
    }
    return super.fetchActions(gameId);
  }
}

Future<void> _seedActions(
  FakeFirebaseFirestore firestore,
  String gameId,
  int count,
) async {
  final ref = firestore.collection('playtests').doc(gameId).collection('actions');
  for (var i = 0; i < count; i++) {
    await ref.doc(i.toString().padLeft(3, '0')).set(buildAction(actionIndex: i).toJson());
  }
}

void main() {
  group('AnalysisActionsLoader.ensureLoaded', () {
    test('actions未取得のレコードだけをFirestoreから取得する', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedActions(firestore, 'g1', 2);
      await _seedActions(firestore, 'g2', 3);
      final loader = AnalysisActionsLoader(
        repository: AdminPlaytestRepository(firestore: firestore),
      );
      final records = [buildRecord(gameId: 'g1'), buildRecord(gameId: 'g2')];

      final result = await loader.ensureLoaded(records);

      expect(result.records[0].actions?.length, 2);
      expect(result.records[1].actions?.length, 3);
      expect(result.failedGameIds, isEmpty);
    });

    test('既にactionsを持つレコードは再取得しない(キャッシュ・既取得の両方)', () async {
      final firestore = FakeFirebaseFirestore();
      // No actions seeded in Firestore for g1 — if the loader tried to
      // re-fetch it, it would get an empty list, not the pre-attached one.
      final loader = AnalysisActionsLoader(
        repository: AdminPlaytestRepository(firestore: firestore),
      );
      final preloaded = buildRecord(
        gameId: 'g1',
        actionsLoaded: true,
        actions: [buildAction(actionIndex: 0)],
      );

      final result = await loader.ensureLoaded([preloaded]);

      expect(result.records.single.actions?.length, 1);
    });

    test('seedFromLoadedRecordsで事前キャッシュした分は再取得しない', () async {
      final firestore = FakeFirebaseFirestore();
      final loader = AnalysisActionsLoader(
        repository: AdminPlaytestRepository(firestore: firestore),
      );
      final alreadyOpened = buildRecord(
        gameId: 'g1',
        actionsLoaded: true,
        actions: [buildAction(actionIndex: 0), buildAction(actionIndex: 1)],
      );
      loader.seedFromLoadedRecords([alreadyOpened]);

      // A fresh record for the same gameId, without actions attached yet —
      // simulating a new "latest N" fetch returning the same game.
      final freshRecordSameGame = buildRecord(gameId: 'g1');
      final result = await loader.ensureLoaded([freshRecordSameGame]);

      expect(result.records.single.actions?.length, 2);
    });

    test('一部ゲームのactions取得が失敗しても他のゲームで処理を継続する', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedActions(firestore, 'good', 1);

      final loader = AnalysisActionsLoader(
        repository: _PartiallyFailingRepository(
          firestore: firestore,
          failingGameId: 'bad',
        ),
      );
      final result = await loader.ensureLoaded([
        buildRecord(gameId: 'good'),
        buildRecord(gameId: 'bad'),
      ]);

      final goodRecord = result.records.firstWhere((r) => r.gameId == 'good');
      final badRecord = result.records.firstWhere((r) => r.gameId == 'bad');
      expect(goodRecord.actions, isNotNull);
      expect(badRecord.actions, isNull);
      expect(result.failedGameIds, ['bad']);
    });

    test('0件のときクラッシュしない', () async {
      final loader = AnalysisActionsLoader(
        repository: AdminPlaytestRepository(firestore: FakeFirebaseFirestore()),
      );
      final result = await loader.ensureLoaded(const []);
      expect(result.records, isEmpty);
      expect(result.failedGameIds, isEmpty);
    });
  });
}
