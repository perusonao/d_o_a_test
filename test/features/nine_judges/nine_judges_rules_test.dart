import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
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
      expect(game.bonusVisibilityLabel(Faction.savior), contains('両者に公開'));
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
      expect(alive.verdictHistory, [VerdictActionType.life]);
      final dead = NineJudgesRules.applyVerdictAction(
        person: alive,
        action: ActionType.death,
        actor: Faction.executor,
      );
      expect(dead.verdictState, VerdictState.dead);
      expect(dead.verdictHistory, [
        VerdictActionType.life,
        VerdictActionType.death,
      ]);
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
      expect(alive.verdictHistory.last, VerdictActionType.life);
      expect(dead.verdictHistory.last, VerdictActionType.death);
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

    test('救済者DEATHと執行者LIFEは各1回だけ使用可能', () {
      final game = NineJudgesController(seed: 22);
      expect(game.canSelectAction(ActionType.death), isTrue);
      game.chooseAction(ActionType.death);
      game.selectSlot(3);
      expect(game.reverseActionUsed[Faction.savior], isTrue);
      expect(game.session.actions.last.wasReverseAction, isTrue);
      expect(game.session.actions.last.actorHandBefore['reverseDeath'], 1);
      expect(game.session.actions.last.actorHandAfter['reverseDeath'], 0);
      game.confirmHandoff();

      expect(game.canSelectAction(ActionType.life), isTrue);
      game.chooseAction(ActionType.life);
      game.selectSlot(4);
      expect(game.reverseActionUsed[Faction.executor], isTrue);
      expect(game.session.actions.last.wasReverseAction, isTrue);
      game.confirmHandoff();

      expect(game.canSelectAction(ActionType.death), isFalse);
      game.chooseAction(ActionType.life);
      game.selectSlot(5);
      game.confirmHandoff();
      expect(game.canSelectAction(ActionType.life), isFalse);
    });
  });

  group('EYEと特殊審判', () {
    test('開始時は各自の手前3枚だけ既知で中央は双方未知', () {
      final game = NineJudgesController(seed: 29);
      for (final index in [6, 7, 8]) {
        expect(
          game.knowsAttribute(game.board[index].person, Faction.savior),
          isTrue,
        );
        expect(
          game.knowsAttribute(game.board[index].person, Faction.executor),
          isFalse,
        );
      }
      for (final index in [0, 1, 2]) {
        expect(
          game.knowsAttribute(game.board[index].person, Faction.executor),
          isTrue,
        );
        expect(
          game.knowsAttribute(game.board[index].person, Faction.savior),
          isFalse,
        );
      }
      for (final index in [3, 4, 5]) {
        expect(
          game.knowsAttribute(game.board[index].person, Faction.savior),
          isFalse,
        );
        expect(
          game.knowsAttribute(game.board[index].person, Faction.executor),
          isFalse,
        );
      }
      expect(game.session.initialKnowledge, hasLength(6));
    });
    test('EYEは本人だけが知り、状態を変えず再調査不可', () {
      final game = NineJudgesController(seed: 30);
      final before = game.board[3].person;
      game.chooseAction(ActionType.eye);
      game.selectSlot(3);
      expect(game.knowsAttribute(before, Faction.savior), isTrue);
      expect(game.knowsAttribute(before, Faction.executor), isFalse);
      expect(game.eyeSeenSlots[Faction.savior], contains(3));
      expect(game.eyeSeenSlots[Faction.executor], isNot(contains(3)));
      expect(game.board[3].person.verdictState, VerdictState.deliberating);
      expect(game.session.actions.single.visibleTargetAttributeAtTime, isNull);
      expect(
        NineJudgesRules.canUseAction(
          action: ActionType.eye,
          person: game.board[3].person,
          actor: Faction.savior,
          actorKnowsAttribute: true,
          specialVerdictUsed: false,
        ),
        isFalse,
      );
    });

    test('相手のEYEだけでは属性を知らず、LIFE/DEATHでも公開されない', () {
      final game = NineJudgesController(seed: 31);
      game.chooseAction(ActionType.eye);
      game.selectSlot(3);
      expect(
        game.knowsAttribute(game.board[3].person, Faction.executor),
        isFalse,
      );
      game.confirmHandoff();
      game.chooseAction(ActionType.death);
      game.selectSlot(3);
      expect(
        game.knowsAttribute(game.board[3].person, Faction.executor),
        isFalse,
      );
      expect(game.knowsAttribute(game.board[3].person, Faction.savior), isTrue);
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

    test('JUDGE選択中に確定済み対象を理由付きで拒否、審議中はnull、JUDGE未選択時は常にnull', () {
      final game = NineJudgesController(seed: 41);
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(0); // savior confirms index 0 via JUDGE
      if (game.awaitingConfirmationReveal) game.confirmConfirmationReveal();
      if (game.awaitingHandoff) game.confirmHandoff();

      // JUDGEが選択されていない間は常にnull(対象が確定済みでも)。
      expect(game.judgeTargetRejectionReason(0), isNull);

      // 次の手番(執行者)がJUDGEを選択すると、確定済みのindex0は拒否理由付きで、
      // 未介入のindex1はnullで返る。
      game.chooseAction(ActionType.specialVerdict);
      expect(
        game.judgeTargetRejectionReason(0),
        'JUDGEは「審議中」の対象にのみ使用できます。',
      );
      expect(game.judgeTargetRejectionReason(1), isNull);
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

    test('非確定者は次の自分の手番開始時に次ボーナスを知る', () {
      final game = NineJudgesController(seed: 50);
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(0);
      final nextBonus = game.currentBonus;
      expect(game.visibleBonusFor(Faction.executor), isNull);
      expect(game.pendingBonusReveal[Faction.executor], isTrue);
      game.confirmConfirmationReveal();
      expect(game.visibleBonusFor(Faction.executor), isNull);
      game.confirmHandoff();
      expect(game.privateBonusKnowledge[Faction.executor], nextBonus);
      expect(game.privateBonusKnowledge[Faction.savior], isNull);
      expect(game.bonusVisibilityLabel(Faction.executor), contains('のみ確認'));
      expect(game.bonusVisibilityLabel(Faction.savior), contains('執行者のみ確認済み'));
    });

    test('閲覧者は確定アクションより前にボーナスを確認済み', () {
      final game = NineJudgesController(seed: 51);
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(0);
      game.confirmConfirmationReveal();
      game.confirmHandoff();
      final revealed = game.currentBonus;
      expect(game.visibleBonusFor(Faction.executor), revealed);

      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(1);
      final action = game.session.actions.last;
      expect(action.bonusRevealTriggered, isTrue);
      expect(action.bonusViewer, Faction.executor.name);
      expect(action.revealedBonus, revealed);
      expect(action.verdictBonus, revealed);
      expect(game.bonusHistory, hasLength(2));
      expect(game.bonusHistory.map((item) => item.order), [1, 2]);
    });

    test('確定者が変わると次ボーナス閲覧者も切り替わる', () {
      final game = NineJudgesController(seed: 52);
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(0);
      game.confirmConfirmationReveal();
      game.confirmHandoff();
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(1);
      expect(game.pendingBonusReveal[Faction.savior], isTrue);
      expect(game.pendingBonusReveal[Faction.executor], isFalse);
      expect(game.session.actions.last.nextBonusViewer, Faction.savior.name);
    });

    test('ボーナス履歴と残りは使用順・重複なしで一致する', () {
      final game = NineJudgesController(seed: 53);
      final first = game.currentBonus;
      game.chooseAction(ActionType.specialVerdict);
      game.selectSlot(0);
      expect(game.bonusHistory.single.bonus, first);
      expect(game.bonusHistory.single.order, 1);
      expect(game.bonusHistory.single.scoringFaction, isNotNull);
      expect(game.remainingBonuses, isNot(contains(first)));
      expect({
        ...game.bonusHistory.map((item) => item.bonus),
        ...game.remainingBonuses,
      }, game.bonusDeck.toSet());
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
      expect(game.session.rulesVersion, NineJudgesConfig.rulesVersion);
      expect(game.session.actions.single.verdictHistoryBefore, isEmpty);
      expect(game.session.actions.single.confirmedBy, 'savior');
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
      expect(
        game.remainingBonuses,
        orderedEquals([...game.remainingBonuses]..sort()),
      );
    });
  });
}
