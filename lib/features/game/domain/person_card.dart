import 'enums.dart';

/// 中央の共有場に伏せて並ぶ「人カード」（Ver.0.3）。
///
/// 正体（種類・数字）は原則ゲーム終了まで非公開。状態と封印だけが公開される。
class PersonCard {
  const PersonCard({
    required this.id,
    required this.position,
    required this.type,
    required this.number,
    this.status = PersonStatus.alive,
    this.sealed = false,
    this.knownBy = Knower.none,
  });

  /// 一意な ID。
  final String id;

  /// 3×3 の配置インデックス（0〜8）。
  final int position;

  /// 種類（善人 / 悪人 / 中立）。非公開。
  final PersonType type;

  /// 数字（1〜9・一意）。非公開。
  final int number;

  /// 現在状態（alive / dead）。マーカーとして公開。
  final PersonStatus status;

  /// 封印状態。true なら終了まで状態変更不可。マーカーとして公開。
  final bool sealed;

  /// この正体を誰が知っているか（none / player / cpu）。
  final Knower knownBy;

  PersonCard copyWith({
    PersonStatus? status,
    bool? sealed,
  }) {
    return PersonCard(
      id: id,
      position: position,
      type: type,
      number: number,
      status: status ?? this.status,
      sealed: sealed ?? this.sealed,
      knownBy: knownBy,
    );
  }

  bool get isAlive => status == PersonStatus.alive;
  bool get isDead => status == PersonStatus.dead;
}
