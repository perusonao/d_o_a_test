import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class NineJudgesController extends ChangeNotifier {
  NineJudgesController({Random? random}) : _random = random ?? Random() {
    reset();
  }

  final Random _random;
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

  int get judgedCount => board.where((slot) => slot.person.isJudged).length;
  bool get isFinished => judgedCount == 9;
  ScoreResult get score => NineJudgesRules.calculateScore(board);
  ActionInventory get currentInventory => inventories[currentPlayer]!;

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
    notifyListeners();
  }

  void reshuffle() => reset();

  void setDebugMode(bool value) {
    debugMode = value;
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
    awaitingHandoff = true;
    notifyListeners();
  }

  void confirmHandoff() {
    awaitingHandoff = false;
    notifyListeners();
  }

  String _publicName(PersonCard person) =>
      '${person.attribute.label}${person.rank}';
}
