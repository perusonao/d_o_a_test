import 'dart:math';

import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/action_card.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_action.dart';
import 'package:dead_or_alive/features/game/domain/game_state.dart';
import 'package:dead_or_alive/features/game/domain/human_card.dart';
import 'package:dead_or_alive/features/game/domain/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// テスト用に人間9枚と手札を組み立てる。
GameState buildState({
  required List<HumanCard> humans,
  Faction aFaction = Faction.savior,
}) {
  List<ActionCard> hand(PlayerId owner) => [
    ActionCard(id: '${owner.name}_life', type: ActionType.life, owner: owner),
    ActionCard(id: '${owner.name}_death', type: ActionType.death, owner: owner),
    ActionCard(
      id: '${owner.name}_prot',
      type: ActionType.protect,
      owner: owner,
    ),
  ];
  return GameState(
    humans: humans,
    playerA: Player(id: PlayerId.a, faction: aFaction, hand: hand(PlayerId.a)),
    playerB: Player(
      id: PlayerId.b,
      faction: aFaction == Faction.savior
          ? Faction.executioner
          : Faction.savior,
      hand: hand(PlayerId.b),
    ),
    current: PlayerId.a,
    phase: GamePhase.playing,
  );
}

HumanCard human(
  int pos,
  HumanType type,
  int points, {
  CardState state = CardState.alive,
  bool protected = false,
}) => HumanCard(
  id: 'h$pos',
  position: pos,
  type: type,
  points: points,
  state: state,
  protected: protected,
);

List<HumanCard> filler() => [
  for (var i = 1; i < 9; i++) human(i, HumanType.neutral, 1),
];

