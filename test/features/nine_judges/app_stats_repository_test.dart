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
}
