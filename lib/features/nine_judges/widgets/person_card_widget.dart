import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class PersonCardWidget extends StatelessWidget {
  const PersonCardWidget({
    required this.person,
    required this.attributeVisible,
    required this.attributeEyeKnown,
    required this.selected,
    required this.cpuHighlighted,
    required this.enabled,
    required this.onTap,
    this.scoreDetail,
    super.key,
  });
  final PersonCard person;
  final bool attributeVisible;
  final bool attributeEyeKnown;
  final bool selected;
  final bool cpuHighlighted;
  final bool enabled;
  final VoidCallback onTap;
  final ({Faction faction, int points})? scoreDetail;

  @override
  Widget build(BuildContext context) {
    final confirmed = person.isConfirmed;
    final border = confirmed
        ? const Color(0xFFB9BDC5)
        : selected || cpuHighlighted
        ? const Color(0xFFFFD76A)
        : const Color(0xFF66552E);
    return AnimatedScale(
      scale: cpuHighlighted ? 1.04 : 1,
      duration: const Duration(milliseconds: 160),
      child: InkWell(
        key: Key('person-${person.id}'),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: confirmed
                ? const Color(0xFF17181B)
                : const Color(0xFF222019),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: confirmed ? 2.5 : 1.3),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      attributeVisible ? person.attribute.label : '正体不明',
                      key: Key(
                        attributeVisible
                            ? 'attribute-known'
                            : 'attribute-hidden',
                      ),
                      style: TextStyle(
                        color: attributeVisible
                            ? _attributeColor(person.attribute)
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (attributeEyeKnown && !confirmed)
                    const Icon(
                      Icons.visibility,
                      size: 12,
                      color: Color(0xFFB49CF2),
                    ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.person, size: 27),
              Text(
                person.verdictState.label,
                key: Key('verdict-${person.verdictState.name}'),
                style: TextStyle(
                  color: person.isAlive
                      ? const Color(0xFF68D893)
                      : person.verdictState == VerdictState.deliberating
                      ? const Color(0xFFD6B25E)
                      : const Color(0xFFF0645A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '介入 ${person.verdictActionCount}/3',
                style: const TextStyle(fontSize: 8, color: Colors.white54),
              ),
              const Spacer(),
              if (confirmed)
                Text(
                  '確定 ${person.awardedBonus}点',
                  key: const Key('confirmed-label'),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  '操作可能',
                  style: TextStyle(fontSize: 8, color: Colors.white38),
                ),
              if (scoreDetail case final detail?)
                Text(
                  '${detail.faction.label} +${detail.points}',
                  style: const TextStyle(fontSize: 8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _attributeColor(PersonAttribute attribute) => switch (attribute) {
    PersonAttribute.good => const Color(0xFF69BDF2),
    PersonAttribute.evil => const Color(0xFFF0645A),
    PersonAttribute.neutral => const Color(0xFFC8C3B8),
  };
}
