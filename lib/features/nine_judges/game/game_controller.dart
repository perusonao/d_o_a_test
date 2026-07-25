import 'dart:async';
import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_player.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/foundation.dart';

class NineJudgesController extends ChangeNotifier {
  factory NineJudgesController({
    Random? random,
    int? seed,
    NineJudgesGameSettings settings = const NineJudgesGameSettings(),
    GameLogRepository? logRepository,
  }) {
    final resolvedSeed =
        seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    return NineJudgesController._(
      random ?? Random(resolvedSeed),
      resolvedSeed,
      settings,
      logRepository ?? MemoryGameLogRepository(),
    );
  }

  NineJudgesController._(
    this._random,
    this.seed,
    this.settings,
    this.logRepository,
  ) {
    reset();
  }

  final Random _random;
  final int seed;
  final GameLogRepository logRepository;
  NineJudgesGameSettings settings;
  late List<BoardSlot> board;
  late Map<Faction, ActionInventory> inventories;
  final Map<Faction, Set<int>> knownAttributeSlots = {
    Faction.savior: <int>{},
    Faction.executor: <int>{},
  };
  final Map<Faction, Set<int>> initialKnowledgeSlots = {
    Faction.savior: <int>{},
    Faction.executor: <int>{},
  };
  final Map<Faction, Set<int>> eyeKnowledgeSlots = {
    Faction.savior: <int>{},
    Faction.executor: <int>{},
  };
  late Map<Faction, int> actionsUsed;
  final List<GameLogEntry> logs = [];
  final Map<String, Faction> judgedBy = {};
  final Map<String, int> judgedTurn = {};

  late Faction currentPlayer;
  late GameSession session;
  TurnPhase phase = TurnPhase.selectingAction;
  ActionType? selectedAction;
  int? selectedSlot;
  int turn = 1;
  bool awaitingHandoff = false;
  bool debugMode = false;
  bool cpuActing = false;
  bool _finished = false;
  bool _saved = false;
  Future<void>? _saveFuture;
  String? endReason;
  String? lastCpuActionMessage;
  int? lastCpuTargetIndex;
  ActionType? lastCpuActionType;
  bool lastCpuWasJudgment = false;
  List<CpuCandidateScore> lastCpuEvaluations = const [];
  double? _pendingCpuScore;
  String? _pendingCpuReason;

  int get judgedCount => board.where((s) => s.person.isJudged).length;
  bool get isFinished => _finished;
  ScoreResult get score => NineJudgesRules.calculateScore(board);
  ActionInventory get currentInventory => inventories[currentPlayer]!;
  ActionInventory inventoryFor(Faction faction) => inventories[faction]!;
  bool get isCpuGame => settings.mode == GameMode.cpu;
  bool get isCpuTurn =>
      isCpuGame && currentPlayer == settings.cpuFaction && !isFinished;
  bool get humanInputEnabled => !isCpuTurn || cpuActing;
  Faction get humanFaction => settings.cpuFaction.opponent;
  int actionsUsedBy(Faction faction) => actionsUsed[faction]!;
  int actionsRemainingFor(Faction faction) =>
      NineJudgesConfig.maxActionsPerPlayer - actionsUsedBy(faction);

