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
  late List<int> bonusDeck;
  late Map<Faction, bool> specialVerdictUsed;
  final Map<Faction, Set<int>> knownAttributeSlots = {
    Faction.savior: <int>{},
    Faction.executor: <int>{},
  };
  final Map<Faction, Set<int>> eyeSeenSlots = {
    Faction.savior: <int>{},
    Faction.executor: <int>{},
  };
  final Map<Faction, int?> privateBonusKnowledge = {
    Faction.savior: null,
    Faction.executor: null,
  };
  final Map<Faction, bool> pendingBonusReveal = {
    Faction.savior: false,
    Faction.executor: false,
  };
  final Map<Faction, int> scores = {Faction.savior: 0, Faction.executor: 0};
  final List<GameLogEntry> logs = [];

  late Faction currentPlayer;
  late GameSession session;
  TurnPhase phase = TurnPhase.selectingAction;
  ActionType? selectedAction;
  int? selectedSlot;
  int turn = 1;
  int bonusIndex = 0;
  bool awaitingHandoff = false;
  bool awaitingBonusReveal = false;
  bool awaitingConfirmationReveal = false;
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
  String? confirmationRevealMessage;
  List<CpuCandidateScore> lastCpuEvaluations = const [];

  int get confirmedCount => board.where((s) => s.person.isConfirmed).length;
  int get judgedCount => confirmedCount;
  int get currentBonus => bonusDeck[bonusIndex];
  bool get isFinished => _finished;
  bool get isCpuGame => settings.mode == GameMode.cpu;
  bool get isCpuTurn =>
      isCpuGame && currentPlayer == settings.cpuFaction && !isFinished;
  bool get humanInputEnabled =>
      (!isCpuTurn || cpuActing) &&
      !awaitingConfirmationReveal &&
      !awaitingBonusReveal &&
      !awaitingHandoff;
  Faction get humanFaction => settings.cpuFaction.opponent;
  Faction get uiViewer => isCpuGame ? humanFaction : currentPlayer;
  ScoreResult get score => ScoreResult(
    savior: scores[Faction.savior]!,
    executor: scores[Faction.executor]!,
    slotScores: {
      for (final slot in board)
        if (slot.person.awardedBonus case final bonus?)
          slot.person.id: (faction: slot.person.scoringFaction!, points: bonus),
    },
  );

  bool specialVerdictAvailable(Faction faction) =>
      !specialVerdictUsed[faction]!;

  String specialVerdictStatus(Faction faction) {
    if (specialVerdictUsed[faction]!) return '使用済み';
    if (_legalTargets(ActionType.specialVerdict, faction).isNotEmpty) {
      return '残り1';
    }
    if (board.every((slot) => slot.person.isConfirmed)) return '対象なし';
    return '生死履歴なしのみ';
  }

  void reset() {
    _resolveRandomSettings();
    board = NineJudgesRules.createBoard(_random);
    bonusDeck = NineJudgesRules.createBonusDeck(_random);
    specialVerdictUsed = {Faction.savior: false, Faction.executor: false};
    for (final knowledge in knownAttributeSlots.values) {
      knowledge.clear();
    }
    for (final seen in eyeSeenSlots.values) {
      seen.clear();
    }
    for (final faction in Faction.values) {
      privateBonusKnowledge[faction] = bonusDeck.first;
      pendingBonusReveal[faction] = false;
      scores[faction] = 0;
    }
    currentPlayer = settings.firstPlayer;
    turn = 1;
    bonusIndex = 0;
    phase = TurnPhase.selectingAction;
    selectedAction = null;
    selectedSlot = null;
    awaitingHandoff = false;
    awaitingBonusReveal = false;
    awaitingConfirmationReveal = false;
    _finished = false;
    _saved = false;
    _saveFuture = null;
    endReason = null;
    logs.clear();
    lastCpuActionMessage = null;
    lastCpuTargetIndex = null;
    lastCpuActionType = null;
    lastCpuWasJudgment = false;
    confirmationRevealMessage = null;
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
            rank: 0,
            initialAlive: false,
            positionIndex: i,
          ),
      ],
      initialKnowledge: const {},
      scoreVisible: false,
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

  bool knowsAttribute(PersonCard person, Faction viewer) {
    if (debugMode || isFinished || person.isConfirmed) return true;
    final index = board.indexWhere((slot) => slot.person.id == person.id);
    return index >= 0 && knownAttributeSlots[viewer]!.contains(index);
  }

  bool eyeKnowsAttribute(int index, Faction viewer) =>
      eyeSeenSlots[viewer]!.contains(index);
  bool initiallyKnowsAttribute(int index, Faction viewer) => false;
  bool knowsNumber(int index, Faction viewer) => false;
  bool eyeKnowsNumber(int index, Faction viewer) => false;
  bool knowsRank(int index, Faction viewer) => false;

  int? visibleBonusFor(Faction viewer) {
    if (debugMode || isFinished || bonusIndex == 0) return currentBonus;
    return privateBonusKnowledge[viewer] == currentBonus ? currentBonus : null;
  }

  String roleLabel(Faction faction) {
    if (!isCpuGame) return faction.label;
    return faction == humanFaction
        ? 'あなた（${faction.label}）'
        : 'CPU（${faction.label}）';
  }

  String actorLabel(Faction faction) {
    if (!isCpuGame) return faction.label;
    return faction == humanFaction ? 'あなた' : 'CPU';
  }

  String positionLabel(int index) {
    const rows = ['上', '中央', '下'];
    const columns = ['左', '中央', '右'];
    return '${rows[index ~/ 3]}${columns[index % 3]}';
  }

  String bonusVisibilityLabel(Faction viewer) {
    if (bonusIndex == 0) return '最初のボーナス・両者に公開';
    if (privateBonusKnowledge[viewer] == currentBonus) {
      return isCpuGame ? 'あなたのみ確認' : '${viewer.label}のみ確認';
    }
    if (privateBonusKnowledge[viewer.opponent] == currentBonus) {
      final owner = isCpuGame
          ? (viewer.opponent == settings.cpuFaction ? 'CPU' : 'あなた')
          : viewer.opponent.label;
      return '$ownerのみ確認済み';
    }
    if (pendingBonusReveal[viewer]!) {
      return isCpuGame ? 'あなたは手番終了後に確認できます' : '${viewer.label}は手番終了後に確認';
    }
    if (pendingBonusReveal[viewer.opponent]!) {
      final owner = isCpuGame
          ? (viewer.opponent == settings.cpuFaction ? 'CPU' : 'あなた')
          : viewer.opponent.label;
      return '$ownerは次の手番終了後に確認';
    }
    return 'まだ確認できません';
  }

  String publicLogText(GameLogEntry log, Faction viewer) {
    final actor = actorLabel(log.player);
    final target = positionLabel(log.targetIndex);
    if (log.action == ActionType.eye) {
      final ownResult = log.player == viewer
          ? '（${board[log.targetIndex].person.attribute.label}を確認）'
          : '';
      return '$actor：$targetをEYE $ownResult';
    }
    if (log.confirmedState != null) {
      return '$actor：$targetに${log.action.label}\n'
          '→ ${log.confirmedAttribute!.label} / '
          '${log.confirmedState!.label} / '
          '${log.scoringFaction!.label} +${log.verdictBonus}';
    }
    return '$actor：$targetに${log.action.label} → ${log.message.split('→').last.trim()}';
  }

  String? lastPublicAction(Faction viewer) =>
      logs.isEmpty ? null : publicLogText(logs.last, viewer);

  bool canSelectAction(ActionType action) =>
      humanInputEnabled &&
      phase == TurnPhase.selectingAction &&
      _legalTargets(action, currentPlayer).isNotEmpty;

  List<int> _legalTargets(ActionType action, Faction viewer) => [
    for (var i = 0; i < board.length; i++)
      if (NineJudgesRules.canUseAction(
        action: action,
        person: board[i].person,
        actor: viewer,
        actorKnowsAttribute: knowsAttribute(board[i].person, viewer),
        specialVerdictUsed: specialVerdictUsed[viewer]!,
      ))
        i,
  ];

  bool hasLegalAction(Faction faction) => ActionType.values.any(
    (action) => _legalTargets(action, faction).isNotEmpty,
  );

  void chooseAction(ActionType action) {
    if (phase == TurnPhase.selectingActionTarget && selectedAction != action) {
      cancelActionSelection(notify: false);
    }
    if (!canSelectAction(action)) return;
    selectedAction = action;
    selectedSlot = null;
    phase = TurnPhase.selectingActionTarget;
    notifyListeners();
  }

  bool canSwitchAction(ActionType action) =>
      humanInputEnabled &&
      phase == TurnPhase.selectingActionTarget &&
      selectedAction != action &&
      _legalTargets(action, currentPlayer).isNotEmpty;

  void cancelActionSelection({bool notify = true}) {
    selectedAction = null;
    selectedSlot = null;
    phase = TurnPhase.selectingAction;
    if (notify) notifyListeners();
  }

  bool canTarget(int index) =>
      humanInputEnabled &&
      selectedAction != null &&
      _legalTargets(selectedAction!, currentPlayer).contains(index);

  void selectSlot(int index) {
    if (!canTarget(index)) return;
    selectedSlot = index;
    _applyAction(index);
  }

  void _applyAction(int index) {
    final action = selectedAction!;
    final actor = currentPlayer;
    final actorKnewAttributeBefore = knowsAttribute(board[index].person, actor);
    final actorHadPendingReveal = pendingBonusReveal[actor]!;
    final before = board[index].person;
    var after = before;
    if (action == ActionType.eye) {
      knownAttributeSlots[actor]!.add(index);
      eyeSeenSlots[actor]!.add(index);
    } else if (action == ActionType.specialVerdict) {
      specialVerdictUsed[actor] = true;
      after = NineJudgesRules.applySpecialVerdict(person: before, actor: actor);
    } else {
      after = NineJudgesRules.applyVerdictAction(
        person: before,
        action: action,
        actor: actor,
      );
    }
    if (!before.isConfirmed && after.isConfirmed) {
      final scorer = NineJudgesRules.scoringFaction(after);
      final bonus = currentBonus;
      scores[scorer] = scores[scorer]! + bonus;
      after = after.copyWith(scoringFaction: scorer, awardedBonus: bonus);
      confirmationRevealMessage =
          '${after.attribute.label}\n${after.verdictState.label}\n'
          '審判ボーナス $bonus POINT\n${scorer.label} +$bonus';
      awaitingConfirmationReveal = true;
      knownAttributeSlots[Faction.savior]!.add(index);
      knownAttributeSlots[Faction.executor]!.add(index);
      if (bonusIndex < bonusDeck.length - 1) {
        bonusIndex++;
        final nonConfirmer = actor.opponent;
        privateBonusKnowledge[Faction.savior] = null;
        privateBonusKnowledge[Faction.executor] = null;
        pendingBonusReveal[actor] = false;
        pendingBonusReveal[nonConfirmer] = true;
      }
    }
    board[index] = board[index].copyWith(person: after);
    final detail = _actionDetail(action, before, after);
    logs.add(
      GameLogEntry(
        turn: turn,
        player: actor,
        message: detail,
        action: action,
        targetIndex: index,
        confirmedAttribute: after.isConfirmed ? after.attribute : null,
        confirmedState: after.isConfirmed ? after.verdictState : null,
        verdictBonus: after.awardedBonus,
        scoringFaction: after.scoringFaction,
      ),
    );
    _recordAction(
      action,
      index,
      actor,
      before,
      after,
      actorKnewAttributeBefore: actorKnewAttributeBefore,
    );
    _finishAction(
      detail,
      action: action,
      targetIndex: index,
      revealPendingBonus: actorHadPendingReveal && !after.isConfirmed,
    );
  }

  String _actionDetail(ActionType action, PersonCard before, PersonCard after) {
    if (action == ActionType.eye) return 'EYEで人物の属性を調査';
    if (after.isConfirmed) {
      final reason =
          after.verdictHistory.length == 3 &&
              action != ActionType.specialVerdict
          ? '3回目の判定により'
          : '審判確定';
      return '$reason ${action.label} → ${after.verdictState.label} / '
          '${after.attribute.label} / ${after.scoringFaction!.label} +${after.awardedBonus}';
    }
    return '${action.label}を与えました / 状態：'
        '${before.verdictState.label} → ${after.verdictState.label}';
  }

  void _recordAction(
    ActionType action,
    int index,
    Faction actor,
    PersonCard before,
    PersonCard after, {
    required bool actorKnewAttributeBefore,
  }) {
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
          targetRank: 0,
          visibleTargetAttributeAtTime: actorKnewAttributeBefore
              ? before.attribute.name
              : null,
          actualTargetAttribute: before.attribute.name,
          stateBefore: before.verdictState.name,
          stateAfter: after.verdictState.name,
          lifeShieldBefore: false,
          lifeShieldAfter: false,
          judgedBefore: before.isConfirmed,
          judgedAfter: after.isConfirmed,
          eyeResult: action == ActionType.eye ? before.attribute.name : null,
          actorHandBefore: {
            'specialVerdict': specialVerdictUsed[actor]! ? 0 : 1,
          },
          actorHandAfter: {
            'specialVerdict': specialVerdictUsed[actor]! ? 0 : 1,
          },
          opponentHandBefore: {
            'specialVerdict': specialVerdictUsed[actor.opponent]! ? 0 : 1,
          },
          opponentHandAfter: {
            'specialVerdict': specialVerdictUsed[actor.opponent]! ? 0 : 1,
          },
          timestamp: DateTime.now(),
          underReviewBefore: !before.isConfirmed,
          underReviewAfter: !after.isConfirmed,
          remainingActionsBefore: -1,
          remainingActionsAfter: -1,
          knowledgeSource: action == ActionType.eye ? 'eye' : 'public',
          scoreVisible: false,
          judgeWasAvailable: action == ActionType.specialVerdict,
          judgeAvailableFromTurn: 0,
          verdictActionCountBefore: before.verdictActionCount,
          verdictActionCountAfter: after.verdictActionCount,
          confirmedBy: after.confirmedBy?.name,
          scoringFaction: after.scoringFaction?.name,
          verdictBonus: after.awardedBonus,
          nextBonusViewer: after.isConfirmed ? actor.opponent.name : null,
          verdictHistoryBefore: [
            for (final item in before.verdictHistory) item.name,
          ],
          verdictHistoryAfter: [
            for (final item in after.verdictHistory) item.name,
          ],
          bonusViewerState: bonusVisibilityLabel(actor),
          cpuDecisionReason: action == ActionType.eye
              ? 'unknown attribute'
              : 'state and bonus evaluation',
        ),
      ],
    );
  }

  void _finishAction(
    String publicMessage, {
    required ActionType action,
    required int targetIndex,
    required bool revealPendingBonus,
  }) {
    final actor = currentPlayer;
    if (isCpuTurn) {
      lastCpuActionMessage = action == ActionType.eye
          ? 'EYEを使用し、対象の情報を確認しました'
          : publicMessage;
      lastCpuTargetIndex = targetIndex;
      lastCpuActionType = action;
      lastCpuWasJudgment = board[targetIndex].person.isConfirmed;
    }
    selectedAction = null;
    selectedSlot = null;
    phase = TurnPhase.selectingAction;
    if (confirmedCount == board.length) {
      _completeGame();
      notifyListeners();
      return;
    }
    if (revealPendingBonus) {
      privateBonusKnowledge[actor] = currentBonus;
      pendingBonusReveal[actor] = false;
      awaitingBonusReveal = !isCpuGame;
    }
    currentPlayer = actor.opponent;
    turn++;
    awaitingHandoff = !isCpuGame;
    notifyListeners();
  }

  void confirmBonusReveal() {
    awaitingBonusReveal = false;
    awaitingHandoff = true;
    notifyListeners();
  }

  void confirmConfirmationReveal() {
    awaitingConfirmationReveal = false;
    confirmationRevealMessage = null;
    notifyListeners();
  }

  void confirmHandoff() {
    awaitingHandoff = false;
    notifyListeners();
  }

  void clearCpuFeedback() {
    lastCpuActionMessage = null;
    lastCpuTargetIndex = null;
    lastCpuActionType = null;
    lastCpuWasJudgment = false;
    notifyListeners();
  }

  void _completeGame() {
    _finished = true;
    endReason = 'allConfirmed';
    session = session.copyWith(
      finishedAt: DateTime.now(),
      winner: score.winner?.name ?? 'draw',
      saviorScore: score.savior,
      executorScore: score.executor,
      totalTurns: turn,
      endReason: endReason,
      actionsUsed: const {},
      actionsRemaining: {
        for (final faction in Faction.values)
          faction.name: specialVerdictUsed[faction]! ? 0 : 1,
      },
      finalBoard: [
        for (var i = 0; i < board.length; i++)
          LoggedPerson(
            personId: board[i].person.id,
            attribute: board[i].person.attribute.name,
            rank: 0,
            initialAlive: false,
            positionIndex: i,
            finalAlive: board[i].person.isAlive,
            judged: true,
            judgedBy: board[i].person.confirmedBy?.name,
            scoringFaction: board[i].person.scoringFaction?.name,
            scoreValue: board[i].person.awardedBonus ?? 0,
            eyeSeenBySavior: eyeSeenSlots[Faction.savior]!.contains(i),
            eyeSeenByExecutor: eyeSeenSlots[Faction.executor]!.contains(i),
            verdictState: board[i].person.verdictState.name,
            verdictActionCount: board[i].person.verdictActionCount,
            awardedBonus: board[i].person.awardedBonus,
            verdictHistory: [
              for (final item in board[i].person.verdictHistory) item.name,
            ],
          ),
      ],
    );
    if (!_saved) {
      _saved = true;
      _saveFuture = logRepository.saveGame(session);
      unawaited(_saveFuture);
    }
  }

  Future<void> ensureLogSaved() async => _saveFuture;

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

  CpuGameView cpuView() {
    final faction = settings.cpuFaction;
    return CpuGameView(
      faction: faction,
      slots: [
        for (var i = 0; i < board.length; i++)
          CpuSlotView(
            index: i,
            person: board[i].person,
            knownAttribute: knowsAttribute(board[i].person, faction)
                ? board[i].person.attribute
                : null,
          ),
      ],
      legalTargets: {
        for (final action in ActionType.values)
          if (_legalTargets(action, faction).isNotEmpty)
            action: _legalTargets(action, faction),
      },
      currentBonus: visibleBonusFor(faction),
      specialVerdictAvailable: specialVerdictAvailable(faction),
    );
  }

  CpuDecision? performCpuAction() {
    if (!isCpuTurn || phase != TurnPhase.selectingAction) return null;
    final strategy = CpuPlayer.strategyFor(settings.cpuLevel, _random);
    final view = cpuView();
    lastCpuEvaluations = strategy.evaluateActions(view)
      ..sort((a, b) => b.score.compareTo(a.score));
    final decision = strategy.decideAction(view);
    cpuActing = true;
    chooseAction(decision.action);
    selectSlot(decision.targetIndex);
    cpuActing = false;
    notifyListeners();
    return decision;
  }
}
