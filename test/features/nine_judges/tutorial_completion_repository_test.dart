import 'package:dead_or_alive/features/nine_judges/services/tutorial_completion_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorialCompletionRepository.recordCompletion', () {
    test('Firebase利用可能時はuidをドキュメントIDにtesterIdとcompletedAtを書き込む', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = TutorialCompletionRepository(
        firestore: firestore,
        uidOverride: 'firebase-auth-uid-1',
        availableOverride: true,
      );

      await repository.recordCompletion(testerId: 'local-device-abc');

      final doc = await firestore
          .collection('tutorialCompletions')
          .doc('firebase-auth-uid-1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['testerId'], 'local-device-abc');
      expect(doc.data()!.containsKey('completedAt'), isTrue);
    });

    test('同じ端末で複数回完了しても1ドキュメントのまま(冪等)', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = TutorialCompletionRepository(
        firestore: firestore,
        uidOverride: 'firebase-auth-uid-1',
        availableOverride: true,
      );

      await repository.recordCompletion(testerId: 'local-device-abc');
      await repository.recordCompletion(testerId: 'local-device-abc');

      final snapshot = await firestore.collection('tutorialCompletions').get();
      expect(snapshot.docs.length, 1);
    });

    test('Firebase未接続(available=false)の場合は何も書き込まず例外も投げない', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = TutorialCompletionRepository(
        firestore: firestore,
        availableOverride: false,
      );

      await repository.recordCompletion(testerId: 'local-device-abc');

      final snapshot = await firestore.collection('tutorialCompletions').get();
      expect(snapshot.docs, isEmpty);
    });
  });
}
