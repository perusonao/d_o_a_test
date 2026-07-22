import 'dart:math';

import '../domain/enums.dart';
import '../domain/game_constants.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';

/// 対戦開始時のセットアップ処理をまとめたサービス。
///
/// 人カードの生成・配布、生死カード手札の生成を担当する。
/// 「5枚シャッフル・スワップ」など将来のルールはこのクラスに追加できるよう独立させている。
class GameSetupService {
  GameSetupService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 人カードを各プレイヤーに配る。
  ///
  /// B（盤面の均等化）: 各プレイヤーに善人・悪人・中立を
  /// [GameConstants.personTypeCountPerPlayer] 枚ずつ配り、配り運を排除する。
  /// 数字は 1〜9 からランダムに割り当てる（種類構成は固定、数字のみ変動）。
  /// C（数字の初期公開）が有効なら、初期の公開レベルを numberOnly にする。
  ///
  /// 戻り値は (playerPersons, cpuPersons)。
  ({List<PersonCard> player, List<PersonCard> cpu}) dealPersonCards() {
    final initialReveal = GameConstants.revealNumbersAtStart
        ? RevealLevel.numberOnly
        : RevealLevel.none;
    final n = GameConstants.personTypeCountPerPlayer;

    final player = <PersonCard>[];
    final cpu = <PersonCard>[];

    for (final type in PersonType.values) {
      // 1〜9 をシャッフルし、先頭 n 枚をプレイヤー、続く n 枚を CPU に割り当てる。
      final numbers = List<int>.generate(
        GameConstants.personNumberMax - GameConstants.personNumberMin + 1,
        (i) => GameConstants.personNumberMin + i,
      )..shuffle(_random);

      for (var i = 0; i < n; i++) {
        player.add(_makePerson(
            type, numbers[i], TurnOwner.player, player.length, initialReveal));
      }
      for (var i = 0; i < n; i++) {
        cpu.add(_makePerson(
            type, numbers[n + i], TurnOwner.cpu, cpu.length, initialReveal));
      }
    }

    // 種類がまとまって並ばないよう表示順をシャッフル（ID は不変で一意）。
    player.shuffle(_random);
    cpu.shuffle(_random);
    return (player: player, cpu: cpu);
  }

  PersonCard _makePerson(
    PersonType type,
    int number,
    TurnOwner owner,
    int index,
    RevealLevel reveal,
  ) {
    return PersonCard(
      id: 'person_${owner.name}_$index',
      type: type,
      number: number,
      status: PersonStatus.alive, // 初期状態は alive
      reveal: reveal,
      owner: owner,
    );
  }

  /// 生死カードの手札を生成する。
  ///
  /// A（手札の均等化）: 両プレイヤーに [GameConstants.balancedHand] の
  /// 共通テンプレート（効果・数字を固定）を配り、引き運を排除する。
  /// 将来的な正式デッキ構成やドラフトへ差し替えやすいよう独立関数にしている。
  List<LifeDeathCard> buildLifeDeathHand(TurnOwner owner) {
    final template = GameConstants.balancedHand;
    final hand = <LifeDeathCard>[];
    for (var i = 0; i < template.length; i++) {
      hand.add(
        LifeDeathCard(
          id: 'ld_${owner.name}_$i',
          effect: template[i].effect,
          number: template[i].number,
          isUsed: false,
        ),
      );
    }
    return hand;
  }
}
