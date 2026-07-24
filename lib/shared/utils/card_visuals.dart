import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/enums.dart';

/// カードの見た目（アイコン・色・ラベル）ヘルパ（Ver.0.4）。
class CardVisuals {
  CardVisuals._();

  // --- 人間カードの種類 ---
  static IconData humanTypeIcon(HumanType type) {
    switch (type) {
      case HumanType.good:
        return Icons.balance;
      case HumanType.neutral:
        return Icons.theater_comedy;
      case HumanType.evil:
        return Icons.local_fire_department;
    }
  }

  static Color humanTypeColor(HumanType type) {
    switch (type) {
      case HumanType.good:
        return AppTheme.good;
      case HumanType.neutral:
        return AppTheme.neutral;
      case HumanType.evil:
        return AppTheme.evil;
    }
  }

  static String humanTypeLabel(HumanType type) {
    switch (type) {
      case HumanType.good:
        return '善人';
      case HumanType.neutral:
        return '中立';
      case HumanType.evil:
        return '悪人';
    }
  }

  // --- アクションカード ---
  static const Color diagnoseColor = Color(0xFF9B7EDE); // 紫（診）

  static IconData actionIcon(ActionType type) {
    switch (type) {
      case ActionType.life:
        return Icons.favorite;
      case ActionType.death:
        return Icons.dangerous;
      case ActionType.protect:
        return Icons.shield;
      case ActionType.diagnose:
        return Icons.search;
    }
  }

  static Color actionColor(ActionType type) {
    switch (type) {
      case ActionType.life:
        return AppTheme.alive;
      case ActionType.death:
        return AppTheme.evil;
      case ActionType.protect:
        return AppTheme.keep;
      case ActionType.diagnose:
        return diagnoseColor;
    }
  }

  static String actionLabel(ActionType type) {
    switch (type) {
      case ActionType.life:
        return '生';
      case ActionType.death:
        return '死';
      case ActionType.protect:
        return '保';
      case ActionType.diagnose:
        return '診';
    }
  }

  // --- 陣営 ---
  static IconData factionIcon(Faction f) =>
      f == Faction.savior ? Icons.shield_moon : Icons.gavel;

  static Color factionColor(Faction f) =>
      f == Faction.savior ? AppTheme.alive : AppTheme.evil;

  static String factionLabel(Faction f) =>
      f == Faction.savior ? '救済者' : '執行者';
}
