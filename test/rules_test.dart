import 'package:dead_or_alive/features/game/application/game_rule_service.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_constants.dart';
import 'package:dead_or_alive/features/game/domain/life_death_card.dart';
import 'package:dead_or_alive/features/game/domain/person_card.dart';
import 'package:flutter_test/flutter_test.dart';

PersonCard person({
  PersonType type = PersonType.good,
  int number = 5,
  PersonStatus status = PersonStatus.alive,
  bool sealed = false,
}) =>
    PersonCard(
      id: 'p',
      position: 0,
      type: type,
      number: number,
      status: status,
      sealed: sealed,
    );

LifeDeathCard card(LifeDeathEffect e, int n) =>
    LifeDeathCard(id: 'c', effect: e, number: n, owner: TurnOwner.player);

void main() {
  const rules = GameRuleService();

  group('パワー判定', () {
    test('数字以上で成功、未満で失敗', () {
      expect(rules.judgePower(5, 5), isTrue);
      expect(rules.judgePower(4, 5), isFalse);
    });
  });

  group('効果適用', () {
    test('デッド成功で死亡', () {
      final r = rules.applyEffect(person(number: 5), card(LifeDeathEffect.dead, 6));
      expect(r.success, isTrue);
      expect(r.changed, isTrue);
      expect(r.updatedCard.status, PersonStatus.dead);
    });
    test('デッド失敗で不変', () {
      final r = rules.applyEffect(person(number: 8), card(LifeDeathEffect.dead, 2));
      expect(r.success, isFalse);
      expect(r.updatedCard.status, PersonStatus.alive);
    });
    test('アライブ成功で復活', () {
      final r = rules.applyEffect(
          person(number: 4, status: PersonStatus.dead), card(LifeDeathEffect.alive, 9));
      expect(r.updatedCard.status, PersonStatus.alive);
      expect(r.changed, isTrue);
    });
    test('同状態なら成功でも変化なし', () {
      final r = rules.applyEffect(person(number: 3), card(LifeDeathEffect.alive, 9));
      expect(r.success, isTrue);
      expect(r.changed, isFalse);
    });
    test('シール成功で封印', () {
      final r = rules.applyEffect(person(number: 3), card(LifeDeathEffect.seal, 5));
      expect(r.success, isTrue);
      expect(r.updatedCard.sealed, isTrue);
    });
  });

  group('封印の恒久固定', () {
    test('封印済みはパワー成功でも状態変更不可', () {
      final sealed = person(number: 3, sealed: true, status: PersonStatus.alive);
      final r = rules.applyEffect(sealed, card(LifeDeathEffect.dead, 9));
      expect(r.success, isTrue);
      expect(r.changed, isFalse);
      expect(r.wasSealed, isTrue);
      expect(r.updatedCard.status, PersonStatus.alive);
    });
  });

  group('得点集計', () {
    List<PersonCard> board(List<(PersonType, PersonStatus)> spec) {
      final list = <PersonCard>[];
      for (var i = 0; i < spec.length; i++) {
        list.add(PersonCard(
          id: 'p$i',
          position: i,
          type: spec[i].$1,
          number: i + 1,
          status: spec[i].$2,
        ));
      }
      return list;
    }

    test('救済者：生存善人2点・死亡悪人/中立1点', () {
      final b = board([
        (PersonType.good, PersonStatus.alive), // savior +2
        (PersonType.good, PersonStatus.alive), // savior +2
        (PersonType.evil, PersonStatus.dead), // savior +1
        (PersonType.neutral, PersonStatus.dead), // savior +1
      ]);
      final r = rules.score(b, Role.savior);
      // savior = 2+2+1+1 = 6, executioner = 0
      expect(r.saviorScore, 6);
      expect(r.executionerScore, 0);
      expect(r.winnerRole, Role.savior);
      expect(r.playerScore, 6);
    });

    test('全員生存の開始時は 6-6 の引き分け', () {
      final b = board([
        (PersonType.good, PersonStatus.alive),
        (PersonType.good, PersonStatus.alive),
        (PersonType.good, PersonStatus.alive),
        (PersonType.evil, PersonStatus.alive),
        (PersonType.evil, PersonStatus.alive),
        (PersonType.evil, PersonStatus.alive),
        (PersonType.neutral, PersonStatus.alive),
        (PersonType.neutral, PersonStatus.alive),
        (PersonType.neutral, PersonStatus.alive),
      ]);
      final r = rules.score(b, Role.savior);
      expect(r.saviorScore, GameConstants.scoreGood * 3); // 6
      expect(r.executionerScore, 3 + 3); // alive evil+neutral
      expect(r.isDraw, isTrue);
      expect(r.winnerRole, isNull);
    });

    test('執行者：死亡善人2点で勝利', () {
      final b = board([
        (PersonType.good, PersonStatus.dead), // exec +2
        (PersonType.good, PersonStatus.dead), // exec +2
        (PersonType.good, PersonStatus.alive), // savior +2
      ]);
      final r = rules.score(b, Role.executioner);
      expect(r.executionerScore, 4);
      expect(r.saviorScore, 2);
      expect(r.winnerRole, Role.executioner);
      expect(r.playerWon, isTrue); // プレイヤーは執行者
    });
  });
}
