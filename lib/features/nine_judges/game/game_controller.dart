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
  final Map<Faction, Set<String>> judgedKnowledge = {
    Faction.savior: <String>{},
    Faction.executor: <String>{},
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
    judgedKnowledge
      ..[Faction.savior]!.clear()
      ..[Faction.executor]!.clear();
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
    final known = viewer == Faction.savior
        ? NineJudgesConfig.saviorKnownNumberSlots
        : NineJudgesConfig.executorKnownNumberSlots;
    return known.contains(slotIndex);
  }

  bool knowsAttribute(PersonCard person, Faction viewer) =>
      NineJudgesRules.isAttributeVisible(
        person,
        viewerHasJudged: judgedKnowledge[viewer]!.contains(person.id),
        revealAll: debugMode || isFinished,
      );

  bool canSelectAction(ActionType action) =>
      phase == TurnPhase.selectingAction &&
      currentInventory.remaining(action) > 0 &&
      board.any(
        (slot) => NineJudgesRules.canUseAction(
          action: action,
          person: slot.person,
          viewerHasJudged: judgedKnowledge[currentPlayer]!.contains(
            slot.person.id,
          ),
        ),
      );

  void chooseAction(ActionType action) {
    if (!canSelectAction(action)) return;
    selectedAction = action;
    selectedSlot = null;
    phase = TurnPhase.selectingTarget;
    notifyListeners();
  }

  bool canTarget(int index) {
    if (phase == TurnPhase.selectingSave) {
      return !board[index].person.isJudged;
    }
    final action = selectedAction;
    return phase == TurnPhase.selectingTarget &&
        action != null &&
        NineJudgesRules.canUseAction(
          action: action,
          person: board[index].person,
          viewerHasJudged: judgedKnowledge[currentPlayer]!.contains(
            board[index].person.id,
          ),
        );
  }

  void selectSlot(int index) {
    selectedSlot = index;
    if (!canTarget(index)) {
      notifyListeners();
      return;
    }
    if (phase == TurnPhase.selectingSave) {
      _save(index);
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
        person = person.copyWith(isAlive: true);
        detail = 'LIFE → ${_publicName(person)}（死→生）';
        break;
      case ActionType.death:
        person = person.copyWith(isAlive: false);
        detail = 'DEATH → ${_publicName(person)}（生→死）';
        break;
      case ActionType.judge:
        judgedKnowledge[currentPlayer]!.add(person.id);
        detail = 'JUDGE → UNKNOWN${person.rank}　結果：${person.attribute.label}';
        break;
    }
    board[index] = slot.copyWith(person: person);
    inventories[currentPlayer] = currentInventory.consume(action);
    logs.add(GameLogEntry(turn: turn, player: currentPlayer, message: detail));
    selectedAction = null;
    phase = TurnPhase.awaitingSave;
    notifyListeners();
  }

  void beginSave() {
    if (phase != TurnPhase.awaitingSave && phase != TurnPhase.selectingAction) {
      return;
    }
    selectedSlot = null;
    phase = TurnPhase.selectingSave;
    notifyListeners();
  }

  void _save(int index) {
    final slot = board[index];
    if (slot.person.isJudged) return;
    board[index] = slot.copyWith(person: slot.person.copyWith(isJudged: true));
    logs.add(
      GameLogEntry(
        turn: turn,
        player: currentPlayer,
        message: 'SAVE → ${_publicName(slot.person)}',
      ),
    );
    if (isFinished) {
      phase = TurnPhase.selectingAction;
      notifyListeners();
      return;
    }
    _completeTurn();
  }

  void endTurnWithoutSave() {
    if (NineJudgesConfig.forceSaveEachTurn || phase != TurnPhase.awaitingSave) {
      return;
    }
    logs.add(
      GameLogEntry(turn: turn, player: currentPlayer, message: 'SAVEなしでターン終了'),
    );
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
