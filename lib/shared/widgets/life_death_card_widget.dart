import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/life_death_card.dart';
import '../utils/card_visuals.dart';

/// 手札の生死カード1枚を描画する Widget。
class LifeDeathCardWidget extends StatelessWidget {
  const LifeDeathCardWidget({
    super.key,
    required this.card,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.width = 72,
  });

  final LifeDeathCard card;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = CardVisuals.effectColor(card.effect);
    final used = card.isUsed;

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${CardVisuals.effectLabel(card.effect)} ${card.number}${used ? " 使用済み" : ""}',
      child: GestureDetector(
        onTap: (enabled && !used) ? onTap : null,
        child: AnimatedScale(
          scale: selected ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Opacity(
            opacity: used ? 0.3 : 1.0,
            child: Container(
              width: width,
              height: width * 1.35,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppTheme.good : color.withValues(alpha: 0.7),
                  width: selected ? 3 : 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.28),
                    AppTheme.surface,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(CardVisuals.effectIcon(card.effect),
                      color: color, size: width * 0.4),
                  Text(
                    '${card.number}',
                    style: TextStyle(
                      fontSize: width * 0.36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEDE6D4),
                    ),
                  ),
                  Text(
                    CardVisuals.effectLabel(card.effect),
                    style: TextStyle(fontSize: width * 0.17, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
