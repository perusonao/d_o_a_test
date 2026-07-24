import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class PersonCardWidget extends StatelessWidget {
  const PersonCardWidget({
    required this.slot,
    required this.attributeVisible,
    required this.numberVisible,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.scoreDetail,
    super.key,
  });

  final BoardSlot slot;
  final bool attributeVisible;
  final bool numberVisible;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final ({Faction faction, int points})? scoreDetail;

  @override
  Widget build(BuildContext context) {
    final person = slot.person;
    final borderColor = person.isJudged
        ? const Color(0xFFD6B25E)
        : selected
        ? const Color(0xFFFFD76A)
        : enabled
        ? const Color(0xFF7E9BC2)
        : const Color(0xFF4B4B4B);
    return GestureDetector(
      onTap: enabled || selected ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: person.isJudged
              ? const Color(0xFF1B1A18)
              : const Color(0xFF202024),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor,
            width: selected || person.isJudged ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person, size: 24, color: Colors.white54),
                Text(
                  person.isAlive ? '生' : '死',
                  style: TextStyle(
                    color: person.isAlive
                        ? const Color(0xFF71B9F0)
                        : const Color(0xFFE36A62),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (numberVisible)
                      const Icon(
                        Icons.visibility_outlined,
                        size: 10,
                        color: Colors.white54,
                      ),
                    Text(
                      ' ${numberVisible ? slot.hiddenNumber : '?'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (person.hasLifeShield)
                  const Text(
                    '♥ LIFE',
                    key: Key('life-shield'),
                    style: TextStyle(
                      color: Color(0xFF72D69A),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (person.isJudged)
                  const Text(
                    '判決済',
                    key: Key('judged-label'),
                    style: TextStyle(
                      color: Color(0xFFD6B25E),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (scoreDetail != null)
                  Text(
                    '${scoreDetail!.faction.label} +${scoreDetail!.points}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD6B25E),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 1,
              top: 0,
              child: Text(
                attributeVisible ? person.attribute.label : '?',
                style: TextStyle(
                  color: attributeVisible
                      ? _attributeColor(person.attribute)
                      : Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              right: 1,
              top: 0,
              child: Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38),
                ),
                child: Text(
                  '${person.rank}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _attributeColor(PersonAttribute attribute) => switch (attribute) {
    PersonAttribute.good => const Color(0xFF73B8EA),
    PersonAttribute.evil => const Color(0xFFE16A62),
    PersonAttribute.neutral => const Color(0xFFC8C3B8),
  };
}