void main() {
  final engine = GameEngine(random: Random(0));

  GameAction act(GameState s, ActionType type, int pos) => GameAction(
    player: s.current,
    actionCardId: s.currentPlayer.hand
        .firstWhere((c) => c.type == type && !c.used)
        .id,
    targetPosition: pos,
  );

  group('生カード', () {
    test('死→生に復活し、公開される', () {
      var s = buildState(
        humans: [
          human(0, HumanType.good, 3, state: CardState.dead),
          ...filler(),
        ],
      );
      s = engine.applyAction(s, act(s, ActionType.life, 0));
      final h = s.humanAt(0);
      expect(h.state, CardState.alive);
      expect(h.revealed, isTrue);
    });
  });

  group('死カード', () {
    test('生→死になり、公開される', () {
      var s = buildState(humans: [human(0, HumanType.good, 3), ...filler()]);
      s = engine.applyAction(s, act(s, ActionType.death, 0));
      final h = s.humanAt(0);
      expect(h.state, CardState.dead);
      expect(h.revealed, isTrue);
    });
  });

  group('保カード', () {
    test('保護を付与し、公開しない', () {
      var s = buildState(humans: [human(0, HumanType.good, 3), ...filler()]);
      s = engine.applyAction(s, act(s, ActionType.protect, 0));
      final h = s.humanAt(0);
      expect(h.protected, isTrue);
      expect(h.revealed, isFalse);
    });

    test('保護中に死を受けると保護だけ壊れ、生死は不変', () {
      var s = buildState(
        humans: [human(0, HumanType.good, 3, protected: true), ...filler()],
      );
      s = engine.applyAction(s, act(s, ActionType.death, 0));
      final h = s.humanAt(0);
      expect(h.protected, isFalse); // 保護は壊れる
      expect(h.state, CardState.alive); // 生死は変化なし
      expect(s.lastProtectAbsorbed, isTrue);
    });
  });

  group('公開処理', () {
    test('一度公開されたら戻らない（死→保でも公開のまま）', () {
      var s = buildState(humans: [human(0, HumanType.good, 3), ...filler()]);
      s = engine.applyAction(s, act(s, ActionType.death, 0)); // A: 公開
      // B が同じ位置に保を使う（保は公開しないが、既に公開済み）。
      s = engine.applyAction(s, act(s, ActionType.protect, 0));
      expect(s.humanAt(0).revealed, isTrue);
    });
  });

  group('ゲーム終了', () {
    test('両者の手札が尽きたら finished', () {
      var s = buildState(
        humans: filler()..insert(0, human(0, HumanType.good, 3)),
      );
      // A3手・B3手を交互に消化（対象は位置0で十分）。
      for (var i = 0; i < 6; i++) {
        final t = s.currentPlayer.usableCards.first.type;
        s = engine.applyAction(s, act(s, t, 0));
      }
      expect(s.phase, GamePhase.finished);
      expect(s.bothHandsEmpty, isTrue);
    });
  });

  group('得点計算', () {
    test('善人/中立=生存で救済者、悪人=死亡で救済者。合計は常に18', () {
      // 全員生存の初期状態で集計。
      final humans = <HumanCard>[];
      var pos = 0;
      for (final type in HumanType.values) {
        for (final pt in [1, 2, 3]) {
          humans.add(human(pos++, type, pt));
        }
      }
      final s = buildState(humans: humans);
      final r = engine.score(s);
      // 全員生存: 善人(6)+中立(6)=救済者12、悪人(6)=執行者6。
      expect(r.saviorScore, 12);
      expect(r.executionerScore, 6);
      expect(r.saviorScore + r.executionerScore, 18);
      expect(r.winner, Faction.savior);
    });

    test('同点(9-9)は引き分け', () {
      // 各種類 1,2,3 を使い、救済者=執行者=9 になるよう状態を設定。
      final humans = [
        // 善人: 1,2 生存(救済3) / 3 死亡(執行3)
        human(0, HumanType.good, 1),
        human(1, HumanType.good, 2),
        human(2, HumanType.good, 3, state: CardState.dead),
        // 中立: 3 生存(救済3) / 1,2 死亡(執行3)
        human(3, HumanType.neutral, 3),
        human(4, HumanType.neutral, 1, state: CardState.dead),
        human(5, HumanType.neutral, 2, state: CardState.dead),
        // 悪人: 3 死亡(救済3) / 1,2 生存(執行3)
        human(6, HumanType.evil, 3, state: CardState.dead),
        human(7, HumanType.evil, 1),
        human(8, HumanType.evil, 2),
      ];
      final s = buildState(humans: humans);
      final r = engine.score(s);
      expect(r.saviorScore, 9);
      expect(r.executionerScore, 9);
      expect(r.saviorScore + r.executionerScore, 18);
      expect(r.isDraw, isTrue);
      expect(r.winner, isNull);
    });
  });

  group('表向き無変化アクションの禁止', () {
    test('公開済み生存カードへの生は禁止、死は許可', () {
      final alive = human(
        0,
        HumanType.good,
        3,
      ).copyWith(revealed: true); // 公開・生存
      expect(GameEngine.isNoOpBlocked(ActionType.life, alive), isTrue);
      expect(GameEngine.isNoOpBlocked(ActionType.death, alive), isFalse);
    });
    test('公開済み死亡カードへの死は禁止、生は許可', () {
      final dead = human(
        0,
        HumanType.good,
        3,
        state: CardState.dead,
      ).copyWith(revealed: true);
      expect(GameEngine.isNoOpBlocked(ActionType.death, dead), isTrue);
      expect(GameEngine.isNoOpBlocked(ActionType.life, dead), isFalse);
    });
    test('保護済みへの保は禁止（表裏問わず）', () {
      final prot = human(0, HumanType.good, 3, protected: true);
      expect(GameEngine.isNoOpBlocked(ActionType.protect, prot), isTrue);
    });
    test('伏せた生存カードへの生は許可（公開のため）', () {
      final hidden = human(0, HumanType.good, 3); // 未公開・生存
      expect(GameEngine.isNoOpBlocked(ActionType.life, hidden), isFalse);
    });
    test('validate も禁止手を弾く', () {
      final s = buildState(
        humans: [
          human(0, HumanType.good, 3).copyWith(revealed: true),
          ...filler(),
        ],
      );
      final lifeCard = s.currentPlayer.hand.firstWhere(
        (c) => c.type == ActionType.life,
      );
      final err = engine.validate(s, actionCardId: lifeCard.id, position: 0);
      expect(err, isNotNull);
    });
  });

  group('診カード', () {
    ActionCard diagCard(GameState s) => s.currentPlayer.hand.firstWhere(
      (c) => c.type == ActionType.diagnose,
      orElse: () =>
          ActionCard(id: 'diag', type: ActionType.diagnose, owner: s.current),
    );

    test('診は自分だけ正体を確認でき、公開・状態変化しない', () {
      // 位置4(中段=誰も知らない)を対象にする。
      final humans = [
        for (var i = 0; i < 9; i++)
          human(i, i == 4 ? HumanType.evil : HumanType.neutral, i == 4 ? 3 : 1),
      ];
      var s = buildState(humans: humans);
      s = GameState(
        humans: s.humans,
        playerA: s.playerA.copyWith(
          hand: const [
            ActionCard(
              id: 'A_diag',
              type: ActionType.diagnose,
              owner: PlayerId.a,
            ),
          ],
        ),
        playerB: s.playerB,
        current: PlayerId.a,
        phase: GamePhase.playing,
      );
      final before = s.humanAt(4);
      expect(s.canSeeFace(PlayerId.a, 4), isFalse);
      s = engine.applyAction(
        s,
        GameAction(
          player: PlayerId.a,
          actionCardId: 'A_diag',
          targetPosition: 4,
        ),
      );
      final after = s.humanAt(4);
      expect(after.revealed, isFalse); // 公開されない
      expect(after.state, before.state); // 状態不変
      expect(s.canSeeFace(PlayerId.a, 4), isTrue); // A は見える
      expect(s.canSeeFace(PlayerId.b, 4), isFalse); // B は見えない
    });

    test('validate: 既に見えているカードへの診は禁止', () {
      var s = engine.setup(Faction.savior);
      s = engine.confirmPeek(s); // playing
      // A の既知は下段(6,7,8)。位置6は既知なので診は無駄→禁止。
      final diag = diagCard(s);
      final err = engine.validate(s, actionCardId: diag.id, position: 6);
      expect(err, isNotNull);
    });
  });

  group('セットアップ', () {
    test('9枚・善中悪3枚ずつ・各種類の得点は1,2,3', () {
      final s = engine.setup(Faction.savior);
      expect(s.humans.length, 9);
      for (final type in HumanType.values) {
        final pts =
            s.humans.where((h) => h.type == type).map((h) => h.points).toList()
              ..sort();
        expect(pts, [1, 2, 3]);
      }
      // 手札は各9枚。
      expect(s.playerA.hand.length, 9);
      expect(s.playerB.hand.length, 9);
      expect(s.playerA.faction, Faction.savior);
      expect(s.playerB.faction, Faction.executioner);
      expect(s.phase, GamePhase.peekA);
    });
  });
}
