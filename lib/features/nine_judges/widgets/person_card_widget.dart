import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class PersonCardWidget extends StatelessWidget {
  const PersonCardWidget({
    required this.slot,
    required this.attributeVisible,
    required this.numberVisible,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.attributeEyeKnown = false,
    this.attributeInitiallyKnown = false,
    this.numberEyeKnown = false,
    this.scoreDetail,
    super.key,
  });

  final BoardSlot slot;
  final bool attributeVisible;
  final bool numberVisible;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool attributeEyeKnown;
  final bool attributeInitiallyKnown;
  final bool numberEyeKnown;
  final ({Faction faction, int points})? scoreDetail;

  @override
  Widget build(BuildContext context) {
    final person = slot.person;
    final borderColor = person.isJudged
        ? const Color(0xFFD6B25E)
        : selected
        ? const Color(0xFFFFD76A)
        : person.isUnderReview
        ? const Color(0xFFD6B25E)
        : enabled
        ? const Color(0xFF8DA4BD)
        : const Color(0xFF45484E);
    return GestureDetector(
      onTap: enabled || selected ? onTap : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 105;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.all(compact ? 3 : 5),
            decoration: BoxDecoration(
              color: person.isJudged
                  ? const Color(0xFF171719)
                  : enabled
                  ? const Color(0xFF202329)
                  : const Color(0xFF181A1E),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: borderColor,
                width: selected || person.isJudged ? 2 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x66FFD76A),
                        blurRadius: 7,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: compact ? 10 : 15),
                    Icon(
                      Icons.person,
                      size: compact ? 22 : 29,
                      color: person.isJudged ? Colors.white30 : Colors.white54,
                    ),
                    Text(
                      person.isAlive ? '生' : '死',
                      key: Key('life-state-${person.id}'),
                      style: TextStyle(
                        color: person.isAlive
                            ? const Color(0xFF62B9F3)
                            : const Color(0xFFF0645A),
                        fontSize: compact ? 18 : 22,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (!person.isJudged)
                      Text(
                        person.isUnderReview
                            ? '審議中'
                            : attributeEyeKnown
                            ? 'EYE確認済み'
                            : '未審議',
                        key: person.isUnderReview
                            ? const Key('under-review-label')
                            : const Key('not-reviewed-label'),
                        style: TextStyle(
                          fontSize: compact ? 7 : 9,
                          color: person.isUnderReview
                              ? const Color(0xFFD6B25E)
                              : attributeEyeKnown
                              ? const Color(0xFFB49CF2)
                              : Colors.white38,
                        ),
                      ),
                    if (scoreDetail != null)
                      Text(
                        '${scoreDetail!.faction.label} +${scoreDetail!.points}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD6B25E),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (person.hasLifeShield || person.isJudged)
                      SizedBox(height: compact ? 13 : 16),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Row(
                    children: [
                      Text(
                        attributeVisible ? person.attribute.label : '?',
                        style: TextStyle(
                          color: attributeVisible
                              ? _attributeColor(person.attribute)
                              : Colors.white70,
                          fontSize: compact ? 9 : 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (attributeEyeKnown)
                        const Icon(
                          Icons.visibility,
                          size: 9,
                          color: Color(0xFFD6B25E),
                        ),
                      if (attributeInitiallyKnown)
                        const Icon(
                          Icons.diamond_outlined,
                          size: 9,
                          color: Color(0xFFD6B25E),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: compact ? 19 : 22,
                    height: compact ? 19 : 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF111216),
                      border: Border.all(color: const Color(0xFFD6B25E)),
                    ),
                    child: Text(
                      '${person.rank}',
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (person.hasLifeShield)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: _StatusBadge(
                      key: const Key('life-shield'),
                      icon: Icons.shield_outlined,
                      label: 'LIFE',
                      color: const Color(0xFF62D58A),
                      compact: compact,
                    ),
                  ),
                if (person.isJudged)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _StatusBadge(
                      key: const Key('judged-label'),
                      icon: Icons.gavel,
                      label: '判決済み',
                      color: const Color(0xFFD6B25E),
                      compact: compact,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _attributeColor(PersonAttribute attribute) => switch (attribute) {
    PersonAttribute.good => const Color(0xFF69BDF2),
    PersonAttribute.evil => const Color(0xFFF0645A),
    PersonAttribute.neutral => const Color(0xFFC8C3B8),
  };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xE6111215),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 8 : 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 7 : 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
