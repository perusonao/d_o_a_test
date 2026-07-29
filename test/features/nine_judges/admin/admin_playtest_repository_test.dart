import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Future<void> _seedPlaytest(
  FakeFirebaseFirestore firestore, {
  required String gameId,
  required DateTime finishedAt,
  Map<String, dynamic>? overrideData,
}) async {
  final record = buildRecord(gameId: gameId, finishedAt: finishedAt);
  final data = record.session.toJson()
    ..remove('actions')
    ..addAll({'firebaseUid': record.firebaseUid});
  await firestore.collection('playtests').doc(gameId).set({
    ...data,
    ...?overrideData,
  });
}

void main() {
  group('AdminPlaytestRepository pagination', () {
    test('finishedAt降順で最初のページを取得する', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPlaytest(firestore, gameId: 'g1', finishedAt: DateTime(2026, 1, 1));
      await _seedPlaytest(firestore, gameId: 'g2', finishedAt: DateTime(2026, 1, 3));
      await _seedPlaytest(firestore, gameId: 'g3', finishedAt: DateTime(2026, 1, 2));

      final repository = AdminPlaytestRepository(firestore: firestore);
      final page = await repository.fetchFirstPage(limit: 20);

      expect(page.records.map((r) => r.gameId).toList(), ['g2', 'g3', 'g1']);
      expect(page.hasMore, isFalse);
    });

    test('limitを超える件数があるときはhasMore=trueになり、次ページを取得できる', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 5; i++) {
        await _seedPlaytest(
          firestore,
          gameId: 'g$i',
          finishedAt: DateTime(2026, 1, 1 + i),
        );
      }
      final repository = AdminPlaytestRepository(firestore: firestore);
      final first = await repository.fetchFirstPage(limit: 3);
      expect(first.records.map((r) => r.gameId).toList(), ['g4', 'g3', 'g2']);
      expect(first.hasMore, isTrue);

      final next = await repository.fetchNextPage(first.lastDocument!, limit: 3);
      expect(next.records.map((r) => r.gameId).toList(), ['g1', 'g0']);
      expect(next.hasMore, isFalse);
    });

    test('形式不正なドキュメントはクラッシュせずmalformedCountとしてスキップされる', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPlaytest(firestore, gameId: 'good', finishedAt: DateTime(2026, 1, 1));
      // Missing required fields (e.g. no seed/gameVersion) -> fromJson throws.
      await firestore.collection('playtests').doc('bad').set({
        'finishedAt': DateTime(2026, 1, 2).toIso8601String(),
      });

      final repository = AdminPlaytestRepository(firestore: firestore);
      final page = await repository.fetchFirstPage();
      expect(page.records.map((r) => r.gameId).toList(), ['good']);
      expect(page.malformedCount, 1);
    });
  });

  group('AdminPlaytestRepository.fetchActions', () {
    test('actionIndexの昇順でアクション履歴を取得する(section 12: 詳細を開いたときのみ)', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPlaytest(firestore, gameId: 'g1', finishedAt: DateTime(2026, 1, 1));
      final actionsRef = firestore
          .collection('playtests')
          .doc('g1')
          .collection('actions');
      await actionsRef.doc('001').set(buildAction(actionIndex: 1).toJson());
      await actionsRef.doc('000').set(buildAction(actionIndex: 0).toJson());
      await actionsRef.doc('002').set(buildAction(actionIndex: 2).toJson());

      final repository = AdminPlaytestRepository(firestore: firestore);
      final actions = await repository.fetchActions('g1');
      expect(actions.map((a) => a.actionIndex).toList(), [0, 1, 2]);
    });
  });

  group('AdminPlaytestRepository.fetchByTester', () {
    test('testerIdで絞り込み、playNumberの昇順で返す(ページネーションに依存しない)', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPlaytest(
        firestore,
        gameId: 'g1',
        finishedAt: DateTime(2026, 1, 1),
        overrideData: {'testerId': 'tester-a', 'playNumber': 3},
      );
      await _seedPlaytest(
        firestore,
        gameId: 'g2',
        finishedAt: DateTime(2026, 1, 2),
        overrideData: {'testerId': 'tester-a', 'playNumber': 1},
      );
      await _seedPlaytest(
        firestore,
        gameId: 'g3',
        finishedAt: DateTime(2026, 1, 3),
        overrideData: {'testerId': 'tester-a', 'playNumber': 2},
      );
      await _seedPlaytest(
        firestore,
        gameId: 'g4',
        finishedAt: DateTime(2026, 1, 4),
        overrideData: {'testerId': 'tester-b', 'playNumber': 1},
      );

      final repository = AdminPlaytestRepository(firestore: firestore);
      final records = await repository.fetchByTester('tester-a');

      expect(records.map((r) => r.gameId).toList(), ['g2', 'g3', 'g1']);
    });

    test('該当するゲームが無ければ空配列を返す', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedPlaytest(firestore, gameId: 'g1', finishedAt: DateTime(2026, 1, 1));

      final repository = AdminPlaytestRepository(firestore: firestore);
      final records = await repository.fetchByTester('nobody');

      expect(records, isEmpty);
    });
  });

  group('AdminPlaytestRepository.fetchTutorialCompletionCount', () {
    test('tutorialCompletionsコレクションの件数をcount()集計で返す', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('tutorialCompletions').doc('uid-1').set({
        'testerId': 'tester-1',
      });
      await firestore.collection('tutorialCompletions').doc('uid-2').set({
        'testerId': 'tester-2',
      });

      final repository = AdminPlaytestRepository(firestore: firestore);
      final count = await repository.fetchTutorialCompletionCount();

      expect(count, 2);
    });

    test('0件のときは0を返す', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AdminPlaytestRepository(firestore: firestore);
      final count = await repository.fetchTutorialCompletionCount();
      expect(count, 0);
    });
  });
}
