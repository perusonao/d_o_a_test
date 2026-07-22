import 'package:flutter/material.dart';

/// ダークファンタジー寄りのテーマ定義。
///
/// 画像素材は使わず、色・図形・アイコンで世界観を表現する。
class AppTheme {
  AppTheme._();

  // 世界観カラー。
  static const Color background = Color(0xFF0E0E12);
  static const Color surface = Color(0xFF1B1B22);
  static const Color parchment = Color(0xFF2A2620); // 古びた紙・石板風
  static const Color parchmentLight = Color(0xFF3A342A);
  static const Color accent = Color(0xFFB8862F); // 金色のアクセント
  static const Color good = Color(0xFFE8C86A); // 善人：光
  static const Color evil = Color(0xFFC1443B); // 悪人：炎・刃
  static const Color neutral = Color(0xFF8A8FA3); // 中立：仮面
  static const Color alive = Color(0xFF6FB98F); // 生命
  static const Color dead = Color(0xFF6B6B72); // 死
  static const Color keep = Color(0xFF5A8FB0); // 封印・盾

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: good,
        surface: surface,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFE6E1D6),
        displayColor: const Color(0xFFE6E1D6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: good,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: accent),
        ),
      ),
    );
  }

  /// 陣営の色。
  static Color factionColor(bool isGood) => isGood ? good : evil;
}
