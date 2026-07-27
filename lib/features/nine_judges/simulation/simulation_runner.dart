import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_player.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_statistics.dart';

class SimulationRun {
  const SimulationRun({
    required this.config,
    required this.results,
    required this.statistics,
    required this.elapsed,
  });

  final SimulationConfig config;
  final List<SimulationResult> results;
  final SimulationStatistics statistics;
  final Duration elapsed;
}

class SimulationRunner {
  const SimulationRunner();

  SimulationRun run(SimulationConfig config) {
    final stopwatch = Stopwatch()..start();
    final results = <SimulationResult>[
      for (var i = 0; i < config.gameCount; i++) _runGame(config, i),
    ];
    stopwatch.stop();
    return SimulationRun(
      config: config,
      results: results,
      statistics: SimulationStatistics.fromResults(results, config),
      elapsed: stopwatch.elapsed,
    );
  }

  SimulationResult _runGame(SimulationConfig config, int gameIndex) {
    final seed = config.seedFor(gameIndex);
    final setupRandom = Random(seed);
    var board = NineJudgesRules.createBoard(setupRandom);
    final bonuses = NineJudgesRules.createBonusDeck(setupRandom);
    final firstPlayer = switch (config.firstPlayer) {
      SimulationFirstPlayer.savior => Faction.savior,
      SimulationFirstPlayer.executor => Faction.executor,
      SimulationFirstPlayer.alternate =>
        gameIndex.isEven ? Faction.savior : Faction.executor,
      SimulationFirstPlayer.random =>
        Random(seed ^ 0x51f15e).nextBool() ? Faction.savior : Faction.executor,
    };
    final strategies = <Faction, CpuStrategy>{
      Faction.savior: CpuPlayer.strategyFor(
        config.saviorDifficulty,
        Random(seed ^ 0x5a710),
      ),
      Faction.executor: CpuPlayer.strategyFor(
        config.executorDifficulty,
        Random(seed ^ 0xeec70),
      ),
    };
    final known = <Faction, Set<int>>{
      Faction.savior: {6, 7, 8},
      Faction.executor: {0, 1, 2},
    };
    final specialUsed = <Faction, bool>{
      Faction.savior: false,
      Faction.executor: false,
    };
    final reverseUsed = <Faction, bool>{
      Faction.savior: false,
      Faction.executor: false,
    };
    final scores = <Faction, int>{Faction.savior: 0, Faction.executor: 0};
    final privateBonus = <Faction, int?>{
      Faction.savior: bonuses.first,
      Faction.executor: bonuses.first,
    };
    final pendingReveal = <Faction, bool>{
      Faction.savior: false,
      Faction.executor: false,
    };
    final actions = <SimulationActionRecord>[];
    var bonusIndex = 0;
    var actor = firstPlayer;
    var turn = 1;

    while (board.where((slot) => slot.person.isConfirmed).length < 9) {
      if (turn > 256) {
        throw StateError('Simulation did not terminate (seed=$seed).');
      }
      if (pendingReveal[actor]!) {
        privateBonus[actor] = bonuses[bonusIndex];
        pendingReveal[actor] = false;
      }
      final legalTargets = <ActionType, List<int>>{
        for (final action in ActionType.values)
          action: [
            for (var index = 0; index < board.length; index++)
              if (NineJudgesRules.canUseAction(
                action: action,
                person: board[index].person,
                actor: actor,
                actorKnowsAttribute:
                    board[index].person.isConfirmed ||
                    known[actor]!.contains(index),
                specialVerdictUsed: specialUsed[actor]!,
                reverseActionUsed:
                    _isReverse(action, actor) && reverseUsed[actor]!,
              ))
                index,
          ],
      };
      final view = CpuGameView(
        faction: actor,
        slots: [
          for (var index = 0; index < board.length; index++)
            CpuSlotView(
              index: index,
              person: board[index].person,
              knownAttribute:
                  board[index].person.isConfirmed ||
                      known[actor]!.contains(index)
                  ? board[index].person.attribute
                  : null,
            ),
        ],
        legalTargets: legalTargets,
        currentBonus: privateBonus[actor],
        specialVerdictAvailable: !specialUsed[actor]!,
        reverseActionAvailable: !reverseUsed[actor]!,
      );
      final decision = strategies[actor]!.decideAction(view);
      if (!(legalTargets[decision.action] ?? const []).contains(
        decision.targetIndex,
      )) {
        throw StateError('CPU returned an illegal action (seed=$seed).');
      }
      final index = decision.targetIndex;
      final before = board[index].person;
      final knewBefore = before.isConfirmed || known[actor]!.contains(index);
      final wasReverse = _isReverse(decision.action, actor);
      var after = before;
      if (decision.action == ActionType.eye) {
        known[actor]!.add(index);
      } else if (decision.action == ActionType.specialVerdict) {
        specialUsed[actor] = true;
        after = NineJudgesRules.applySpecialVerdict(
          person: before,
          actor: actor,
        );
      } else {
        if (wasReverse) reverseUsed[actor] = true;
        after = NineJudgesRules.applyVerdictAction(
          person: before,
          action: decision.action,
          actor: actor,
        );
      }
      int? awardedBonus;
      if (!before.isConfirmed && after.isConfirmed) {
        final scorer = NineJudgesRules.scoringFaction(after);
        awardedBonus = bonuses[bonusIndex];
        scores[scorer] = scores[scorer]! + awardedBonus;
        after = after.copyWith(
          scoringFaction: scorer,
          awardedBonus: awardedBonus,
        );
        known[Faction.savior]!.add(index);
        known[Faction.executor]!.add(index);
        if (bonusIndex < bonuses.length - 1) {
          bonusIndex++;
          privateBonus[Faction.savior] = null;
          privateBonus[Faction.executor] = null;
          pendingReveal[actor] = false;
          pendingReveal[actor.opponent] = true;
        }
      }
      board[index] = board[index].copyWith(person: after);
      actions.add(
        SimulationActionRecord(
          turn: turn,
          faction: actor,
          action: decision.action,
          targetIndex: index,
          wasReverseAction: wasReverse,
          actorKnewAttributeBefore: knewBefore,
          stateBefore: before.verdictState,
          stateAfter: after.verdictState,
          historyBefore: before.verdictHistory,
          historyAfter: after.verdictHistory,
          verdictBonus: awardedBonus,
        ),
      );
      actor = actor.opponent;
      turn++;
    }
    return _buildResult(
      config: config,
      gameIndex: gameIndex,
      seed: seed,
      firstPlayer: firstPlayer,
      scores: scores,
      board: board,
      actions: actions,
    );
  }

