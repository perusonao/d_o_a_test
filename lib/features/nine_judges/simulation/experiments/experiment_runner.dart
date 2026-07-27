import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_player.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_result.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';

/// Runs one [SimulationConfig] under a [SimulationExperimentConfig].
///
/// This intentionally duplicates (rather than imports and branches inside)
/// the production [SimulationRunner]'s per-game loop: the production
/// simulation, `game_rules.dart`, `game_controller.dart`, the real CPU
/// strategies and the real game screen are never modified by this file. Every
/// experimental rule lives only here, gated by a [SimulationExperimentConfig]
/// toggle, so CONTROL runs (`SimulationExperimentConfig.control`) reproduce
/// production behaviour exactly and remain comparable to the untouched
/// [SimulationRunner] used elsewhere in the codebase.
///
/// Simplifying assumptions used where a rule change has no natural CPU
/// strategy to reuse (documented so measured vs. assumed numbers stay
/// separable):
/// - Experiment C (reverse-JUDGE) uses a small local greedy evaluator instead
///   of [CpuEvaluator], because the shared evaluator's JUDGE scoring assumes
///   JUDGE *confirms* a person, not that it flips one already confirmed.
/// - Experiment B (10th FINAL JUDGE person)'s simultaneous LIFE/DEATH guess
///   is an unbiased 50/50 coin flip per player (dedicated RNG stream), since
///   no CPU strategy input exists for a blind guess with zero information.
class ExperimentSimulationRunner {
  const ExperimentSimulationRunner();

  static const _centerIndices = {3, 4, 5};

  ExperimentSimulationRun run(
    SimulationConfig config,
    SimulationExperimentConfig experiment,
  ) {
    final stopwatch = Stopwatch()..start();
    final outcomes = <ExperimentGameOutcome>[
      for (var i = 0; i < config.gameCount; i++) _runGame(config, experiment, i),
    ];
    stopwatch.stop();
    return ExperimentSimulationRun(
      config: config,
      experiment: experiment,
      outcomes: outcomes,
      elapsed: stopwatch.elapsed,
    );
  }