  void reset() {
    _resolveRandomSettings();
    board = NineJudgesRules.createBoard(_random);
    inventories = {
      Faction.savior: NineJudgesConfig.initialInventory,
      Faction.executor: NineJudgesConfig.initialInventory,
    };
    actionsUsed = {Faction.savior: 0, Faction.executor: 0};
    for (final known in knownAttributeSlots.values) {
      known.clear();
    }
    for (final known in initialKnowledgeSlots.values) {
      known.clear();
    }
    for (final known in eyeKnowledgeSlots.values) {
      known.clear();
    }
    final rankThreeSlots = [
      for (var i = 0; i < board.length; i++)
        if (board[i].person.rank == 3) i,
    ]..shuffle(_random);
    initialKnowledgeSlots[Faction.savior]!.add(rankThreeSlots[0]);
    initialKnowledgeSlots[Faction.executor]!.add(rankThreeSlots[1]);
    knownAttributeSlots[Faction.savior]!.add(rankThreeSlots[0]);
    knownAttributeSlots[Faction.executor]!.add(rankThreeSlots[1]);
    logs.clear();
    judgedBy.clear();
    judgedTurn.clear();
    currentPlayer = settings.firstPlayer;
    phase = TurnPhase.selectingAction;
    selectedAction = null;
    selectedSlot = null;
    turn = 1;
    awaitingHandoff = false;
    cpuActing = false;
    _finished = false;
    _saved = false;
    _saveFuture = null;
    endReason = null;
    lastCpuActionMessage = null;
    lastCpuTargetIndex = null;
    lastCpuActionType = null;
    lastCpuWasJudgment = false;
    lastCpuEvaluations = const [];
    final now = DateTime.now();
    session = GameSession(
      gameId: '${now.microsecondsSinceEpoch}-$seed',
      startedAt: now,
      gameVersion: NineJudgesConfig.gameVersion,
      rulesVersion: NineJudgesConfig.rulesVersion,
      mode: settings.mode.name,
      playerFaction: isCpuGame ? humanFaction.name : Faction.savior.name,
      cpuFaction: isCpuGame ? settings.cpuFaction.name : '',
      firstPlayer: currentPlayer.name,
      cpuDifficulty: isCpuGame ? settings.cpuLevel.strategyLabel : '',
      seed: seed,
      initialBoard: [
        for (var i = 0; i < board.length; i++)
          LoggedPerson(
            personId: board[i].person.id,
            attribute: board[i].person.attribute.name,
            rank: board[i].person.rank,
            initialAlive: board[i].person.isAlive,
            positionIndex: i,
          ),
      ],
      initialKnowledge: {
        for (final faction in Faction.values)
          faction.name: InitialKnowledgeLog(
            personId: board[initialKnowledgeSlots[faction]!.single].person.id,
            attribute: board[initialKnowledgeSlots[faction]!.single]
                .person
                .attribute
                .name,
          ),
      },
    );
    notifyListeners();
  }

  void _resolveRandomSettings() {
    if (settings.mode != GameMode.cpu) return;
    final human = switch (settings.factionSelection) {
      FactionSelection.savior => Faction.savior,
      FactionSelection.executor => Faction.executor,
      FactionSelection.random =>
        _random.nextBool() ? Faction.savior : Faction.executor,
    };
    final humanStarts = switch (settings.firstPlayerSelection) {
      FirstPlayerSelection.human => true,
      FirstPlayerSelection.cpu => false,
      FirstPlayerSelection.random => _random.nextBool(),
    };
    settings = settings.copyWith(
      cpuFaction: human.opponent,
      firstPlayer: humanStarts ? human : human.opponent,
    );
  }

  void reshuffle() => reset();
  void setDebugMode(bool value) {
    debugMode = value;
    notifyListeners();
  }

  void updateSettings(NineJudgesGameSettings value) {
    settings = value;
    notifyListeners();
  }

  bool knowsNumber(int index, Faction viewer) =>
      NineJudgesConfig.numberCardsEnabled && (debugMode || isFinished);
  bool eyeKnowsNumber(int index, Faction viewer) => false;

  bool knowsAttribute(PersonCard person, Faction viewer) {
    if (debugMode || isFinished || !person.hidesAttributeWhenDead) return true;
    final index = board.indexWhere((slot) => slot.person.id == person.id);
    return index >= 0 &&
        (knownAttributeSlots[viewer]!.contains(index) ||
            inferredAttribute(index, viewer) != null);
  }

  bool eyeKnowsAttribute(int index, Faction viewer) =>
      eyeKnowledgeSlots[viewer]!.contains(index);

  bool initiallyKnowsAttribute(int index, Faction viewer) =>
      initialKnowledgeSlots[viewer]!.contains(index);

