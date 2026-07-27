import 'package:dead_or_alive/app/theme.dart';
import 'package:flutter/material.dart';

/// Shared visual language for the in-game screen. Keeping colours and metrics
/// here (instead of scattering literals across widgets) lets the board, header
/// and action bars read as one dark-fantasy system.
abstract final class GameColors {
  // Backdrop — a very dark navy "hall of judgement".
  static const background = Color(0xFF06070C);
  static const backdropTop = Color(0x8A0A0E1A);
  static const backdropMid = Color(0xC1070910);
  static const backdropBottom = Color(0xF608070C);

  // Thin, restrained gold used only for frames, dividers and coordinates.
  static const gold = Color(0xFFC7A24C);
  static const goldSoft = Color(0x55C7A24C);
  static const goldFaint = Color(0x22C7A24C);

  /// A deliberately muted gold for "it's not your turn" states, so CPU TURN
  /// never competes visually with the emphasized YOUR TURN.
  static const goldMuted = Color(0xFF8A7A55);

  // Factions.
  static const savior = Color(0xFF5AA9E6);
  static const saviorPanelTop = Color(0xFF15293F);
  static const saviorPanelBottom = Color(0xFF091321);
  static const executor = Color(0xFFDB5750);
  static const executorPanelTop = Color(0xFF3A1418);
  static const executorPanelBottom = Color(0xFF16090B);

  // Actions.
  static const life = Color(0xFF55D9ED);
  static const death = Color(0xFFE0554F);
  static const eye = Color(0xFFB078FF);

  // Text.
  static const text = Color(0xFFEDE4D0);
  static const textDim = Color(0xFF9C927D);

  // Attribute / state colours are shared with the rest of the app.
  static const good = AppTheme.good;
  static const evil = AppTheme.evil;
  static const neutral = AppTheme.neutral;
  static const alive = AppTheme.alive;
  static const dead = AppTheme.dead;

  static Color faction(bool isSavior) => isSavior ? savior : executor;
}

abstract final class GameMetrics {
  static const cardGap = 5.0;

  /// Card width / height. Below 1 the cards read as tall portraits.
  static const cardAspect = 0.74;
  static const cardRadius = 11.0;
  static const panelRadius = 12.0;

  /// Left gutter for row numbers and bottom gutter for column letters.
  static const rowGutter = 18.0;
  static const colGutter = 15.0;

  static const gap = 4.0;
  static const gapSm = 3.0;
}
