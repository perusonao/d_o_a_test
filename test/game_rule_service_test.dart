import 'package:dead_or_alive/features/game/application/game_rule_service.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/life_death_card.dart';
import 'package:dead_or_alive/features/game/domain/person_card.dart';
import 'package:dead_or_alive/features/game/domain/player_state.dart';
import 'package:flutter_test/flutter_test.dart';

PersonCard person({
  PersonType type = PersonType.good,
  int number = 5,
  PersonStatus status = PersonStatus.alive,
  RevealLevel reveal = RevealLevel.none,
  bool guarded = false,
  TurnOwner owner = TurnOwner.cpu,
}) {
  return PersonCard(
    id: 'p',
    type: type,
    number: number,
    status: status,
    reveal: reveal,
    isGuarded: guarded,
    owner: owner,
  );
}

LifeDeathCard card(LifeDeathEffect effect, int number) =>
    LifeDeathCard(id: 'c', effect: effect, number: number);

void main() {
  const rules = GameRuleService();

  group('パワー判定', () {
    test('生死カードの数字が人カードの数字以上なら成功', () {
      expect(rules.judgePower(5, 5), isTrue);
      expect(rules.judgePower(9, 1), isTrue);
    });
    test('生死カードの数字が人カードの数字未満なら失敗', () {
      expect(rules.judgePower(4, 5), isFalse);
      expect(rules.judgePower(1, 9), isFalse);
    });
  });

  group('デッド', () {
    test('成功すると dead になる', () {
      final r = rules.applyEffect(person(number: 5), card(LifeDeathEffect.dead, 5));
      expect(r.success, isTrue);
      expect(r.updatedCard.status, PersonStatus.dead);
      expect(r.becameDead, isTrue);
    });
    test('alive でも dead に変更される', () {
      final r = rules.applyEffect(
        person(number: 3, status: PersonStatus.alive),
        card(LifeDeathEffect.dead, 9),
      );
      expect(r.updatedCard.status, PersonStatus.dead);
    });
    test('失敗すると状態は変化しない', () {
      final r = rules.applyEffect(person(number: 8), card(LifeDeathEffect.dead, 2));
      expect(r.success, isFalse);
      expect(r.updatedCard.status, PersonStatus.alive);
    });
  });

  group('アライブ', () {
    test('成功すると dead から復活する', () {
      final r = rules.applyEffect(
        person(number: 4, status: PersonStatus.dead),
        card(LifeDeathEffect.alive, 6),
      );
      expect(r.success, isTrue);
      expect(r.updatedCard.status, PersonStatus.alive);
      expect(r.becameAlive, isTrue);
    });
    test('既に alive なら成功だが状態変化なし', () {
      final r = rules.applyEffect(
        person(number: 4, status: PersonStatus.alive),
        card(LifeDeathEffect.alive, 6),
      );
      expect(r.success, isTrue);
      expect(r.becameAlive, isFalse);
      expect(r.updatedCard.status, PersonStatus.alive);
    });
  });

  group('キープによる防御', () {
    test('キープ成功で防御が付与される', () {
      final r = rules.applyEffect(person(number: 5), card(LifeDeathEffect.keep, 5));
      expect(r.success, isTrue);
      expect(r.updatedCard.isGuarded, isTrue);
    });

    test('防御中はデッドを1回無効化し防御が解除される', () {
      final guarded = person(number: 3, guarded: true);
      final r = rules.applyEffect(guarded, card(LifeDeathEffect.dead, 9));
      expect(r.guardBlocked, isTrue);
      expect(r.updatedCard.status, PersonStatus.alive); // 無効化
      expect(r.updatedCard.isGuarded, isFalse); // 解除
    });

    test('防御解除後は次のデッドが通る', () {
      final guarded = person(number: 3, guarded: true);
      final first = rules.applyEffect(guarded, card(LifeDeathEffect.dead, 9));
      final second =
          rules.applyEffect(first.updatedCard, card(LifeDeathEffect.dead, 9));
      expect(second.updatedCard.status, PersonStatus.dead);
    });

    test('キープにキープを重ねても防御は永続化せず更新のみ', () {
      final r1 = rules.applyEffect(person(number: 2), card(LifeDeathEffect.keep, 5));
      final r2 =
          rules.applyEffect(r1.updatedCard, card(LifeDeathEffect.keep, 5));
      expect(r2.updatedCard.isGuarded, isTrue);
      // 1回の攻撃で解除されることを確認。
      final atk =
          rules.applyEffect(r2.updatedCard, card(LifeDeathEffect.dead, 9));
      expect(atk.updatedCard.isGuarded, isFalse);
    });
  });

  group('情報公開', () {
    test('成功すると種類+数字まで公開', () {
      final r = rules.applyEffect(person(number: 5), card(LifeDeathEffect.dead, 5));
      expect(r.updatedCard.reveal, RevealLevel.full);
    });
    test('失敗すると数字のみ公開', () {
      final r = rules.applyEffect(person(number: 8), card(LifeDeathEffect.dead, 2));
      expect(r.updatedCard.reveal, RevealLevel.numberOnly);
    });
    test('一度公開された情報は下がらない', () {
      final full = person(number: 8, reveal: RevealLevel.full);
      final r = rules.applyEffect(full, card(LifeDeathEffect.dead, 2)); // 失敗
      expect(r.updatedCard.reveal, RevealLevel.full);
    });
  });

  group('中立ペナルティ', () {
    test('善人陣営が中立を dead にするとペナルティ', () {
      final neutral = person(type: PersonType.neutral, number: 3);
      final r = rules.applyEffect(neutral, card(LifeDeathEffect.dead, 5));
      final penalty = rules.isNeutralPenalty(
        actorFaction: Faction.good,
        target: neutral,
        becameDead: r.becameDead,
        becameAlive: r.becameAlive,
      );
      expect(penalty, isTrue);
    });
    test('悪人陣営が中立を alive にするとペナルティ', () {
      final neutral =
          person(type: PersonType.neutral, number: 3, status: PersonStatus.dead);
      final r = rules.applyEffect(neutral, card(LifeDeathEffect.alive, 5));
      final penalty = rules.isNeutralPenalty(
        actorFaction: Faction.evil,
        target: neutral,
        becameDead: r.becameDead,
        becameAlive: r.becameAlive,
      );
      expect(penalty, isTrue);
    });
    test('キープでは中立ペナルティは発生しない', () {
      final neutral = person(type: PersonType.neutral, number: 3);
      final r = rules.applyEffect(neutral, card(LifeDeathEffect.keep, 5));
      final penalty = rules.isNeutralPenalty(
        actorFaction: Faction.good,
        target: neutral,
        becameDead: r.becameDead,
        becameAlive: r.becameAlive,
      );
      expect(penalty, isFalse);
    });
    test('陣営と同方向の変化ならペナルティなし', () {
      final neutral = person(type: PersonType.neutral, number: 3);
      final r = rules.applyEffect(neutral, card(LifeDeathEffect.dead, 5));
      // 悪人陣営が中立を殺してもペナルティなし。
      final penalty = rules.isNeutralPenalty(
        actorFaction: Faction.evil,
        target: neutral,
        becameDead: r.becameDead,
        becameAlive: r.becameAlive,
      );
      expect(penalty, isFalse);
    });
  });

  group('ゲーム終了判定', () {
    PlayerState make(TurnOwner o, List<LifeDeathCard> hand) => PlayerState(
          owner: o,
          faction: Faction.good,
          persons: const [],
          hand: hand,
        );

    test('両者とも使用可能カードが無ければ終了', () {
      final used = card(LifeDeathEffect.dead, 5).copyWith(isUsed: true);
      expect(
        rules.isGameOver(make(TurnOwner.player, [used]), make(TurnOwner.cpu, [used])),
        isTrue,
      );
    });
    test('片方でも残っていれば終了しない', () {
      final used = card(LifeDeathEffect.dead, 5).copyWith(isUsed: true);
      final unused = card(LifeDeathEffect.dead, 5);
      expect(
        rules.isGameOver(
            make(TurnOwner.player, [unused]), make(TurnOwner.cpu, [used])),
        isFalse,
      );
    });
  });
}