  PersonAttribute? inferredAttribute(int index, Faction viewer) =>
      NineJudgesRules.inferRank3Attribute(
        rankThreePeople: [
          for (final slot in board)
            if (slot.person.rank == 3) slot.person,
        ],
        knownPersonIds: {
          for (final knownIndex in knownAttributeSlots[viewer]!)
            board[knownIndex].person.id,
        },
        targetPersonId: board[index].person.id,
      );

  List<EyeInformation> availableEyeInformation(int index, Faction viewer) {
    final person = board[index].person;
    return person.rank == 3 &&
            !person.isAlive &&
            !person.isJudged &&
            !knowsAttribute(person, viewer)
        ? const [EyeInformation.attribute]
        : const [];
  }

  bool canSelectAction(ActionType action) =>
      humanInputEnabled &&
      phase == TurnPhase.selectingAction &&
      actionsRemainingFor(currentPlayer) > 0 &&
      inventoryFor(currentPlayer).remaining(action) > 0 &&
      _legalTargets(action, currentPlayer).isNotEmpty;

  List<int> _legalTargets(ActionType action, Faction viewer) => [
    for (var i = 0; i < board.length; i++)
      if (NineJudgesRules.canUseAction(
        action: action,
        person: board[i].person,
        viewerKnowsNumber: true,
        viewerKnowsAttribute: knowsAttribute(board[i].person, viewer),
      ))
        i,
  ];

  bool hasLegalAction(Faction faction) {
    if (actionsRemainingFor(faction) <= 0) return false;
    final hand = inventoryFor(faction);
    return ActionType.values.any(
      (action) =>
          hand.remaining(action) > 0 &&
          _legalTargets(action, faction).isNotEmpty,
    );
  }

  void chooseAction(ActionType action) {
    if (!canSelectAction(action)) return;
    selectedAction = action;
    selectedSlot = null;
    phase = TurnPhase.selectingActionTarget;
    notifyListeners();
  }

  bool canTarget(int index) =>
      humanInputEnabled &&
      phase == TurnPhase.selectingActionTarget &&
      selectedAction != null &&
      _legalTargets(selectedAction!, currentPlayer).contains(index);

  void selectSlot(int index) {
    if (!canTarget(index)) return;
    selectedSlot = index;
    if (selectedAction == ActionType.eye) {
      phase = TurnPhase.selectingEyeInformation;
      notifyListeners();
    } else {
      _applyAction(index);
    }
  }

  void revealEyeInformation(EyeInformation information) {
    final index = selectedSlot;
    if (phase != TurnPhase.selectingEyeInformation ||
        index == null ||
        information != EyeInformation.attribute ||
        !availableEyeInformation(index, currentPlayer).contains(information)) {
      return;
    }
    final actor = currentPlayer;
    final before = board[index].person;
    final actorBefore = inventoryFor(actor);
    final opponentBefore = inventoryFor(actor.opponent);
    inventories[actor] = actorBefore.consume(ActionType.eye);
    logs.add(GameLogEntry(turn: turn, player: actor, message: 'EYEを使用'));
    knownAttributeSlots[actor]!.add(index);
    eyeKnowledgeSlots[actor]!.add(index);
    final after = before.copyWith(isUnderReview: true);
    board[index] = board[index].copyWith(person: after);
    _recordAction(
      action: ActionType.eye,
      index: index,
      actor: actor,
      before: before,
      after: after,
      actorBefore: actorBefore,
      opponentBefore: opponentBefore,
      eyeResult: before.attribute.name,
      knowledgeSource: 'eye',
    );
    _finishAction('人物3を調査しました', action: ActionType.eye, targetIndex: index);
  }

  void cancelEyeInformation() {
    if (phase != TurnPhase.selectingEyeInformation) return;
    selectedSlot = null;
    phase = TurnPhase.selectingActionTarget;
    notifyListeners();
  }

