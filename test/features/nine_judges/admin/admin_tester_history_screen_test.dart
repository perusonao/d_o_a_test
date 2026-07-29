import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_tester_history_screen.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seedPlaytest(
  FakeFirebaseFirestore firestore, {
  required String gameId,
  required String testerId,
  required int playNumber,
  String playerFaction = 'savior',
  String firstPlayer = 'savior',
  String? winner = 'savior',
}) async {
  await firestore.collection('playtests').doc(gameId).set({
    'gameId': gameId,
    'startedAt': DateTime(2026, 1, playNumber).toIso8601String(),
    'finishedAt': DateTime(2026, 1, playNumber, 10).toIso8601String(),
    'gameVersion': '1.3.0-external-test-beta',
    'rulesVersion': '1.2',
    'mode': 'cpu',
    'playerFaction': playerFaction,
    'cpuFaction': playerFaction == 'savior' ? 'executor' : 'savior',
    'firstPlayer': firstPlayer,
    'cpuDifficulty': 'balanced',
    'seed': 1,
    'initialBoard': <Map<String, dynamic>>[],
    'winner': winner,
    'saviorScore': 25,
    'executorScore': 18,
    'totalTurns': 20,
    'testerId': testerId,
    'playNumber': playNumber,
    'firebaseUid': 'uid-1',
  });
}

void main() {
  testWidgets('testerIdの全戦歴を陣営・先後・勝敗つきで一覧表示する', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedPlaytest(
      firestore,
      gameId: 'g1',
      testerId: 'tester-a',
      playNumber: 1,
      playerFaction: 'savior',
      firstPlayer: 'savior',
      winner: 'savior',
    );
    await _seedPlaytest(
      firestore,
      gameId: 'g2',
      testerId: 'tester-a',
      playNumber: 2,
      playerFaction: 'executor',
      firstPlayer: 'executor',
      winner: 'executor',
    );
    await _seedPlaytest(
      firestore,
      gameId: 'g3',
      testerId: 'tester-b',
      playNumber: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminTesterHistoryScreen(
          repository: AdminPlaytestRepository(firestore: firestore),
          anonymizer: TesterAnonymizer(),
          testerId: 'tester-a',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('tester-history-row-g1')), findsOneWidget);
    expect(find.byKey(const Key('tester-history-row-g2')), findsOneWidget);
    expect(find.byKey(const Key('tester-history-row-g3')), findsNothing);
    expect(find.text('救済者　先攻　勝ち'), findsOneWidget);
    expect(find.text('執行者　先攻　勝ち'), findsOneWidget);
    expect(find.textContaining('全2戦　勝ち2'), findsOneWidget);
  });

  testWidgets('記録が無い場合は0件メッセージを表示する', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminTesterHistoryScreen(
          repository: AdminPlaytestRepository(firestore: firestore),
          anonymizer: TesterAnonymizer(),
          testerId: 'nobody',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('tester-history-empty')), findsOneWidget);
  });
}