  SimulationResult _buildResult({
    required SimulationConfig config,
    required int gameIndex,
    required int seed,
    required Faction firstPlayer,
    required Map<Faction, int> scores,
    required List<BoardSlot> board,
    required List<SimulationActionRecord> actions,
  }) {
    int count(Faction faction, ActionType action) => actions
        .where((entry) => entry.faction == faction && entry.action == action)
        .length;
    final touchedBy = <int, Set<Faction>>{};
    for (final action in actions) {
      if (action.action == ActionType.life ||
          action.action == ActionType.death) {
        touchedBy.putIfAbsent(action.targetIndex, () => {}).add(action.faction);
      }
    }
    final eyeTargets = <Faction, Set<int>>{
      for (final faction in Faction.values)
        faction: actions
            .where(
              (entry) =>
                  entry.faction == faction && entry.action == ActionType.eye,
            )
            .map((entry) => entry.targetIndex)
            .toSet(),
    };
    final judgeActions = actions
        .where((entry) => entry.action == ActionType.specialVerdict)
        .toList();
    final reverseActions = actions
        .where((entry) => entry.wasReverseAction)
        .toList();
    final saviorBonuses = board
        .where((slot) => slot.person.scoringFaction == Faction.savior)
        .map((slot) => slot.person.awardedBonus!)
        .toList();
    final executorBonuses = board
        .where((slot) => slot.person.scoringFaction == Faction.executor)
        .map((slot) => slot.person.awardedBonus!)
        .toList();
    final saviorScore = scores[Faction.savior]!;
    final executorScore = scores[Faction.executor]!;
    return SimulationResult(
      gameIndex: gameIndex,
      seed: seed,
      winner: saviorScore == executorScore
          ? null
          : saviorScore > executorScore
          ? Faction.savior
          : Faction.executor,
      firstPlayer: firstPlayer,
      saviorScore: saviorScore,
      executorScore: executorScore,
      totalTurns: actions.length,
      endReason: 'allConfirmed',
      saviorEyeCount: count(Faction.savior, ActionType.eye),
      executorEyeCount: count(Faction.executor, ActionType.eye),
      saviorLifeCount: count(Faction.savior, ActionType.life),
      executorLifeCount: count(Faction.executor, ActionType.life),
      saviorDeathCount: count(Faction.savior, ActionType.death),
      executorDeathCount: count(Faction.executor, ActionType.death),
      saviorJudgeUsed: judgeActions.any(
        (entry) => entry.faction == Faction.savior,
      ),
      executorJudgeUsed: judgeActions.any(
        (entry) => entry.faction == Faction.executor,
      ),
      saviorReverseUsed: reverseActions.any(
        (entry) => entry.faction == Faction.savior,
      ),
      executorReverseUsed: reverseActions.any(
        (entry) => entry.faction == Faction.executor,
      ),
      saviorReverseTurn: _reverseTurn(reverseActions, Faction.savior),
      executorReverseTurn: _reverseTurn(reverseActions, Faction.executor),
      confirmedBySavior: board
          .where((slot) => slot.person.confirmedBy == Faction.savior)
          .length,
      confirmedByExecutor: board
          .where((slot) => slot.person.confirmedBy == Faction.executor)
          .length,
      contestedPersonCount: touchedBy.values
          .where((factions) => factions.length > 1)
          .length,
      lifeDeathFlipCount: board.fold(0, (sum, slot) {
        final history = slot.person.verdictHistory;
        return sum +
            [
              for (var i = 1; i < history.length; i++)
                if (history[i] != history[i - 1]) 1,
            ].length;
      }),
      thirdActionConfirmationCount: actions
          .where(
            (entry) =>
                entry.action != ActionType.specialVerdict &&
                entry.historyAfter.length == 3 &&
                entry.stateAfter.isConfirmed,
          )
          .length,
      instantJudgeConfirmationCount: judgeActions.length,
      eyeUniqueTargetsSavior: eyeTargets[Faction.savior]!.length,
      eyeUniqueTargetsExecutor: eyeTargets[Faction.executor]!.length,
      eyeRedundantCountSavior: actions
          .where(
            (entry) =>
                entry.faction == Faction.savior &&
                entry.action == ActionType.eye &&
                entry.actorKnewAttributeBefore,
          )
          .length,
      eyeRedundantCountExecutor: actions
          .where(
            (entry) =>
                entry.faction == Faction.executor &&
                entry.action == ActionType.eye &&
                entry.actorKnewAttributeBefore,
          )
          .length,
      maxVerdictHistoryLength: board
          .map((slot) => slot.person.verdictHistory.length)
          .reduce(max),
      bonusValuesWonBySavior: saviorBonuses,
      bonusValuesWonByExecutor: executorBonuses,
      highBonusWonBySavior: saviorBonuses
          .where((bonus) => bonus >= config.highBonusThreshold)
          .length,
      highBonusWonByExecutor: executorBonuses
          .where((bonus) => bonus >= config.highBonusThreshold)
          .length,
      judgeBonuses: judgeActions
          .map((entry) => entry.verdictBonus)
          .whereType<int>()
          .toList(),
      reverseOutcomeChangedCount: reverseActions.where((entry) {
        final finalState = board[entry.targetIndex].person.verdictState;
        return entry.stateBefore != entry.stateAfter &&
            finalState.isAlive == entry.stateAfter.isAlive;
      }).length,
      finalConfirmedCount: board
          .where((slot) => slot.person.isConfirmed)
          .length,
      actions: List.unmodifiable(actions),
    );
  }

  static bool _isReverse(ActionType action, Faction faction) =>
      (faction == Faction.savior && action == ActionType.death) ||
      (faction == Faction.executor && action == ActionType.life);

  static int? _reverseTurn(
    List<SimulationActionRecord> actions,
    Faction faction,
  ) {
    for (final action in actions) {
      if (action.faction == faction) return action.turn;
    }
    return null;
  }
}
