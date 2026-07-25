import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_player.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/foundation.dart';

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
  final Map<Faction, Set<int>> knownAttributeSlots = {
    Faction.savior: <int>{},
    Faction.executor: <int>{},
  };
  final List<GameLogEntry> logs = [];

  late Faction currentPlayer;
  TurnPhase phase = TurnPhase.selectingAction;
  ActionType? selectedAction;
  int? selectedSlot;
  int turn = 1;
  bool awaitingHandoff = false;
  bool debugMode = false;
  bool cpuActing = false;
  String? lastCpuActionMessage;
  List<CpuCandidateScore> lastCpuEvaluations = const [];

  int get judgedCount => board.where((s) => s.person.isJudged).length;
  bool get isFinished => judgedCount == board.length;
  ScoreResult get score => NineJudgesRules.calculateScore(board);
  ActionInventory get currentInventory => inventories[currentPlayer]!;
  bool get isCpuGame => settings.mode == GameMode.cpu;
  bool get isCpuTurn =>
      isCpuGame && currentPlayer == settings.cpuFaction && !isFinished;
  bool get humanInputEnabled => !isCpuTurn || cpuActing;
  Faction get humanFaction => settings.cpuFaction.opponent;

  void reset() {
    _resolveRandomSettings();
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
    for (final known in knownAttributeSlots.values) {
      known.clear();
    }
    logs.clear();
    currentPlayer = settings.firstPlayer;
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

  void _resolveRandomSettings() {
    if (settings.mode != GameMode.cpu) return;
    final humanFaction = switch (settings.factionSelection) {
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
      cpuFaction: humanFaction.opponent,
      firstPlayer: humanStarts ? humanFaction : humanFaction.opponent,
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
      debugMode || isFinished || knownNumberSlots[viewer]!.contains(index);

  bool knowsAttribute(PersonCard person, Faction viewer) {
    if (debugMode || isFinished || !person.hidesAttributeWhenDead) return true;
    final index = board.indexWhere(
      (slot) => identical(slot.person, person) || slot.person.id == person.id,
    );
    return index >= 0 && knownAttributeSlots[viewer]!.contains(index);
  }

  bool eyeKnowsAttribute(int index, Faction viewer) =>
      knownAttributeSlots[viewer]!.contains(index);
  bool eyeKnowsNumber(int index, Faction viewer) =>
      knownNumberSlots[viewer]!.contains(index) &&
      !(viewer == Faction.savior
              ? NineJudgesConfig.saviorKnownNumberSlots
              : NineJudgesConfig.executorKnownNumberSlots)
          .contains(index);

  List<EyeInformation> availableEyeInformation(int index, Faction viewer) {
    final person = board[index].person;
    if (person.isJudged) return const [];
    return [
      if (person.hidesAttributeWhenDead && !knowsAttribute(person, viewer))
        EyeInformation.attribute,
      if (!knowsNumber(index, viewer)) EyeInformation.number,
    ];
  }

  bool canSelectAction(ActionType action) =>
      humanInputEnabled &&
      phase == TurnPhase.selectingAction &&
      (action == ActionType.judge || currentInventory.remaining(action) > 0) &&
      List.generate(board.length, (i) => i).any((i) => _canUse(action, i));

  bool _canUse(ActionType action, int index) => NineJudgesRules.canUseAction(
    action: action,
    person: board[index].person,
    viewerKnowsNumber: knowsNumber(index, currentPlayer),
    viewerKnowsAttribute: knowsAttribute(board[index].person, currentPlayer),
  );

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
      _canUse(selectedAction!, index);

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
        !availableEyeInformation(index, currentPlayer).contains(information)) {
      return;
    }
    if (information == EyeInformation.number) {
      knownNumberSlots[currentPlayer]!.add(index);
    } else {
      knownAttributeSlots[currentPlayer]!.add(index);
    }
    inventories[currentPlayer] = currentInventory.consume(ActionType.eye);
    logs.add(
      GameLogEntry(turn: turn, player: currentPlayer, message: 'EYEを使用'),
    );
    _finishAction('${currentPlayer.label}がEYEを使用しました');
  }

  void cancelEyeInformation() {
    if (phase != TurnPhase.selectingEyeInformation) return;
    selectedSlot = null;
    phase = TurnPhase.selectingActionTarget;
    notifyListeners();
  }

  void _applyAction(int index) {
    final action = selectedAction!;
    final slot = board[index];
    var person = slot.person;
    var detail = '';
    switch (action) {
      case ActionType.life:
        person = person.isAlive
            ? person.copyWith(hasLifeShield: true)
            : person.copyWith(isAlive: true);
        detail = '${person.id}が${person.isAlive ? '生' : '死'}になりました';
      case ActionType.death:
        person = !person.isAlive
            ? person.copyWith(isJudged: true)
            : person.hasLifeShield
            ? person.copyWith(hasLifeShield: false)
            : person.copyWith(isAlive: false);
        detail = !slot.person.isAlive
            ? '${person.id}を死で判決'
            : '${person.id}へDEATH';
      case ActionType.judge:
        person = person.copyWith(isJudged: true);
        detail = '${person.id}を${person.isAlive ? '生' : '死'}で判決';
      case ActionType.eye:
        return;
    }
    board[index] = slot.copyWith(person: person);
    if (action != ActionType.judge) {
      inventories[currentPlayer] = currentInventory.consume(action);
    }
    logs.add(GameLogEntry(turn: turn, player: currentPlayer, message: detail));
    _finishAction('${currentPlayer.label}が${action.label}を使用\n$detail');
  }

  void _finishAction(String publicMessage) {
    lastCpuActionMessage = isCpuTurn ? publicMessage : null;
    selectedAction = null;
    selectedSlot = null;
    if (!isFinished) {
      currentPlayer = currentPlayer.opponent;
      turn++;
      phase = TurnPhase.selectingAction;
      awaitingHandoff = !isCpuGame;
    }
    notifyListeners();
  }

  void confirmHandoff() {
    awaitingHandoff = false;
    notifyListeners();
  }

  CpuGameView cpuView() {
    final faction = settings.cpuFaction;
    final known = knownNumberSlots[faction]!;
    final knownNumbers = {for (final i in known) board[i].hiddenNumber};
    final legal = <ActionType, List<int>>{};
    for (final action in ActionType.values) {
      if (action != ActionType.judge &&
          inventories[faction]!.remaining(action) <= 0) {
        continue;
      }
      final targets = [
        for (var i = 0; i < board.length; i++)
          if (_cpuCanUse(action, i, faction)) i,
      ];
      if (targets.isNotEmpty) legal[action] = targets;
    }
    return CpuGameView(
      faction: faction,
      slots: [
        for (var i = 0; i < board.length; i++)
          CpuSlotView(
            index: i,
            person: PersonCard(
              id: board[i].person.id,
              attribute: knowsAttribute(board[i].person, faction)
                  ? board[i].person.attribute
                  : PersonAttribute.neutral,
              rank: board[i].person.rank,
              isAlive: board[i].person.isAlive,
              isJudged: board[i].person.isJudged,
              hasLifeShield: board[i].person.hasLifeShield,
            ),
            knownNumber: known.contains(i) ? board[i].hiddenNumber : null,
            knownAttribute: knowsAttribute(board[i].person, faction)
                ? board[i].person.attribute
                : null,
            eyeOptions: availableEyeInformation(i, faction),
          ),
      ],
      inventory: inventories[faction]!,
      unknownNumberCandidates: {
        for (var n = 1; n <= 9; n++)
          if (!knownNumbers.contains(n)) n,
      },
      legalTargets: legal,
    );
  }

  bool _cpuCanUse(ActionType action, int i, Faction faction) =>
      NineJudgesRules.canUseAction(
        action: action,
        person: board[i].person,
        viewerKnowsNumber: knowsNumber(i, faction),
        viewerKnowsAttribute: knowsAttribute(board[i].person, faction),
      );

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
    if (decision.action == ActionType.eye) {
      revealEyeInformation(
        decision.eyeInformation ??
            availableEyeInformation(
              decision.targetIndex,
              settings.cpuFaction,
            ).first,
      );
    }
    cpuActing = false;
    notifyListeners();
    return decision;
  }
}
