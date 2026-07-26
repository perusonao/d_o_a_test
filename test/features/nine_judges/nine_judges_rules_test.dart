import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_rules.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('初期化', () {
    test('善人・悪人・中立が3人ずつ、全員審議中', () {
      final board = NineJudgesRules.createBoard(Random(10));
      for (final attribute in PersonAttribute.values) {
        expect(
          board.where((slot) => slot.person.attribute == attribute),
          hasLength(3),
        );
      }
      expect(
        board.every(
          (slot) =>
              slot.person.verdictState == VerdictState.deliberating &&
              slot.person.verdictActionCount == 0,
        ),
        isTrue,
      );
    });

    test('ボーナス1〜9は重複せず、初期得点0で最初は双方に公開', () {
      final game = NineJudgesController(seed: 20);
      expect(game.bonusDeck.toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9});
      expect(game.score.savior, 0);
      expect(game.score.executor, 0);
      expect(game.visibleBonusFor(Faction.savior), game.currentBonus);
      expect(game.visibleBonusFor(Faction.executor), game.currentBonus);
    });
  });

  group('LIFE / DEATH', () {
    PersonCard person(VerdictState state, int count) => PersonCard(
      id: 'p',
      attribute: PersonAttribute.good,
      verdictState: state,
      verdictActionCount: count,
    );

    test('審議中→生、生→死、死→生', () {
      final alive = NineJudgesRules.applyVerdictAction(
        person: person(VerdictState.deliberating, 0),
        action: ActionType.life,
        actor: Faction.savior,
      );
      expect(alive.verdictState, VerdictState.alive);
      final dead = NineJudgesRules.applyVerdictAction(
        person: alive,
        action: ActionType.death,
        actor: Faction.executor,
      );
      expect(dead.verdictState, VerdictState.dead);
      final aliveAgain = NineJudgesRules.applyVerdictAction(
        person: person(VerdictState.dead, 1),
        action: ActionType.life,
        actor: Faction.savior,
      );
      expect(aliveAgain.verdictState, VerdictState.alive);
    });

    test('同じ状態を2回与えると確定', () {
      final alive = NineJudgesRules.applyVerdictAction(
        person: person(VerdictState.alive, 1),
        action: ActionType.life,
        actor: Faction.savior,
      );
      final dead = NineJudgesRules.applyVerdictAction(
        person: person(VerdictState.dead, 1),
        action: ActionType.death,
        actor: Faction.executor,
      );
      expect(alive.verdictState, VerdictState.aliveConfirmed);
      expect(dead.verdictState, VerdictState.deadConfirmed);
    });

    test('3回目は現在状態で強制確定', () {
      final alive = NineJudgesRules.applyVerdictAction(
        person: person(VerdictState.dead, 2),
        action: ActionType.life,
        actor: Faction.savior,
      );
      final dead = NineJudgesRules.applyVerdictAction(
        person: person(VerdictState.alive, 2),
        action: ActionType.death,
        actor: Faction.executor,
      );
      expect(alive.verdictState, VerdictState.aliveConfirmed);
      expect(dead.verdictState, VerdictState.deadConfirmed);
    });
  });

  group('EYEと特殊審判', () {
    test('EYEは本人だけが知り、状態を変えず再調査不可', () {
      final game = NineJudgesController(seed: 30);
      final before = game.board[0].person;
      game.chooseAction(ActionType.eye);
      game.selectSlot(0);
      expect(game.knowsAttribute(before, Faction.savior), isTrue);
      expect(game.knowsAttribute(before, Faction.executor), isFalse);
      expect(game.board[0].person.verdictState, VerdictState.deliberating);
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.eye,
          person: game.board[0].person,
          actor: Faction.savior,
          actorKnowsAttribute: true,
          specialVerdictUsed: false,
        ),
        isFalse,
      );
    });

    test('特殊審判は未介入人物だけ、陣営の状態で即確定し1回のみ', () {
      final game = NineJudgesController(seed: 40);
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(0);
      expect(game.board[0].person.verdictState, VerdictState.aliveConfirmed);
      expect(game.specialVerdictAvailable(Faction.savior), isFalse);
      final touched = game.board[1].person.copyWith(
        verdictState: VerdictState.alive,
        verdictActionCount: 1,
      );
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.specialVerdict,
          person: touched,
          actor: Faction.executor,
          actorKnowsAttribute: false,
          specialVerdictUsed: false,
        ),
        isFalse,
      );
    });
  });

  group('得点とボーナス秘密情報', () {
    test('属性と確定状態ごとの得点陣営', () {
      PersonCard confirmed(PersonAttribute attribute, bool alive) => PersonCard(
        id: 'p',
        attribute: attribute,
        verdictState: alive
            ? VerdictState.aliveConfirmed
            : VerdictState.deadConfirmed,
      );
      expect(
        NineJudgesRules.scoringFaction(confirmed(PersonAttribute.good, true)),
        Faction.savior,
      );
      expect(
        NineJudgesRules.scoringFaction(confirmed(PersonAttribute.good, false)),
        Faction.executor,
      );
      expect(
        NineJudgesRules.scoringFaction(
          confirmed(PersonAttribute.neutral, true),
        ),
        Faction.savior,
      );
      expect(
        NineJudgesRules.scoringFaction(
          confirmed(PersonAttribute.neutral, false),
        ),
        Faction.executor,
      );
      expect(
        NineJudgesRules.scoringFaction(confirmed(PersonAttribute.evil, true)),
        Faction.executor,
      );
      expect(
        NineJudgesRules.scoringFaction(confirmed(PersonAttribute.evil, false)),
        Faction.savior,
      );
    });

    test('非確定者は次の自分の行動完了後に次ボーナスを知る', () {
      final game = NineJudgesController(seed: 50);
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(0);
      final nextBonus = game.currentBonus;
      expect(game.visibleBonusFor(Faction.executor), isNull);
      game.confirmConfirmationReveal();
      game.confirmHandoff();
      game.chooseAction(ActionType.eye);
      game.selectSlot(1);
      expect(game.privateBonusKnowledge[Faction.executor], nextBonus);
      expect(game.privateBonusKnowledge[Faction.savior], isNull);
      expect(game.awaitingBonusReveal, isTrue);
    });

    test('確定者と得点者を分離しログ保存する', () async {
      final repo = MemoryGameLogRepository();
      final game = NineJudgesController(seed: 60, logRepository: repo);
      final evil = game.board.indexWhere(
        (slot) => slot.person.attribute == PersonAttribute.evil,
      );
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(evil);
      final person = game.board[evil].person;
      expect(person.confirmedBy, Faction.savior);
      expect(person.scoringFaction, Faction.executor);
      expect(person.awardedBonus, isNotNull);
      expect(game.session.actions.single.actionType, 'specialVerdict');
      expect(game.session.rulesVersion, '1.0');
    });

    test('9人確定で終了し、9枚のボーナス合計45・引き分けなし', () {
      final game = NineJudgesController(seed: 61);
      var guard = 0;
      while (!game.isFinished && guard++ < 60) {
        final actor = game.currentPlayer;
        final action = actor == Faction.savior
            ? ActionType.life
            : ActionType.death;
        final desired = actor == Faction.savior
            ? VerdictState.alive
            : VerdictState.dead;
        var target = game.board.indexWhere(
          (slot) =>
              !slot.person.isConfirmed && slot.person.verdictState == desired,
        );
        target = target >= 0
            ? target
            : game.board.indexWhere(
                (slot) =>
                    !slot.person.isConfirmed &&
                    slot.person.verdictActionCount >= 2,
              );
        target = target >= 0
            ? target
            : game.board.indexWhere((slot) => !slot.person.isConfirmed);
        game.chooseAction(action);
        game.selectSlot(target);
        if (game.awaitingConfirmationReveal) {
          game.confirmConfirmationReveal();
        }
        if (game.awaitingBonusReveal) game.confirmBonusReveal();
        if (game.awaitingHandoff) game.confirmHandoff();
      }
      expect(game.isFinished, isTrue);
      expect(game.confirmedCount, 9);
      expect(game.score.savior + game.score.executor, 45);
      expect(game.score.winner, isNotNull);
      expect(
        game.board.map((slot) => slot.person.awardedBonus).toSet(),
        game.bonusDeck.toSet(),
      );
    });
  });
}
