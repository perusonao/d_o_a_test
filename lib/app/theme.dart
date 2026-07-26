import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFF0B0B10);
  static const surface = Color(0xE613141A);
  static const parchment = Color(0xFF211C16);
  static const parchmentLight = Color(0xFF332A1F);
  static const accent = Color(0xFFC8A34A);
  static const savior = Color(0xFF4EB5E8);
  static const executor = Color(0xFFE0554F);
  static const eye = Color(0xFFB078FF);
  static const good = Color(0xFF6EC8F2);
  static const evil = Color(0xFFE05A50);
  static const neutral = Color(0xFFD0A84E);
  static const alive = Color(0xFF4FCB84);
  static const dead = Color(0xFFE1524A);
  static const keep = Color(0xFF5A8FB0);

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
        bodyColor: const Color(0xFFF0E8D8),
        displayColor: const Color(0xFFF0E8D8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xEE0B0B10),
        elevation: 0,
        centerTitle: true,
      ),
      dividerColor: accent.withValues(alpha: .28),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF141218),
        modalBackgroundColor: Color(0xFF141218),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF141218),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: accent),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  static Color factionColor(bool isSavior) => isSavior ? savior : executor;
}
