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
        ? Colors.white
        : enabled
        ? const Color(0xFF7E9BC2)
        : const Color(0xFF4B4B4B);
    return GestureDetector(
      onTap: enabled || selected ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF202024),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  attributeVisible ? person.attribute.label : '?',
                  maxLines: 1,
                  style: TextStyle(
                    color: attributeVisible
                        ? _attributeColor(person.attribute)
                        : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('人物 ${person.rank}', style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 1),
                Text(
                  person.isAlive ? '生' : '死',
                  style: TextStyle(
                    color: person.isAlive
                        ? const Color(0xFF71B9F0)
                        : const Color(0xFFE36A62),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '数字 ${numberVisible ? slot.hiddenNumber : '?'}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (scoreDetail != null)
                  Text(
                    '${scoreDetail!.faction == Faction.savior ? '救' : '執'} +${scoreDetail!.points}',
                    style: const TextStyle(
                      color: Color(0xFFD6B25E),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (person.isJudged)
              const Positioned(
                right: 1,
                top: 0,
                child: Text(
                  '判',
                  style: TextStyle(
                    color: Color(0xFFD6B25E),
                    fontWeight: FontWeight.w900,
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
