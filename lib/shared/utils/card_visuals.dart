import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/enums.dart';

/// 人カード・生死カードの見た目（アイコン・色・ラベル）をまとめたヘルパ。
///
/// 色だけに依存せず、アイコン＋文字でも状態が分かるようにする。
class CardVisuals {
  CardVisuals._();

  /// 種類のアイコン。善人=天秤/光、悪人=刃/炎、中立=仮面。
  static IconData personTypeIcon(PersonType type) {
    switch (type) {
      case PersonType.good:
        return Icons.balance; // 天秤
      case PersonType.evil:
        return Icons.local_fire_department; // 炎
      case PersonType.neutral:
        return Icons.theater_comedy; // 仮面
    }
  }

  static Color personTypeColor(PersonType type) {
    switch (type) {
      case PersonType.good:
        return AppTheme.good;
      case PersonType.evil:
        return AppTheme.evil;
      case PersonType.neutral:
        return AppTheme.neutral;
    }
  }

  static String personTypeLabel(PersonType type) {
    switch (type) {
      case PersonType.good:
        return '善人';
      case PersonType.evil:
        return '悪人';
      case PersonType.neutral:
        return '中立';
    }
  }

  /// 生死カードのアイコン。
  static IconData effectIcon(LifeDeathEffect effect) {
    switch (effect) {
      case LifeDeathEffect.dead:
        return Icons.dangerous; // 骸骨代わり
      case LifeDeathEffect.alive:
        return Icons.favorite; // 心臓
      case LifeDeathEffect.keep:
        return Icons.shield; // 盾
    }
  }

  static Color effectColor(LifeDeathEffect effect) {
    switch (effect) {
      case LifeDeathEffect.dead:
        return AppTheme.evil;
      case LifeDeathEffect.alive:
        return AppTheme.alive;
      case LifeDeathEffect.keep:
        return AppTheme.keep;
    }
  }

  static String effectLabel(LifeDeathEffect effect) {
    switch (effect) {
      case LifeDeathEffect.dead:
        return 'デッド';
      case LifeDeathEffect.alive:
        return 'アライブ';
      case LifeDeathEffect.keep:
        return 'キープ';
    }
  }

  /// 状態のアイコン（alive/dead）。dead は墓標代わりのアイコン。
  static IconData statusIcon(PersonStatus status) {
    switch (status) {
      case PersonStatus.dead:
        return Icons.heart_broken; // 死（墓標/骸骨の代替）
      case PersonStatus.alive:
        return Icons.favorite; // 生命
      case PersonStatus.hidden:
        return Icons.help_outline;
    }
  }
}
