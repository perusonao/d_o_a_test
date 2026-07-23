import 'enums.dart';

/// 中央3×3に並ぶ「人間カード」（Ver.0.4）。
class HumanCard {
  const HumanCard({
    required this.id,
    required this.position,
    required this.type,
    required this.points,
    this.state = CardState.alive,
    this.protected = false,
    this.revealed = false,
    this.diagnosedByA = false,
    this.diagnosedByB = false,
  });

  /// 一意な ID。
  final String id;

  /// 配置インデックス（0〜8）。列: 左=0,3,6 / 中央=1,4,7 / 右=2,5,8。
  final int position;

  /// 種類（善人 / 中立 / 悪人）。
  final HumanType type;

  /// 得点（1〜3）。
  final int points;

  /// 生死状態。
  final CardState state;

  /// 保護状態。
  final bool protected;

  /// 公開状態（生/死を受けると公開、以後は戻らない）。
  final bool revealed;

  /// 「診」で正体を確認したプレイヤー（自分だけに見える・非公開）。
  final bool diagnosedByA;
  final bool diagnosedByB;

  HumanCard copyWith({
    CardState? state,
    bool? protected,
    bool? revealed,
    bool? diagnosedByA,
    bool? diagnosedByB,
  }) {
    return HumanCard(
      id: id,
      position: position,
      type: type,
      points: points,
      state: state ?? this.state,
      protected: protected ?? this.protected,
      revealed: revealed ?? this.revealed,
      diagnosedByA: diagnosedByA ?? this.diagnosedByA,
      diagnosedByB: diagnosedByB ?? this.diagnosedByB,
    );
  }

  /// 指定プレイヤーが「診」済みか。
  bool diagnosedBy(PlayerId id) =>
      id == PlayerId.a ? diagnosedByA : diagnosedByB;

  bool get isAlive => state == CardState.alive;
  bool get isDead => state == CardState.dead;

  /// この位置が属する列（0=左, 1=中央, 2=右）。
  int get column => position % 3;

  /// この位置が属する行（0=上段, 1=中段, 2=下段）。
  int get row => position ~/ 3;
}
