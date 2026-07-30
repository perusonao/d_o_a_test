import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:dead_or_alive/features/nine_judges/services/app_stats_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage for the play-count hook added this round (see
/// AppStatsRepository.recordPlay, wired into _startGame): a real game start
/// must record exactly one play, and merely showing the mode-select menu
/// (no game started yet) must not.
void main() {
  testWidgets('starting a real game via initialSettings records exactly one play', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = AppStatsRepository(
      firestore: firestore,
      availableOverride: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NineJudgesGameScreen(
          initialSettings: const NineJudgesGameSettings(
            mode: GameMode.cpu,
            skipCpuDelays: true,
          ),
          appStatsRepository: repository,
        ),
      ),
    );
    await tester.pump();

    final doc = await firestore.collection('appStats').doc('plays').get();
    expect(doc.data()!['count'], 1);
  });

  testWidgets('sitting on the mode-select menu (no game started) records no play', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = AppStatsRepository(
      firestore: firestore,
      availableOverride: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NineJudgesGameScreen(appStatsRepository: repository),
      ),
    );
    await tester.pump();

    final snapshot = await firestore.collection('appStats').get();
    expect(snapshot.docs, isEmpty);
  });
}
