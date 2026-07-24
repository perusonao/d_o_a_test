import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/game/domain/action_card.dart';
import '../utils/card_visuals.dart';

/// 手札のアクションカード1枚（生 / 死 / 保）。数字は持たない。
class ActionCardWidget extends StatelessWidget {
  const ActionCardWidget({
    super.key,
    required this.card,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.width = 64,
  });

  final ActionCard card;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = CardVisuals.actionColor(card.type);
    final used = card.used;

    return Semantics(
      button: true,
      selected: selected,
      label: '${CardVisuals.actionLabel(card.type)}カード${used ? " 使用済み" : ""}',
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
                  colors: [color.withValues(alpha: 0.28), AppTheme.surface],
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CardVisuals.actionIcon(card.type),
                          color: color, size: width * 0.42),
                      const SizedBox(height: 3),
                      Text(CardVisuals.actionLabel(card.type),
                          style: TextStyle(
                              fontSize: width * 0.34,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEDE6D4))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
