import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_log.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/rules/rules_guide_screen.dart';
import 'package:dead_or_alive/features/nine_judges/services/external_test_profile.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../tool/run_external_test_analysis.dart' as analysis_cli;

void main() {
  group('外部テスト用プロフィール(testerId/playNumber/firstGame)', () {
    test('testerIdは初回に生成され、以後同じ値を返す', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await ExternalTestProfile.loadForNewGame();
      final second = await ExternalTestProfile.loadForNewGame();
      expect(first.testerId, isNotEmpty);
      expect(first.testerId, second.testerId);
    });

    test('recordGameFinishedのたびにplayNumberが増え、isFirstGameは初回のみtrue', () async {
      SharedPreferences.setMockInitialValues({});
      final p1 = await ExternalTestProfile.loadForNewGame();
      expect(p1.playNumber, 1);
      expect(p1.isFirstGame, isTrue);
      await p1.recordGameFinished();

      final p2 = await ExternalTestProfile.loadForNewGame();
      expect(p2.playNumber, 2);
      expect(p2.isFirstGame, isFalse);
      await p2.recordGameFinished();

      final p3 = await ExternalTestProfile.loadForNewGame();
      expect(p3.playNumber, 3);
      expect(p3.isFirstGame, isFalse);
    });

    test('チュートリアルの完了/スキップ状態が端末に永続化される', () async {
      SharedPreferences.setMockInitialValues({});
      var profile = await ExternalTestProfile.loadForNewGame();
      expect(profile.hasCompletedTutorial, isFalse);
      expect(profile.hasSkippedTutorial, isFalse);

      await ExternalTestProfile.markTutorialCompleted();
      profile = await ExternalTestProfile.loadForNewGame();
      expect(profile.hasCompletedTutorial, isTrue);
    });

    test('applyExternalTestContextでセッションに識別情報が反映される', () {
      final game = NineJudgesController(seed: 9001);
      game.applyExternalTestContext(
        const ExternalTestProfile(
          testerId: 'tester-abc',
          playNumber: 2,
          isFirstGame: false,
          hasCompletedTutorial: true,
          hasSkippedTutorial: false,
        ),
      );
      expect(game.session.testerId, 'tester-abc');
      expect(game.session.playNumber, 2);
      expect(game.session.isFirstGame, isFalse);
      expect(game.session.completedTutorial, isTrue);
      expect(game.session.tutorialSkipped, isFalse);
      expect(game.session.testCohort, NineJudgesConfig.testCohort);
      expect(game.session.sessionId, isNotEmpty);
    });
  });

  group('アンケート強化(rating保存・feedbackComment)', () {
    test('新規5項目とfeedbackCommentが保存される', () async {
      final game = NineJudgesController(seed: 9002);
      await game.updatePlaytestFeedback(
        notes: 'memo',
        fun: 5,
        ruleUnderstanding: 4,
        judgeUsefulness: 3,
        eyeTension: 2,
        strategicDepth: 5,
        replayIntent: 4,
        feedbackComment: '分かりづらかった点があった',
      );
      expect(game.session.ruleUnderstandingRating, 4);
      expect(game.session.judgeUsefulnessRating, 3);
      expect(game.session.eyeTensionRating, 2);
      expect(game.session.strategicDepthRating, 5);
      expect(game.session.replayIntentRating, 4);
      expect(game.session.feedbackComment, '分かりづらかった点があった');
    });
  });

  group('旧ログとの互換性(nullable/additive)', () {
    test('新フィールドの無いGameSession JSONも例外なく読み込める', () {
      final legacy = {
        'gameId': 'legacy-1',
        'startedAt': DateTime(2024, 1, 1).toIso8601String(),
        'gameVersion': '1.0.0',
        'rulesVersion': '1.1',
        'mode': 'cpu',
        'playerFaction': 'savior',
        'cpuFaction': 'executor',
        'firstPlayer': 'savior',
        'cpuDifficulty': 'balanced',
        'seed': 1,
      };
      final session = GameSession.fromJson(legacy);
      expect(session.testerId, isNull);
      expect(session.playNumber, isNull);
      expect(session.isFirstGame, isNull);
      expect(session.feedbackComment, isNull);
      expect(session.ruleUnderstandingRating, isNull);
      expect(session.judgeOpportunityCountSavior, isNull);
      expect(session.gameAbandoned, isNull);
    });

    test('新フィールドの無いGameActionLog JSONも例外なく読み込める', () {
      final legacy = {
        'actionIndex': 1,
        'turnNumber': 1,
        'actingPlayer': 'player',
        'faction': 'savior',
        'actionType': 'life',
        'targetPersonId': 'p0',
        'targetRank': 0,
        'visibleTargetAttributeAtTime': null,
        'actualTargetAttribute': 'good',
        'stateBefore': 'deliberating',
        'stateAfter': 'alive',
        'lifeShieldBefore': false,
        'lifeShieldAfter': false,
        'judgedBefore': false,
        'judgedAfter': false,
        'actorHandBefore': <String, int>{},
        'actorHandAfter': <String, int>{},
        'opponentHandBefore': <String, int>{},
        'opponentHandAfter': <String, int>{},
        'timestamp': DateTime(2024, 1, 1).toIso8601String(),
      };
      final log = GameActionLog.fromJson(legacy);
      expect(log.turnDecisionTimeMs, isNull);
      expect(log.eyeCandidateCount, isNull);
    });
  });

  group('turnDecisionTimeMs / EYE候補数 / JUDGE機会ログ', () {
    test('人間の手番にはturnDecisionTimeMsが記録され、CPUの手番はnull', () {
      final game = NineJudgesController(
        seed: 9003,
        settings: const NineJudgesGameSettings(
          mode: GameMode.cpu,
          cpuFaction: Faction.executor,
          firstPlayer: Faction.savior,
          skipCpuDelays: true,
        ),
      );
      game.chooseAction(ActionType.life);
      game.selectSlot(7);
      final humanLog = game.session.actions.single;
      expect(humanLog.faction, 'savior');
      expect(humanLog.turnDecisionTimeMs, isNotNull);

      game.confirmHandoff();
      game.performCpuAction();
      final cpuLog = game.session.actions.last;
      expect(cpuLog.faction, 'executor');
      expect(cpuLog.turnDecisionTimeMs, isNull);
    });

    test('EYEのeyeCandidateCountは実行時点の合法対象数を反映する', () {
      final game = NineJudgesController(seed: 9004);
      game.chooseAction(ActionType.eye);
      game.selectSlot(3);
      expect(game.session.actions.single.eyeCandidateCount, 3);
      game.confirmHandoff();

      // 執行者はまだ何も見ていないため、中央3人すべてが候補のまま。
      game.chooseAction(ActionType.eye);
      expect(game.session.actions.length, 1);
      game.selectSlot(4);
      expect(game.session.actions.last.eyeCandidateCount, 3);
      game.confirmHandoff();

      // 救済者は自分がEYE済みの3を除いた{4,5}が候補(4は執行者しか知らない)。
      game.chooseAction(ActionType.eye);
      final saviorCandidates = [
        for (var i = 0; i < 9; i++)
          if (game.canTarget(i)) i,
      ];
      expect(saviorCandidates, unorderedEquals([4, 5]));
    });

    test('JUDGE機会カウントは未使用かつ合法対象がある手番ごとに増え、使用後は増えない', () {
      final game = NineJudgesController(seed: 9005);
      expect(game.judgeOpportunityCount[Faction.savior], 0);

      game.chooseAction(ActionType.life);
      game.selectSlot(7); // savior turn 1: JUDGE available & unused -> +1
      expect(game.judgeOpportunityCount[Faction.savior], 1);
      game.confirmHandoff();

      game.chooseAction(ActionType.death);
      game.selectSlot(0); // executor turn 1
      expect(game.judgeOpportunityCount[Faction.executor], 1);
      game.confirmHandoff();

      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(
        1,
      ); // savior turn 2: still unused at turn start -> +1, then consumes JUDGE
      expect(game.judgeOpportunityCount[Faction.savior], 2);
      expect(game.specialVerdictAvailable(Faction.savior), isFalse);
      game.confirmHandoff();

      game.chooseAction(ActionType.death);
      game.selectSlot(2); // executor turn 2
      game.confirmHandoff();

      game.chooseAction(ActionType.life);
      game.selectSlot(
        4,
      ); // savior turn 3: JUDGE already used -> no further increment
      expect(game.judgeOpportunityCount[Faction.savior], 2);
    });
  });

  group('チュートリアル/ルール画面の計測イベント', () {
    testWidgets('完走するとtutorialStarted/StepReached/Completedが記録される', (
      tester,
    ) async {
      final repo = MemoryTutorialEventRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: TutorialScreen(
            eventRepository: repo,
            beatDuration: Duration.zero,
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byKey(const Key('tutorial-next')));
        await tester.pump();
        // A zero-duration outcome-beat still schedules a real Timer — a bare
        // pump() doesn't reliably elapse it, so pump explicit tiny durations
        // (up to two chained beats for the steps that run a CPU action then
        // the player's own follow-up).
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.tap(find.byKey(const Key('tutorial-complete')));
      await tester.pump();

      final types = repo.events.map((e) => e.type).toList();
      expect(types, contains('tutorialStarted'));
      expect(types, contains('tutorialCompleted'));
      expect(
        types.where((t) => t == 'tutorialStepReached').length,
        greaterThanOrEqualTo(10),
      );
    });

    testWidgets('最後まで進めずに離脱するとtutorialSkippedが記録される', (tester) async {
      final repo = MemoryTutorialEventRepository();
      await tester.pumpWidget(
        MaterialApp(home: TutorialScreen(eventRepository: repo)),
      );
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      final skipped = repo.events
          .where((e) => e.type == 'tutorialSkipped')
          .toList();
      expect(skipped, hasLength(1));
      expect(skipped.single.step, 2);
    });

    testWidgets('遊び方を開いて閉じるとrulesOpened/rulesClosedが記録される', (tester) async {
      final repo = MemoryTutorialEventRepository();
      await tester.pumpWidget(
        MaterialApp(home: RulesGuideScreen(eventRepository: repo)),
      );
      await tester.pump(const Duration(milliseconds: 5));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(repo.events.map((e) => e.type).toList(), [
        'rulesOpened',
        'rulesClosed',
      ]);
      expect(repo.events.last.rulesReadDurationMs, isNotNull);
    });
  });

  group('外部テスト分析CLIの集計整合性', () {
    test('勝率・評価平均・EYE/JUDGE集計が入力セッションから正しく計算される', () {
      GameSession session({
        required String tester,
        required int playNumber,
        required bool isFirstGame,
        required String winner,
        required String firstPlayer,
        required int fun,
        List<GameActionLog> actions = const [],
      }) => GameSession(
        gameId: '$tester-$playNumber',
        startedAt: DateTime(2024, 1, 1),
        gameVersion: '1.3.0-external-test-beta',
        rulesVersion: '1.2',
        mode: 'cpu',
        playerFaction: 'savior',
        cpuFaction: 'executor',
        firstPlayer: firstPlayer,
        cpuDifficulty: 'balanced',
        seed: playNumber,
        initialBoard: const [],
        winner: winner,
        saviorScore: winner == 'savior' ? 30 : 15,
        executorScore: winner == 'savior' ? 15 : 30,
        totalTurns: 20,
        actions: actions,
        testerId: tester,
        playNumber: playNumber,
        isFirstGame: isFirstGame,
        funRating: fun,
      );

      GameActionLog eyeAction(int candidateCount) => GameActionLog(
        actionIndex: 1,
        turnNumber: 1,
        actingPlayer: 'player',
        faction: 'savior',
        actionType: 'eye',
        targetPersonId: 'p0',
        targetRank: 0,
        visibleTargetAttributeAtTime: null,
        actualTargetAttribute: 'good',
        stateBefore: 'deliberating',
        stateAfter: 'deliberating',
        lifeShieldBefore: false,
        lifeShieldAfter: false,
        judgedBefore: false,
        judgedAfter: false,
        actorHandBefore: const {},
        actorHandAfter: const {},
        opponentHandBefore: const {},
        opponentHandAfter: const {},
        timestamp: DateTime(2024, 1, 1),
        eyeCandidateCount: candidateCount,
      );

      final sessions = [
        session(
          tester: 't1',
          playNumber: 1,
          isFirstGame: true,
          winner: 'savior',
          firstPlayer: 'savior',
          fun: 5,
          actions: [eyeAction(3)],
        ),
        session(
          tester: 't1',
          playNumber: 2,
          isFirstGame: false,
          winner: 'executor',
          firstPlayer: 'executor',
          fun: 3,
          actions: [eyeAction(1)],
        ),
        session(
          tester: 't2',
          playNumber: 1,
          isFirstGame: true,
          winner: 'savior',
          firstPlayer: 'savior',
          fun: 4,
        ),
      ];

      final report = analysis_cli.ExternalTestReport.build(
        sessions: sessions,
        tutorialEvents: const [],
        oneSidedThreshold: 15,
      );

      expect(report.uniqueTesterCount, 2);
      expect(report.values['gameCount'], 3);
      expect(report.values['saviorWinRate'], closeTo(2 / 3, 1e-9));
      expect(report.values['executorWinRate'], closeTo(1 / 3, 1e-9));
      // 全3戦とも先手が勝利しているので先手勝率は100%。
      expect(report.values['firstPlayerWinRate'], 1.0);

      final ratings = report.values['ratings'] as Map<String, double?>;
      expect(ratings['fun'], closeTo((5 + 3 + 4) / 3, 1e-9));

      final ratingsFirst =
          report.values['ratingsFirstGame'] as Map<String, double?>;
      expect(ratingsFirst['fun'], closeTo((5 + 4) / 2, 1e-9));

      final eye = report.values['eye'] as Map<String, Object?>;
      expect(eye['averageCandidateCount'], closeTo(2.0, 1e-9));
      expect(eye['candidateCountOneRate'], closeTo(0.5, 1e-9));
    });
  });

  group('rulesVersion 1.2が今回の変更で書き換わっていないこと', () {
    test('EYEの中央制限・上限2回は不変', () {
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

    test('10,000戦(rules 1.2, Balanced vs Balanced)は正常終了し再現性がある', () {
      const config = SimulationConfig(
        gameCount: 10000,
        baseSeed: 9500,
        ruleVersion: NineJudgesRuleVersion.v1_2,
      );
      final first = const SimulationRunner().run(config);
      expect(first.results, hasLength(10000));
      for (final result in first.results) {
        expect(result.finalConfirmedCount, 9);
        expect(result.saviorScore + result.executorScore, 45);
        expect(result.saviorEyeCount, lessThanOrEqualTo(2));
        expect(result.executorEyeCount, lessThanOrEqualTo(2));
      }
      // 計測処理(このラウンドの変更)はSimulationRunner/NineJudgesRulesに一切触れて
      // いないため、同一設定は常に同一結果になる — 実行するたびに確認する。
      final second = const SimulationRunner().run(config);
      expect(
        first.results.map((r) => r.toJson()).toList(),
        second.results.map((r) => r.toJson()).toList(),
      );
    });
  });
}