  void _applyAction(int index) {
    final action = selectedAction!;
    final actor = currentPlayer;
    final slot = board[index];
    final before = slot.person;
    final actorBefore = inventoryFor(actor);
    final opponentBefore = inventoryFor(actor.opponent);
    var after = before;
    var detail = '';
    switch (action) {
      case ActionType.life:
        after = before.isAlive
            ? before.copyWith(hasLifeShield: true, isUnderReview: true)
            : before.copyWith(isAlive: true, isUnderReview: true);
        detail = before.isAlive ? '${after.id}にLIFE防護' : '${after.id}が生になりました';
      case ActionType.death:
        after = !before.isAlive
            ? before.copyWith(isJudged: true, isUnderReview: false)
            : before.hasLifeShield
            ? before.copyWith(hasLifeShield: false, isUnderReview: true)
            : before.copyWith(isAlive: false, isUnderReview: true);
        detail = !before.isAlive ? '${after.id}を死で判決' : '${after.id}へDEATH';
      case ActionType.judge:
        after = before.copyWith(isJudged: true, isUnderReview: false);
        detail = '${after.id}を${after.isAlive ? '生' : '死'}で判決';
      case ActionType.eye:
        return;
    }
    board[index] = slot.copyWith(person: after);
    inventories[actor] = actorBefore.consume(action);
    if (!before.isJudged && after.isJudged) {
      judgedBy[after.id] = actor;
      judgedTurn[after.id] = turn;
    }
    logs.add(GameLogEntry(turn: turn, player: actor, message: detail));
    _recordAction(
      action: action,
      index: index,
      actor: actor,
      before: before,
      after: after,
      actorBefore: actorBefore,
      opponentBefore: opponentBefore,
    );
    _finishAction(
      _publicActionResult(
        action: action,
        index: index,
        before: before,
        after: after,
      ),
      action: action,
      targetIndex: index,
      judgment:
          action == ActionType.judge ||
          (action == ActionType.death && !before.isAlive),
    );
  }

  String _publicActionResult({
    required ActionType action,
    required int index,
    required PersonCard before,
    required PersonCard after,
  }) {
    final target = knowsAttribute(before, humanFaction)
        ? '${before.attribute.label} ${before.rank}'
        : '人物${before.rank}';
    return switch (action) {
      ActionType.life when !before.isAlive => '$target を「生」にしました',
      ActionType.life => '$target にLIFE防護を付与',
      ActionType.death when !before.isAlive => '$target を「死」で確定',
      ActionType.death when before.hasLifeShield => '$target のLIFE防護を破壊',
      ActionType.death => '$target を「死」にしました',
      ActionType.judge => '$target\n「${after.isAlive ? '生' : '死'}」で判定',
      ActionType.eye => '人物3を調査しました',
    };
  }

  void _recordAction({
    required ActionType action,
    required int index,
    required Faction actor,
    required PersonCard before,
    required PersonCard after,
    required ActionInventory actorBefore,
    required ActionInventory opponentBefore,
    String? eyeResult,
    String knowledgeSource = 'none',
  }) {
    final visible = knowsAttribute(before, actor)
        ? before.attribute.name
        : null;
    session = session.copyWith(
      actions: [
        ...session.actions,
        GameActionLog(
          actionIndex: session.actions.length + 1,
          turnNumber: turn,
          actingPlayer: isCpuGame && actor == settings.cpuFaction
              ? 'cpu'
              : 'player',
          faction: actor.name,
          actionType: action.name,
          targetPersonId: before.id,
          targetRank: before.rank,
          visibleTargetAttributeAtTime: visible,
          actualTargetAttribute: before.attribute.name,
          stateBefore: before.isAlive ? 'alive' : 'dead',
          stateAfter: after.isAlive ? 'alive' : 'dead',
          lifeShieldBefore: before.hasLifeShield,
          lifeShieldAfter: after.hasLifeShield,
          judgedBefore: before.isJudged,
          judgedAfter: after.isJudged,
          eyeResult: eyeResult,
          actorHandBefore: actorBefore.toJson(),
          actorHandAfter: inventoryFor(actor).toJson(),
          opponentHandBefore: opponentBefore.toJson(),
          opponentHandAfter: inventoryFor(actor.opponent).toJson(),
          timestamp: DateTime.now(),
          cpuEvaluationScore: _pendingCpuScore,
          cpuDecisionReason: _pendingCpuReason,
          underReviewBefore: before.isUnderReview,
          underReviewAfter: after.isUnderReview,
          remainingActionsBefore: actionsRemainingFor(actor),
          remainingActionsAfter: actionsRemainingFor(actor) - 1,
          knowledgeSource: knowledgeSource,
        ),
      ],
    );
    _pendingCpuScore = null;
    _pendingCpuReason = null;
  }

