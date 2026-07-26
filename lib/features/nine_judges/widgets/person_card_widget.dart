import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class PersonCardWidget extends StatelessWidget {
  const PersonCardWidget({
    required this.person,
    this.coordinate = '',
    required this.attributeVisible,
    required this.viewerEyeKnown,
    required this.opponentEyeKnown,
    required this.viewerLabel,
    required this.opponentLabel,
    required this.selected,
    required this.cpuHighlighted,
    required this.enabled,
    required this.onTap,
    this.scoreDetail,
    super.key,
  });

  final PersonCard person;
  final String coordinate;
  final bool attributeVisible;
  final bool viewerEyeKnown;
  final bool opponentEyeKnown;
  final String viewerLabel;
  final String opponentLabel;
  final bool selected;
  final bool cpuHighlighted;
  final bool enabled;
  final VoidCallback onTap;
  final ({Faction faction, int points})? scoreDetail;

  @override
  Widget build(BuildContext context) {
    final confirmed = person.isConfirmed;
    final stateAccent = confirmed
        ? person.isAlive
              ? AppTheme.alive
              : AppTheme.dead
        : selected || cpuHighlighted
        ? const Color(0xFFFFD76A)
        : enabled
        ? AppTheme.accent
        : const Color(0xFF66552E);

    return Semantics(
      label:
          '$coordinate ${attributeVisible ? person.attribute.label : '正体不明'} '
          '${person.verdictState.label}',
      button: enabled,
      child: AnimatedScale(
        scale: cpuHighlighted ? 1.035 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('person-${person.id}'),
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              key: Key('card-surface-${person.verdictState.name}'),
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _cardColors(confirmed),
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: stateAccent,
                  width: confirmed || selected || cpuHighlighted ? 2.2 : 1.1,
                ),
                boxShadow: [
                  if (selected || cpuHighlighted || confirmed)
                    BoxShadow(
                      color: stateAccent.withValues(alpha: .33),
                      blurRadius: 9,
                      spreadRadius: .5,
                    ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    _CardHeader(
                      coordinate: coordinate,
                      attributeVisible: attributeVisible,
                      attribute: person.attribute,
                      viewerEyeKnown: viewerEyeKnown,
                      opponentEyeKnown: opponentEyeKnown,
                      viewerLabel: viewerLabel,
                      opponentLabel: opponentLabel,
                      confirmed: confirmed,
                    ),
                    Expanded(
                      child: _CharacterPortrait(
                        person: person,
                        attributeVisible: attributeVisible,
                        compact: constraints.maxHeight < 115,
                      ),
                    ),
                    Text(
                      person.verdictState.label,
                      key: Key('verdict-${person.verdictState.name}'),
                      maxLines: 1,
                      style: TextStyle(
                        color: _stateColor(person.verdictState),
                        fontSize: constraints.maxHeight < 115 ? 9 : 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 17,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            _VerdictChip(
                              index: i,
                              action: i < person.verdictHistory.length
                                  ? person.verdictHistory[i]
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    if (confirmed)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            person.isAlive ? Icons.check_circle : Icons.cancel,
                            size: 10,
                            color: stateAccent,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              person.isAlive ? 'ALIVE 生存確定' : 'DEAD 死亡確定',
                              key: const Key('confirmed-label'),
                              maxLines: 1,
                              style: TextStyle(
                                color: stateAccent,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (selected)
                      const Text(
                        '選択中',
                        key: Key('selected-label'),
                        style: TextStyle(
                          color: Color(0xFFFFD76A),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                    if (scoreDetail case final detail?)
                      Text(
                        '${detail.faction.label} +${detail.points} POINT',
                        maxLines: 1,
                        style: const TextStyle(fontSize: 7),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _cardColors(bool confirmed) {
    if (!confirmed) return const [Color(0xF523211C), Color(0xF5121216)];
    return person.isAlive
        ? const [Color(0xE6254936), Color(0xF5102119)]
        : const [Color(0xE64A2322), Color(0xF5221012)];
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.coordinate,
    required this.attributeVisible,
    required this.attribute,
    required this.viewerEyeKnown,
    required this.opponentEyeKnown,
    required this.viewerLabel,
    required this.opponentLabel,
    required this.confirmed,
  });

  final String coordinate;
  final bool attributeVisible;
  final PersonAttribute attribute;
  final bool viewerEyeKnown;
  final bool opponentEyeKnown;
  final String viewerLabel;
  final String opponentLabel;
  final bool confirmed;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          coordinate,
          key: Key('coordinate-$coordinate'),
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 3),
      Expanded(
        child: Text(
          attributeVisible ? attribute.label : '正体不明',
          key: Key(attributeVisible ? 'attribute-known' : 'attribute-hidden'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: attributeVisible
                ? _attributeColor(attribute)
                : Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (!confirmed) ...[
        if (viewerEyeKnown) _EyeMark(label: viewerLabel, color: AppTheme.eye),
        if (opponentEyeKnown)
          _EyeMark(label: opponentLabel, color: AppTheme.executor),
      ],
    ],
  );
}

class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({
    required this.person,
    required this.attributeVisible,
    required this.compact,
  });

  final PersonCard person;
  final bool attributeVisible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = attributeVisible
        ? _attributeColor(person.attribute)
        : Colors.blueGrey;
    final icon = attributeVisible
        ? switch (person.attribute) {
            PersonAttribute.good => Icons.air,
            PersonAttribute.evil => Icons.local_fire_department,
            PersonAttribute.neutral => Icons.balance,
          }
        : Icons.person;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [color.withValues(alpha: .24), Colors.transparent],
              ),
            ),
          ),
        ),
        Icon(
          icon,
          key: Key(
            attributeVisible
                ? 'attribute-icon-${person.attribute.name}'
                : 'attribute-icon-hidden',
          ),
          size: compact ? 22 : 30,
          color: color,
        ),
      ],
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.index, required this.action});

  final int index;
  final VerdictActionType? action;

  @override
  Widget build(BuildContext context) {
    final isLife = action == VerdictActionType.life;
    final color = action == null
        ? Colors.white24
        : isLife
        ? AppTheme.alive
        : AppTheme.dead;
    return Container(
      key: action == null
          ? Key('verdict-chip-$index-empty')
          : Key('verdict-chip-$index-${action!.name}'),
      width: 20,
      height: 15,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: action == null ? Colors.black26 : color.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        action?.label ?? '',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EyeMark extends StatelessWidget {
  const _EyeMark({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 2),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility, size: 8, color: color),
        Text(
          label,
          style: TextStyle(
            fontSize: 5,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

Color _attributeColor(PersonAttribute attribute) => switch (attribute) {
  PersonAttribute.good => AppTheme.good,
  PersonAttribute.evil => AppTheme.evil,
  PersonAttribute.neutral => AppTheme.neutral,
};

Color _stateColor(VerdictState state) => switch (state) {
  VerdictState.alive || VerdictState.aliveConfirmed => AppTheme.alive,
  VerdictState.dead || VerdictState.deadConfirmed => AppTheme.dead,
  VerdictState.deliberating => const Color(0xFFDCC277),
};
