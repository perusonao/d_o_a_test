import 'package:dead_or_alive/features/nine_judges/services/app_stats_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppStatsRepository.recordVisit', () {
    test('Firebase利用可能時はappStats/visitsのcountを1にする(初回)', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: true,
      );

      await repository.recordVisit();

      final doc = await firestore.collection('appStats').doc('visits').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['count'], 1);
    });

    test('2回目以降はcountを1ずつ加算する', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: true,
      );

      await repository.recordVisit();
      await repository.recordVisit();
      await repository.recordVisit();

      final doc = await firestore.collection('appStats').doc('visits').get();
      expect(doc.data()!['count'], 3);
    });

    test('Firebase未接続(available=false)の場合は何も書き込まず例外も投げない', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: false,
      );

      await repository.recordVisit();

      final snapshot = await firestore.collection('appStats').get();
      expect(snapshot.docs, isEmpty);
    });
  });

  group('AppStatsRepository.recordPlay', () {
    test('appStats/playsとappStats/visitsは独立したカウンタとして加算される', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: true,
      );

      await repository.recordVisit();
      await repository.recordPlay();
      await repository.recordPlay();

      final visits = await firestore.collection('appStats').doc('visits').get();
      final plays = await firestore.collection('appStats').doc('plays').get();
      expect(visits.data()!['count'], 1);
      expect(plays.data()!['count'], 2);
    });

    test('Firebase未接続の場合は何も書き込まない', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: false,
      );

      await repository.recordPlay();

      final snapshot = await firestore.collection('appStats').get();
      expect(snapshot.docs, isEmpty);
    });
  });

  group('AppStatsRepository daily buckets', () {
    test('recordVisit/recordPlayはappStats/{stat}/days/{yyyy-MM-dd}も加算する', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: true,
        nowOverride: () => DateTime.utc(2026, 7, 30, 23), // 2026-07-31 08:00 JST
      );

      await repository.recordVisit();
      await repository.recordVisit();
      await repository.recordPlay();

      final visitDay = await firestore
          .collection('appStats')
          .doc('visits')
          .collection('days')
          .doc('2026-07-31')
          .get();
      final playDay = await firestore
          .collection('appStats')
          .doc('plays')
          .collection('days')
          .doc('2026-07-31')
          .get();
      expect(visitDay.data()!['count'], 2);
      expect(playDay.data()!['count'], 1);
    });

    test('日付をまたぐと別ドキュメントとして加算される', () async {
      final firestore = FakeFirebaseFirestore();
      var now = DateTime.utc(2026, 7, 30, 10); // 2026-07-30 19:00 JST
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: true,
        nowOverride: () => now,
      );

      await repository.recordVisit();
      now = DateTime.utc(2026, 7, 31, 10); // next JST day
      await repository.recordVisit();

      final day1 = await firestore
          .collection('appStats')
          .doc('visits')
          .collection('days')
          .doc('2026-07-30')
          .get();
      final day2 = await firestore
          .collection('appStats')
          .doc('visits')
          .collection('days')
          .doc('2026-07-31')
          .get();
      expect(day1.data()!['count'], 1);
      expect(day2.data()!['count'], 1);
    });

    test('Firebase未接続の場合は日別ドキュメントも書き込まない', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = AppStatsRepository(
        firestore: firestore,
        availableOverride: false,
      );

      await repository.recordVisit();

      final snapshot = await firestore
          .collectionGroup('days')
          .get();
      expect(snapshot.docs, isEmpty);
    });
  });

  group('jstDateKey', () {
    test('UTC時刻をJST(UTC+9)の日付文字列yyyy-MM-ddへ変換する', () {
      // 2026-07-30 15:00 UTC = 2026-07-31 00:00 JST
      expect(jstDateKey(DateTime.utc(2026, 7, 30, 15)), '2026-07-31');
      // 2026-07-30 14:59 UTC = 2026-07-30 23:59 JST (still the previous day)
      expect(jstDateKey(DateTime.utc(2026, 7, 30, 14, 59)), '2026-07-30');
    });

    test('月・日を2桁ゼロ埋めする', () {
      expect(jstDateKey(DateTime.utc(2026, 1, 5, 0)), '2026-01-05');
    });
  });
}