  void _finishAction(
    String publicMessage, {
    ActionType? action,
    int? targetIndex,
    bool judgment = false,
  }) {
    actionsUsed[currentPlayer] = actionsUsed[currentPlayer]! + 1;
    if (isCpuTurn) {
      lastCpuActionMessage = publicMessage;
      lastCpuTargetIndex = targetIndex;
      lastCpuActionType = action;
      lastCpuWasJudgment = judgment;
    } else {
      lastCpuActionMessage = null;
      lastCpuTargetIndex = null;
      lastCpuActionType = null;
      lastCpuWasJudgment = false;
    }
    selectedAction = null;
    selectedSlot = null;
    phase = TurnPhase.selectingAction;
    if (_checkFinished()) {
      notifyListeners();
      return;
    }
    currentPlayer = currentPlayer.opponent;
    turn++;
    if (!hasLegalAction(currentPlayer) &&
        hasLegalAction(currentPlayer.opponent)) {
      currentPlayer = currentPlayer.opponent;
    }
    awaitingHandoff = !isCpuGame;
    notifyListeners();
  }

  void clearCpuFeedback() {
    if (lastCpuActionMessage == null) return;
    lastCpuActionMessage = null;
    lastCpuTargetIndex = null;
    lastCpuActionType = null;
    lastCpuWasJudgment = false;
    notifyListeners();
  }

  bool _checkFinished() {
    if (judgedCount == board.length) {
      _completeGame('allJudged');
      return true;
    }
    if (actionsUsed.values.every(
      (used) => used >= NineJudgesConfig.maxActionsPerPlayer,
    )) {
      _completeGame('turnLimit');
      return true;
    }
    if (!hasLegalAction(Faction.savior) && !hasLegalAction(Faction.executor)) {
      _completeGame('noLegalActions');
      return true;
    }
    return false;
  }

  void _completeGame(String reason) {
    _finished = true;
    endReason = reason;
    final result = score;
    session = session.copyWith(
      finishedAt: DateTime.now(),
      winner: result.winner?.name ?? 'draw',
      saviorScore: result.savior,
      executorScore: result.executor,
      totalTurns: turn,
      endReason: reason,
      actionsUsed: {
        for (final faction in Faction.values)
          faction.name: actionsUsedBy(faction),
      },
      actionsRemaining: {
        for (final faction in Faction.values)
          faction.name: actionsRemainingFor(faction),
      },
      finalBoard: [
        for (var i = 0; i < board.length; i++)
          LoggedPerson(
            personId: board[i].person.id,
            attribute: board[i].person.attribute.name,
            rank: board[i].person.rank,
            initialAlive: session.initialBoard[i].initialAlive,
            positionIndex: i,
            finalAlive: board[i].person.isAlive,
            judged: board[i].person.isJudged,
            judgedBy: judgedBy[board[i].person.id]?.name,
            judgedTurn: judgedTurn[board[i].person.id],
            lifeShieldRemaining: board[i].person.hasLifeShield,
            scoringFaction: NineJudgesRules.scoringFaction(
              board[i].person,
            ).name,
            scoreValue: board[i].person.rank,
            eyeSeenBySavior: knownAttributeSlots[Faction.savior]!.contains(i),
            eyeSeenByExecutor: knownAttributeSlots[Faction.executor]!.contains(
              i,
            ),
          ),
      ],
    );
    if (!_saved) {
      _saved = true;
      _saveFuture = logRepository.saveGame(session);
      unawaited(_saveFuture);
    }
  }

