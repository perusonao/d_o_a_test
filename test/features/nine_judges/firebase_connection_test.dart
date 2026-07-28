import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_playtest_repository.dart';
import 'package:dead_or_alive/firebase_options.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameSession _session({required String testerId, String gameId = 'game-1'}) =>
    GameSession(
      gameId: gameId,
      startedAt: DateTime(2024, 1, 1),
      gameVersion: NineJudgesConfig.gameVersion,
      rulesVersion: NineJudgesConfig.rulesVersion,
      mode: 'cpu',
      playerFaction: 'savior',
      cpuFaction: 'executor',
      firstPlayer: 'savior',
      cpuDifficulty: 'balanced',
      seed: 1,
      initialBoard: const [],
      testerId: testerId,
      playNumber: 1,
      isFirstGame: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultFirebaseOptions(接続したFirebaseプロジェクト nine-verdicts)', () {
    test('Web向けオプションはnine-verdictsプロジェクトを指す', () {
      const web = DefaultFirebaseOptions.web;
      expect(web.projectId, 'nine-verdicts');
      expect(web.authDomain, 'nine-verdicts.firebaseapp.com');
      expect(web.apiKey, isNotEmpty);
      expect(web.appId, isNotEmpty);
    });

    test('Web以外のプラットフォームは未設定としてUnsupportedErrorを投げる', () {
      // flutter test はWebでは動かないため、kIsWeb=falseの経路を確実に踏む。
      expect(kIsWeb, isFalse);
      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsUnsupportedError,
      );
    });
  });

  group('FirebaseBootstrap(初期化・フォールバック)', () {
    test('実際のFirebaseバックエンドに接続できない環境ではavailable=falseへフォールバックする', () async {
      // flutter test は素のDart VM上で動くため、Web用FirebaseOptionsで
      // Firebase.initializeAppを呼んでもプラットフォームチャンネルが無く失敗する。
      // このとき例外を外へ漏らさず、ローカルHive保存だけで動き続けられることを確認する。
      await FirebaseBootstrap.initialize();
      expect(FirebaseBootstrap.available, isFalse);
      expect(FirebaseBootstrap.error, isNotNull);
      expect(FirebaseBootstrap.uid, isNull);
    });
  });

  group('testerIdとfirebaseUidの分離', () {
    test('GameSession自体はfirebaseUidという概念を持たない', () {
      final session = _session(testerId: 'local-device-abc');
      final json = session.toJson();
      expect(json['testerId'], 'local-device-abc');
      expect(json.containsKey('firebaseUid'), isFalse);
    });
  });

  group('FirebasePlaytestRepository.send(FakeFirebaseFirestoreによる検証)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('送信成功: testerIdを保ったままfirebaseUidを別フィールドとして書き込む', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirebasePlaytestRepository(
        firestore: firestore,
        uidOverride: 'firebase-auth-uid-1',
        availableOverride: true,
      );
      final session = _session(testerId: 'local-device-abc', gameId: 'ok-1');

      await repository.send(
        session: session,
        ratings: const {'fun': 5},
        notes: '',
      );

      final doc = await firestore.collection('playtests').doc('ok-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['firebaseUid'], 'firebase-auth-uid-1');
      // 永続testerIdはFirebase Authのuidで上書きされていないこと(過去の不具合の回帰防止)。
      expect(doc.data()!['testerId'], 'local-device-abc');
      expect(await repository.wasSent('ok-1'), isTrue);

      // 2回目のsendは何も書き換えない(既送信ガード)。
      await repository.send(
        session: session,
        ratings: const {'fun': 1},
        notes: 'changed',
      );
      final again = await firestore.collection('playtests').doc('ok-1').get();
      expect(again.data()!['ratings'], {'fun': 5});
    });

    test('送信失敗: Firestore側が例外を返した場合は呼び出し元へ伝播する', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('playtests').doc('rejected-1');
      whenCalling(Invocation.method(#set, null))
          .on(docRef)
          .thenThrow(
            FirebaseException(plugin: 'firestore', code: 'permission-denied'),
          );
      final repository = FirebasePlaytestRepository(
        firestore: firestore,
        uidOverride: 'firebase-auth-uid-1',
        availableOverride: true,
      );
      final session = _session(
        testerId: 'local-device-abc',
        gameId: 'rejected-1',
      );

      await expectLater(
        repository.send(session: session, ratings: const {'fun': 5}, notes: ''),
        throwsA(isA<FirebaseException>()),
      );
      // 失敗時は「送信済み」フラグを立てない(再送を妨げない)。
      expect(await repository.wasSent('rejected-1'), isFalse);
    });

    test('送信失敗: Firebase未接続(available=false)の場合は送信前にStateErrorで失敗する', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirebasePlaytestRepository(
        firestore: firestore,
        availableOverride: false,
      );
      final session = _session(
        testerId: 'local-device-abc',
        gameId: 'unavail-1',
      );

      await expectLater(
        repository.send(session: session, ratings: const {'fun': 5}, notes: ''),
        throwsStateError,
      );
      final doc = await firestore
          .collection('playtests')
          .doc('unavail-1')
          .get();
      expect(doc.exists, isFalse);
    });
  });

  group('rulesVersion 1.2が今回の変更で書き換わっていないこと', () {
    test('EYEの中央制限・上限2回・rulesVersionは不変', () {
      expect(
        NineJudgesConfig.eyeMaxUsesPerPlayer(NineJudgesRuleVersion.v1_2),
        2,
      );
      expect(
        NineJudgesConfig.eyeZoneRestricted(NineJudgesRuleVersion.v1_2),
        isTrue,
      );
      expect(NineJudgesConfig.centerIndices, {3, 4, 5});
      expect(NineJudgesConfig.rulesVersion, '1.2');
    });
  });
}
