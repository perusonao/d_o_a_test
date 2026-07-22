import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/enums.dart';

/// カードの見た目（アイコン・色・ラベル）をまとめたヘルパ（Ver.0.3）。
/// 色だけに依存せず、アイコン＋文字でも状態が分かるようにする。
class CardVisuals {
  CardVisuals._();

  // --- 人カードの種類 ---
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

  // --- 生死カードの効果 ---
  static IconData effectIcon(LifeDeathEffect effect) {
    switch (effect) {
      case LifeDeathEffect.dead:
        return Icons.dangerous;
      case LifeDeathEffect.alive:
        return Icons.favorite;
      case LifeDeathEffect.seal:
        return Icons.lock; // 封印
    }
  }

  static Color effectColor(LifeDeathEffect effect) {
    switch (effect) {
      case LifeDeathEffect.dead:
        return AppTheme.evil;
      case LifeDeathEffect.alive:
        return AppTheme.alive;
      case LifeDeathEffect.seal:
        return AppTheme.keep;
    }
  }

  static String effectLabel(LifeDeathEffect effect) {
    switch (effect) {
      case LifeDeathEffect.dead:
        return 'デッド';
      case LifeDeathEffect.alive:
        return 'アライブ';
      case LifeDeathEffect.seal:
        return 'シール';
    }
  }

  // --- 状態 ---
  static IconData statusIcon(PersonStatus status) {
    switch (status) {
      case PersonStatus.dead:
        return Icons.heart_broken; // 死（墓標/骸骨の代替）
      case PersonStatus.alive:
        return Icons.favorite;
    }
  }

  // --- 役割 ---
  static IconData roleIcon(Role role) =>
      role == Role.savior ? Icons.shield_moon : Icons.gavel;

  static Color roleColor(Role role) =>
      role == Role.savior ? AppTheme.alive : AppTheme.evil;

  static String roleLabel(Role role) => role == Role.savior ? '救済者' : '執行者';

  static String roleGoal(Role role) => role == Role.savior
      ? '善人を生存させる'
      : '善人を死亡させる';
}