  Future<void> ensureLogSaved() async {
    if (isFinished && !_saved) _completeGame(endReason ?? 'finished');
    await _saveFuture;
  }

  Future<void> updatePlaytestFeedback({
    required String notes,
    int? fun,
    int? reading,
    int? luck,
    int? tempo,
  }) async {
    session = session.copyWith(
      notes: notes,
      funRating: fun,
      readingRating: reading,
      luckRating: luck,
      tempoRating: tempo,
    );
    await logRepository.saveGame(session);
    notifyListeners();
  }

  void confirmHandoff() {
    awaitingHandoff = false;
    notifyListeners();
  }

  CpuGameView cpuView() {
    final faction = settings.cpuFaction;
    final legal = <ActionType, List<int>>{};
    for (final action in ActionType.values) {
      if (inventoryFor(faction).remaining(action) <= 0) continue;
      final targets = _legalTargets(action, faction);
      if (targets.isNotEmpty) legal[action] = targets;
    }
    return CpuGameView(
      faction: faction,
      slots: [
        for (var i = 0; i < board.length; i++)
          CpuSlotView(
            index: i,
            person: PersonCard(
              id: knowsAttribute(board[i].person, faction)
                  ? board[i].person.id
                  : 'unknown-slot-$i',
              attribute: knowsAttribute(board[i].person, faction)
                  ? inferredAttribute(i, faction) ?? board[i].person.attribute
                  : PersonAttribute.neutral,
              rank: board[i].person.rank,
              isAlive: board[i].person.isAlive,
              isJudged: board[i].person.isJudged,
              hasLifeShield: board[i].person.hasLifeShield,
              isUnderReview: board[i].person.isUnderReview,
            ),
            knownAttribute: knowsAttribute(board[i].person, faction)
                ? inferredAttribute(i, faction) ?? board[i].person.attribute
                : null,
            knowledgeSource: eyeKnowledgeSlots[faction]!.contains(i)
                ? 'eye'
                : initialKnowledgeSlots[faction]!.contains(i)
                ? 'initial'
                : inferredAttribute(i, faction) != null
                ? 'inference'
                : 'public',
            eyeOptions: availableEyeInformation(i, faction),
          ),
      ],
      inventory: inventoryFor(faction),
      opponentInventory: inventoryFor(faction.opponent),
      remainingActions: actionsRemainingFor(faction),
      opponentRemainingActions: actionsRemainingFor(faction.opponent),
      legalTargets: legal,
    );
  }

  CpuDecision? performCpuAction() {
    if (!isCpuTurn || phase != TurnPhase.selectingAction) return null;
    final strategy = CpuPlayer.strategyFor(settings.cpuLevel, _random);
    final view = cpuView();
    lastCpuEvaluations = strategy.evaluateActions(view)
      ..sort((a, b) => b.score.compareTo(a.score));
    final decision = strategy.decideAction(view);
    _pendingCpuScore = decision.score;
    _pendingCpuReason =
        'Selected ${decision.action.label}; '
        'opponent hand ${view.opponentInventory.toJson()}; '
        'remaining actions ${view.remainingActions}/'
        '${view.opponentRemainingActions}'
        '${view.slots[decision.targetIndex].knowledgeSource == 'inference' ? '; inferred rank-3 attribute by elimination' : ''}';
    cpuActing = true;
    chooseAction(decision.action);
    selectSlot(decision.targetIndex);
    if (decision.action == ActionType.eye) {
      revealEyeInformation(EyeInformation.attribute);
    }
    cpuActing = false;
    notifyListeners();
    return decision;
  }
}