  ExperimentGameOutcome _runGame(
    SimulationConfig config,
    SimulationExperimentConfig experiment,
    int gameIndex,
  ) {
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

    final attributeViewer = experiment.attributeViewer(firstPlayer);
    final bonusViewer = experiment.bonusViewer(firstPlayer);
    final known = <Faction, Set<int>>{
      Faction.savior: attributeViewer == null
          ? {6, 7, 8}
          : (attributeViewer == Faction.savior
                ? {0, 1, 2, 3, 4, 5, 6, 7, 8}
                : <int>{}),
      Faction.executor: attributeViewer == null
          ? {0, 1, 2}
          : (attributeViewer == Faction.executor
                ? {0, 1, 2, 3, 4, 5, 6, 7, 8}
                : <int>{}),
    };

    int specialBudget(Faction faction) =>
        1 +
        (faction == firstPlayer &&
                experiment.firstPlayerBonusAction ==
                    FirstPlayerBonusAction.specialVerdict
            ? 1
            : 0);
    int reverseBudget(Faction faction) =>
        1 +
        (faction == firstPlayer &&
                experiment.firstPlayerBonusAction ==
                    FirstPlayerBonusAction.reverseAction
            ? 1
            : 0);

    final specialCount = <Faction, int>{Faction.savior: 0, Faction.executor: 0};
    final reverseCount = <Faction, int>{Faction.savior: 0, Faction.executor: 0};
    final scores = <Faction, int>{Faction.savior: 0, Faction.executor: 0};
    final privateBonus = <Faction, int?>{
      Faction.savior: bonuses.first,
      Faction.executor: bonuses.first,
    };
    final pendingReveal = <Faction, bool>{
      Faction.savior: false,
      Faction.executor: false,
    };
    final eyeUsedSlots = <int>{};
    final judgeReversed = <int>{};
    var judgeReversalCount = 0;
    var judgeReversalSwing = 0;
    final reversalEvents = <({Faction oldScorer, Faction newScorer, int bonus})>[];
    int? finalJudgeBaseBonus;
    Faction? finalJudgeScorer;
    final actions = <SimulationActionRecord>[];
    var bonusIndex = 0;
    var actor = firstPlayer;
    var turn = 1;

    while (board.where((slot) => slot.person.isConfirmed).length < 9) {
      if (turn > 256) {
        throw StateError('Experiment simulation did not terminate (seed=$seed).');
      }
      if (bonusViewer != null) {
        privateBonus[bonusViewer] = bonuses[bonusIndex];
        privateBonus[attributeViewer!] = null;
      } else if (pendingReveal[actor]!) {
        privateBonus[actor] = bonuses[bonusIndex];
        pendingReveal[actor] = false;
      }

      if (experiment.judgeVariant == JudgeVariant.reverseConfirmed &&
          specialCount[actor]! < specialBudget(actor)) {
        final reversal = _bestReversal(actor, board, judgeReversed);
        if (reversal != null && reversal.score > 0) {
          final targetIndex = reversal.targetIndex;
          final before = board[targetIndex].person;
          final bonus = before.awardedBonus!;
          final oldScorer = before.scoringFaction!;
          final flippedState = before.verdictState == VerdictState.aliveConfirmed
              ? VerdictState.deadConfirmed
              : VerdictState.aliveConfirmed;
          final flipped = before.copyWith(verdictState: flippedState);
          final newScorer = NineJudgesRules.scoringFaction(flipped);
          final after = flipped.copyWith(scoringFaction: newScorer);
          scores[oldScorer] = scores[oldScorer]! - bonus;
          scores[newScorer] = scores[newScorer]! + bonus;
          board[targetIndex] = board[targetIndex].copyWith(person: after);
          judgeReversed.add(targetIndex);
          specialCount[actor] = specialCount[actor]! + 1;
          judgeReversalCount++;
          if (newScorer != oldScorer) judgeReversalSwing += bonus;
          reversalEvents.add(
            (oldScorer: oldScorer, newScorer: newScorer, bonus: bonus),
          );
          actions.add(
            SimulationActionRecord(
              turn: turn,
              faction: actor,
              action: ActionType.specialVerdict,
              targetIndex: targetIndex,
              wasReverseAction: false,
              actorKnewAttributeBefore: true,
              stateBefore: before.verdictState,
              stateAfter: after.verdictState,
              historyBefore: before.verdictHistory,
              historyAfter: after.verdictHistory,
              targetAttribute: before.attribute,
              currentBonusValue: bonuses[bonusIndex],
              currentBonusKnown: privateBonus[actor] == bonuses[bonusIndex],
              verdictBonus: bonus,
              scoringFaction: newScorer,
            ),
          );
          actor = actor.opponent;
          turn++;
          continue;
        }
      }

      final legalTargets = <ActionType, List<int>>{
        for (final action in ActionType.values)
          action: action == ActionType.specialVerdict &&
                  experiment.judgeVariant == JudgeVariant.reverseConfirmed
              ? const []
              : [
                  for (var index = 0; index < board.length; index++)
                    if (_canUse(
                      action: action,
                      person: board[index].person,
                      actor: actor,
                      actorKnowsAttribute:
                          board[index].person.isConfirmed ||
                          known[actor]!.contains(index),
                      specialVerdictUsed:
                          specialCount[actor]! >= specialBudget(actor),
                      reverseActionUsed:
                          _isReverse(action, actor) &&
                          reverseCount[actor]! >= reverseBudget(actor),
                      inCenterZoneOnly:
                          action == ActionType.eye &&
                          experiment.eyeZoneMode == EyeZoneMode.centerOnly,
                      eyeAlreadyUsedElsewhere:
                          action == ActionType.eye &&
                          experiment.eyeSharedSingleUse &&
                          eyeUsedSlots.contains(index),
                      index: index,
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
        specialVerdictAvailable: specialCount[actor]! < specialBudget(actor),
        reverseActionAvailable: reverseCount[actor]! < reverseBudget(actor),
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
      final currentBonusValue = bonuses[bonusIndex];
      final currentBonusKnown = privateBonus[actor] == currentBonusValue;
      var after = before;
      if (decision.action == ActionType.eye) {
        known[actor]!.add(index);
        eyeUsedSlots.add(index);
      } else if (decision.action == ActionType.specialVerdict) {
        specialCount[actor] = specialCount[actor]! + 1;
        after = NineJudgesRules.applySpecialVerdict(person: before, actor: actor);
      } else {
        if (wasReverse) reverseCount[actor] = reverseCount[actor]! + 1;
        after = NineJudgesRules.applyVerdictAction(
          person: before,
          action: decision.action,
          actor: actor,
        );
      }
      int? awardedBonus;
      int? confirmationOrder;
      if (!before.isConfirmed && after.isConfirmed) {
        final scorer = NineJudgesRules.scoringFaction(after);
        confirmationOrder =
            board.where((slot) => slot.person.isConfirmed).length + 1;
        awardedBonus = bonuses[bonusIndex];
        if (experiment.finalJudgeMode == FinalJudgeMode.doubleBonus &&
            confirmationOrder == 9) {
          finalJudgeBaseBonus = awardedBonus;
          finalJudgeScorer = scorer;
          awardedBonus *= 2;
        }
        scores[scorer] = scores[scorer]! + awardedBonus;
        after = after.copyWith(scoringFaction: scorer, awardedBonus: awardedBonus);
        known[Faction.savior]!.add(index);
        known[Faction.executor]!.add(index);
        if (bonusIndex < bonuses.length - 1) {
          bonusIndex++;
          if (bonusViewer == null) {
            privateBonus[Faction.savior] = null;
            privateBonus[Faction.executor] = null;
            pendingReveal[actor] = false;
            pendingReveal[actor.opponent] = true;
          }
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
          targetAttribute: before.attribute,
          currentBonusValue: currentBonusValue,
          currentBonusKnown: currentBonusKnown,
          verdictBonus: awardedBonus,
          scoringFaction: after.scoringFaction,
          confirmationOrder: confirmationOrder,
        ),
      );
      actor = actor.opponent;
      turn++;
    }

    final extras = <String, Object?>{
      'judgeReversalCount': judgeReversalCount,
      'judgeReversalSwingPoints': judgeReversalSwing,
    };

    if (reversalEvents.isNotEmpty) {
      final withoutReversal = <Faction, int>{
        Faction.savior: scores[Faction.savior]!,
        Faction.executor: scores[Faction.executor]!,
      };
      for (final event in reversalEvents) {
        withoutReversal[event.newScorer] =
            withoutReversal[event.newScorer]! - event.bonus;
        withoutReversal[event.oldScorer] =
            withoutReversal[event.oldScorer]! + event.bonus;
      }
      final winnerWithReversal = scores[Faction.savior]! == scores[Faction.executor]!
          ? null
          : scores[Faction.savior]! > scores[Faction.executor]!
          ? Faction.savior
          : Faction.executor;
      final withoutSavior = withoutReversal[Faction.savior]!;
      final withoutExecutor = withoutReversal[Faction.executor]!;
      final winnerWithoutReversal = withoutSavior == withoutExecutor
          ? null
          : withoutSavior > withoutExecutor
          ? Faction.savior
          : Faction.executor;
      extras['judgeReversalFlippedWinner'] =
          winnerWithReversal != winnerWithoutReversal;
    } else {
      extras['judgeReversalFlippedWinner'] = false;
    }

    var saviorScore = scores[Faction.savior]!;
    var executorScore = scores[Faction.executor]!;
    final saviorScoreBeforeTenth = saviorScore;
    final executorScoreBeforeTenth = executorScore;

    if (experiment.finalJudgeMode == FinalJudgeMode.doubleBonus &&
        finalJudgeBaseBonus != null) {
      final scorer = finalJudgeScorer!;
      final withoutDoubling = <Faction, int>{
        Faction.savior: saviorScore,
        Faction.executor: executorScore,
      };
      withoutDoubling[scorer] = withoutDoubling[scorer]! - finalJudgeBaseBonus;
      final winnerWithDoubling = saviorScore == executorScore
          ? null
          : saviorScore > executorScore
          ? Faction.savior
          : Faction.executor;
      final withoutSavior = withoutDoubling[Faction.savior]!;
      final withoutExecutor = withoutDoubling[Faction.executor]!;
      final winnerWithoutDoubling = withoutSavior == withoutExecutor
          ? null
          : withoutSavior > withoutExecutor
          ? Faction.savior
          : Faction.executor;
      extras['finalJudgeBonusBase'] = finalJudgeBaseBonus;
      extras['finalJudgeBonusFinal'] = finalJudgeBaseBonus * 2;
      extras['finalJudgeScorer'] = scorer.name;
      extras['finalJudgeFlippedWinner'] =
          winnerWithDoubling != winnerWithoutDoubling;
    }

    if (experiment.finalJudgeMode == FinalJudgeMode.tenthPerson) {
      final tenthAttribute =
          PersonAttribute.values[Random(seed ^ 0xF00D10).nextInt(3)];
      final saviorGuess = Random(seed ^ 0xF00D11).nextBool()
          ? ActionType.life
          : ActionType.death;
      final executorGuess = Random(seed ^ 0xF00D22).nextBool()
          ? ActionType.life
          : ActionType.death;
      String outcome;
      Faction? tenthScorer;
      if (saviorGuess == executorGuess) {
        outcome = saviorGuess == ActionType.life ? 'lifeLife' : 'deathDeath';
        final finalState = saviorGuess == ActionType.life
            ? VerdictState.aliveConfirmed
            : VerdictState.deadConfirmed;
        final hypothetical = PersonCard(
          id: 'tenth',
          attribute: tenthAttribute,
          verdictState: finalState,
        );
        tenthScorer = NineJudgesRules.scoringFaction(hypothetical);
        scores[tenthScorer] = scores[tenthScorer]! + 10;
      } else {
        outcome = 'mismatch';
      }
      extras['tenthPersonAttribute'] = tenthAttribute.name;
      extras['tenthPersonOutcome'] = outcome;
      extras['tenthPersonScorer'] = tenthScorer?.name;
      extras['tenthPersonPoints'] = tenthScorer == null ? 0 : 10;
      saviorScore = scores[Faction.savior]!;
      executorScore = scores[Faction.executor]!;
      final winnerBeforeTenth = saviorScoreBeforeTenth == executorScoreBeforeTenth
          ? null
          : saviorScoreBeforeTenth > executorScoreBeforeTenth
          ? Faction.savior
          : Faction.executor;
      final winnerAfterTenth = saviorScore == executorScore
          ? null
          : saviorScore > executorScore
          ? Faction.savior
          : Faction.executor;
      extras['tenthPersonFlippedWinner'] = winnerBeforeTenth != winnerAfterTenth;
    }

    if (experiment.eyeScoreCost > 0) {
      final saviorEyeCount = actions
          .where(
            (entry) =>
                entry.faction == Faction.savior && entry.action == ActionType.eye,
          )
          .length;
      final executorEyeCount = actions
          .where(
            (entry) =>
                entry.faction == Faction.executor &&
                entry.action == ActionType.eye,
          )
          .length;
      final saviorCost = experiment.eyeScoreCost * saviorEyeCount;
      final executorCost = experiment.eyeScoreCost * executorEyeCount;
      extras['saviorScoreBeforeEyeCost'] = saviorScore;
      extras['executorScoreBeforeEyeCost'] = executorScore;
      extras['saviorEyeCost'] = saviorCost;
      extras['executorEyeCost'] = executorCost;
      saviorScore = max(0, saviorScore - saviorCost);
      executorScore = max(0, executorScore - executorCost);
    }

    return ExperimentGameOutcome(
      result: _buildResult(
        config: config,
        gameIndex: gameIndex,
        seed: seed,
        firstPlayer: firstPlayer,
        saviorScore: saviorScore,
        executorScore: executorScore,
        board: board,
        actions: actions,
      ),
      extras: extras,
    );
  }

  ({int targetIndex, double score})? _bestReversal(
    Faction actor,
    List<BoardSlot> board,
    Set<int> judgeReversed,
  ) {
    ({int targetIndex, double score})? best;
    for (var index = 0; index < board.length; index++) {
      final person = board[index].person;
      if (!person.isConfirmed || judgeReversed.contains(index)) continue;
      final bonus = person.awardedBonus!;
      final flippedState = person.verdictState == VerdictState.aliveConfirmed
          ? VerdictState.deadConfirmed
          : VerdictState.aliveConfirmed;
      final flipped = person.copyWith(verdictState: flippedState);
      final newScorer = NineJudgesRules.scoringFaction(flipped);
      final gain = newScorer == actor ? bonus.toDouble() : -bonus.toDouble();
      final score = gain - (newScorer == actor ? 0 : 2);
      if (best == null || score > best.score) {
        best = (targetIndex: index, score: score);
      }
    }
    return best;
  }

  bool _canUse({
    required ActionType action,
    required PersonCard person,
    required Faction actor,
    required bool actorKnowsAttribute,
    required bool specialVerdictUsed,
    required bool reverseActionUsed,
    required bool inCenterZoneOnly,
    required bool eyeAlreadyUsedElsewhere,
    required int index,
  }) {
    if (action == ActionType.eye) {
      if (inCenterZoneOnly && !_centerIndices.contains(index)) return false;
      if (eyeAlreadyUsedElsewhere) return false;
    }
    return NineJudgesRules.canUseAction(
      action: action,
      person: person,
      actor: actor,
      actorKnowsAttribute: actorKnowsAttribute,
      specialVerdictUsed: specialVerdictUsed,
      reverseActionUsed: reverseActionUsed,
    );
  }

  SimulationResult _buildResult({
    required SimulationConfig config,
    required int gameIndex,
    required int seed,
    required Faction firstPlayer,
    required int saviorScore,
    required int executorScore,
    required List<BoardSlot> board,
    required List<SimulationActionRecord> actions,
  }) {
    int count(Faction faction, ActionType action) => actions
        .where((entry) => entry.faction == faction && entry.action == action)
        .length;
    final touchedBy = <int, Set<Faction>>{};
    for (final action in actions) {
      if (action.action == ActionType.life || action.action == ActionType.death) {
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
    final reverseActions = actions.where((entry) => entry.wasReverseAction).toList();
    final saviorBonuses = board
        .where((slot) => slot.person.scoringFaction == Faction.savior)
        .map((slot) => slot.person.awardedBonus!)
        .toList();
    final executorBonuses = board
        .where((slot) => slot.person.scoringFaction == Faction.executor)
        .map((slot) => slot.person.awardedBonus!)
        .toList();
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
      saviorJudgeUsed: judgeActions.any((entry) => entry.faction == Faction.savior),
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
      judgeBonuses: judgeActions.map((entry) => entry.verdictBonus).whereType<int>().toList(),
      reverseOutcomeChangedCount: reverseActions.where((entry) {
        final finalState = board[entry.targetIndex].person.verdictState;
        return entry.stateBefore != entry.stateAfter &&
            finalState.isAlive == entry.stateAfter.isAlive;
      }).length,
      finalConfirmedCount: board.where((slot) => slot.person.isConfirmed).length,
      actions: List.unmodifiable(actions),
    );
  }

  static bool _isReverse(ActionType action, Faction faction) =>
      (faction == Faction.savior && action == ActionType.death) ||
      (faction == Faction.executor && action == ActionType.life);

  static int? _reverseTurn(List<SimulationActionRecord> actions, Faction faction) {
    for (final action in actions) {
      if (action.faction == faction) return action.turn;
    }
    return null;
  }
}

class ExperimentSimulationRun {
  const ExperimentSimulationRun({
    required this.config,
    required this.experiment,
    required this.outcomes,
    required this.elapsed,
  });

  final SimulationConfig config;
  final SimulationExperimentConfig experiment;
  final List<ExperimentGameOutcome> outcomes;
  final Duration elapsed;

  List<SimulationResult> get results =>
      [for (final outcome in outcomes) outcome.result];
}
