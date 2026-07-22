import 'enums.dart';

/// 場に並ぶ「人カード」。
///
/// 種類・数字・状態・情報公開状態・防御状態・所有者を保持する。
/// 状態変更は copyWith で新しいインスタンスを生成する（イミュータブル）。
class PersonCard {
  const PersonCard({
    required this.id,
    required this.type,
    required this.number,
    this.status = PersonStatus.alive,
    this.reveal = RevealLevel.none,
    this.isGuarded = false,
    required this.owner,
  });

  /// 一意な ID。
  final String id;

  /// 種類（善人 / 悪人 / 中立）。
  final PersonType type;

  /// 数字（1〜9）。
  final int number;

  /// 現在状態（hidden / alive / dead）。
  final PersonStatus status;

  /// 情報公開状態。
  final RevealLevel reveal;

  /// キープによる防御状態（true の場合、次の dead/alive を1回無効化）。
  final bool isGuarded;

  /// 所有者（player / cpu）。
  final TurnOwner owner;

  PersonCard copyWith({
    PersonStatus? status,
    RevealLevel? reveal,
    bool? isGuarded,
  }) {
    return PersonCard(
      id: id,
      type: type,
      number: number,
      status: status ?? this.status,
      reveal: reveal ?? this.reveal,
      isGuarded: isGuarded ?? this.isGuarded,
      owner: owner,
    );
  }

  /// 情報公開レベルを引き上げる（下げることはしない）。
  PersonCard revealAtLeast(RevealLevel level) {
    if (level.index <= reveal.index) return this;
    return copyWith(reveal: level);
  }

  bool get isAlive => status == PersonStatus.alive;
  bool get isDead => status == PersonStatus.dead;
}
