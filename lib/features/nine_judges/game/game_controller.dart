import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_player.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class NineJudgesController extends ChangeNotifier {
  NineJudgesController({
    Random? random,
    this.settings = const NineJudgesGameSettings(),
  }) : _random = random ?? Random() {
    reset();
  }

  final Random _random;
  NineJudgesGameSettings settings;
  late List<BoardSlot> board;
  late Map<Faction, ActionInventory> inventories;
  final Map<Faction, Set<int>> knownNumberSlots = {
    Faction.savior: <int>{},
    Faction.executor: <int>{},
  };
  final List<GameLogEntry> logs = [];

  Faction currentPlayer = Faction.savior;
  TurnPhase phase = TurnPhase.selectingAction;
  ActionType? selectedAction;
  int? selectedSlot;
  int turn = 1;
  bool awaitingHandoff = false;
  bool debugMode = false;
  bool cpuActing = false;
  String? lastCpuActionMessage;
  List<CpuCandidateScore> lastCpuEvaluations = const [];

  int get judgedCount => board.where((slot) => slot.person.isJudged).length;
  bool get isFinished => judgedCount == 9;
  ScoreResult get score => NineJudgesRules.calculateScore(board);
  ActionInventory get currentInventory => inventories[currentPlayer]!;
  bool get isCpuGame => settings.mode == GameMode.cpu;
  bool get isCpuTurn =>
      isCpuGame && currentPlayer == settings.cpuFaction && !isFinished;
  bool get humanInputEnabled => !isCpuTurn || cpuActing;

  void reset() {
    board = NineJudgesRules.createBoard(_random);
    inventories = {
      Faction.savior: NineJudgesConfig.initialInventory,
      Faction.executor: NineJudgesConfig.initialInventory,
    };
    knownNumberSlots[Faction.savior]!
      ..clear()
      ..addAll(NineJudgesConfig.saviorKnownNumberSlots);
    knownNumberSlots[Faction.executor]!
      ..clear()
      ..addAll(NineJudgesConfig.executorKnownNumberSlots);
    logs.clear();
    currentPlayer = Faction.savior;
    phase = TurnPhase.selectingAction;
    selectedAction = null;
    selectedSlot = null;
    turn = 1;
    awaitingHandoff = false;
    cpuActing = false;
    lastCpuActionMessage = null;
    lastCpuEvaluations = const [];
    notifyListeners();
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

  bool knowsNumber(int slotIndex, Faction viewer) {
    if (debugMode || isFinished) return true;
    return knownNumberSlots[viewer]!.contains(slotIndex);
  }

  bool knowsAttribute(PersonCard person, Faction viewer) =>
      NineJudgesRules.isAttributeVisible(
        person,
        revealAll: debugMode || isFinished,
      );

  bool canSelectAction(ActionType action) =>
      humanInputEnabled &&
      phase == TurnPhase.selectingAction &&
      currentInventory.remaining(action) > 0 &&
      board.asMap().entries.any(
        (entry) => NineJudgesRules.canUseAction(
          action: action,
          person: entry.value.person,
          viewerKnowsNumber: knowsNumber(entry.key, currentPlayer),
        ),
      );

  void chooseAction(ActionType action) {
    if (!canSelectAction(action)) return;
    selectedAction = action;
    selectedSlot = null;
    phase = TurnPhase.selectingActionTarget;
    notifyListeners();
  }

  bool canTarget(int index) {
    if (!humanInputEnabled) return false;
    if (phase == TurnPhase.selectingJudgeTarget) {
      return !board[index].person.isJudged;
    }
    final action = selectedAction;
    return phase == TurnPhase.selectingActionTarget &&
        action != null &&
        NineJudgesRules.canUseAction(
          action: action,
          person: board[index].person,
          viewerKnowsNumber: knowsNumber(index, currentPlayer),
        );
  }

  void selectSlot(int index) {
    selectedSlot = index;
    if (!canTarget(index)) {
      notifyListeners();
      return;
    }
    if (phase == TurnPhase.selectingJudgeTarget) {
      _judge(index);
    } else {
      _applyAction(index);
    }
  }

  void _applyAction(int index) {
    final action = selectedAction!;
    final slot = board[index];
    var person = slot.person;
    String detail;
    switch (action) {
      case ActionType.life:
        if (person.isAlive) {
          person = person.copyWith(hasLifeShield: true);
          detail = 'LIFE → ${_publicName(person)}（生存防護）';
        } else {
          person = person.copyWith(isAlive: true);
          detail = 'LIFE → ${_publicName(person)}（死→生）';
        }
        break;
      case ActionType.death:
        if (!person.isAlive) {
          person = person.copyWith(isJudged: true);
          detail = 'DEATH → ${_publicName(person)}（死を即時確定）';
        } else if (person.hasLifeShield) {
          person = person.copyWith(hasLifeShield: false);
          detail = 'DEATH → ${_publicName(person)}（LIFE防護を除去）';
        } else {
          person = person.copyWith(isAlive: false);
          detail = 'DEATH → ${_publicName(person)}（生→死）';
        }
        break;
      case ActionType.eye:
        knownNumberSlots[currentPlayer]!.add(index);
        detail = 'EYE → slot ${index + 1}（数字${slot.hiddenNumber}を確認）';
        break;
    }
    board[index] = slot.copyWith(person: person);
    inventories[currentPlayer] = currentInventory.consume(action);
    logs.add(GameLogEntry(turn: turn, player: currentPlayer, message: detail));
    selectedAction = null;
    if (action == ActionType.death && person.isJudged) {
      if (!isFinished) _completeTurn();
    } else {
      phase = TurnPhase.awaitingJudge;
    }
    notifyListeners();
  }

  void beginJudge() {
    if (phase != TurnPhase.awaitingJudge) return;
    selectedSlot = null;
    phase = TurnPhase.selectingJudgeTarget;
    notifyListeners();
  }

  void _judge(int index) {
    final slot = board[index];
    if (slot.person.isJudged) return;
    board[index] = slot.copyWith(person: slot.person.copyWith(isJudged: true));
    logs.add(
      GameLogEntry(
        turn: turn,
        player: currentPlayer,
        message:
            'JUDGE → ${_publicName(slot.person)}（${slot.person.isAlive ? '生' : '死'}で判決）',
      ),
    );
    if (isFinished) {
      phase = TurnPhase.selectingAction;
      notifyListeners();
      return;
    }
    _completeTurn();
  }

  void _completeTurn() {
    selectedAction = null;
    selectedSlot = null;
    currentPlayer = currentPlayer.opponent;
    turn++;
    phase = TurnPhase.selectingAction;
    awaitingHandoff = !isCpuGame;
    notifyListeners();
  }

  void confirmHandoff() {
    awaitingHandoff = false;
    notifyListeners();
  }

  String _publicName(PersonCard person) =>
      '${person.attribute.label}${person.rank}';

  CpuGameView cpuView() {
    final faction = settings.cpuFaction;
    final known = knownNumberSlots[faction]!;
    final knownNumbers = {for (final index in known) board[index].hiddenNumber};
    final unknownCandidates = {
      for (var number = 1; number <= 9; number++)
        if (!knownNumbers.contains(number)) number,
    };
    final legalTargets = <ActionType, List<int>>{};
    for (final action in ActionType.values) {
      if (inventories[faction]!.remaining(action) <= 0) continue;
      final targets = [
        for (var index = 0; index < board.length; index++)
          if (NineJudgesRules.canUseAction(
            action: action,
            person: board[index].person,
            viewerKnowsNumber: known.contains(index),
          ))
            index,
      ];
      if (targets.isNotEmpty) legalTargets[action] = targets;
    }
    return CpuGameView(
      faction: faction,
      slots: [
        for (var index = 0; index < board.length; index++)
          CpuSlotView(
            index: index,
            person: board[index].person,
            knownNumber: known.contains(index)
                ? board[index].hiddenNumber
                : null,
          ),
      ],
      inventory: inventories[faction]!,
      unknownNumberCandidates: unknownCandidates,
      legalTargets: legalTargets,
    );
  }

  CpuDecision? performCpuAction() {
    if (!isCpuTurn || phase != TurnPhase.selectingAction) return null;
    final strategy = CpuPlayer.strategyFor(settings.cpuLevel, _random);
    final view = cpuView();
    lastCpuEvaluations = strategy.evaluateActions(view)
      ..sort((a, b) => b.score.compareTo(a.score));
    final decision = strategy.decideAction(view);
    final person = board[decision.targetIndex].person;
    cpuActing = true;
    chooseAction(decision.action);
    selectSlot(decision.targetIndex);
    cpuActing = false;
    lastCpuActionMessage = decision.action == ActionType.eye
        ? '${settings.cpuFaction.label}  EYE → 人物${person.rank}\n数字を確認しました'
        : '${settings.cpuFaction.label}  ${decision.action.label} → '
              '${_publicName(person)}\n${_publicCpuEffect(decision.action, person)}';
    notifyListeners();
    return decision;
  }

  int? performCpuJudge() {
    if (!isCpuTurn || phase != TurnPhase.awaitingJudge) return null;
    final strategy = CpuPlayer.strategyFor(settings.cpuLevel, _random);
    final target = strategy.decideJudgeTarget(cpuView());
    cpuActing = true;
    beginJudge();
    selectSlot(target);
    cpuActing = false;
    notifyListeners();
    return target;
  }

  String _publicCpuEffect(ActionType action, PersonCard before) =>
      switch (action) {
        ActionType.life when before.isAlive => 'LIFE防護を付与',
        ActionType.life => '生き返らせました',
        ActionType.death when !before.isAlive => '死を即時確定',
        ActionType.death when before.hasLifeShield => 'LIFE防護を破壊',
        ActionType.death => '死亡させました',
        ActionType.eye => '数字を確認しました',
      };
}
