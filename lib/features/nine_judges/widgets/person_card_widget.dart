import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/card_assets.dart';
import 'package:flutter/material.dart';

/// A single board card rendered in the dark-fantasy style of the mockup:
/// a full-bleed character portrait, corner badges for attribute and EYE, and a
/// scrimmed footer carrying the verdict state and the LIFE/DEATH history pips.
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
    this.targeting = false,
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
  final bool targeting;
  final VoidCallback onTap;
  final ({Faction faction, int points})? scoreDetail;

  @override
  Widget build(BuildContext context) {
    final confirmed = person.isConfirmed;
    final highlighted = selected || cpuHighlighted;
    final accent = confirmed
        ? (person.isAlive ? AppTheme.alive : AppTheme.dead)
        : highlighted
        ? const Color(0xFFFFD76A)
        : enabled
        ? AppTheme.accent
        : const Color(0xFF66552E);

    return Semantics(
      label:
          '$coordinate ${attributeVisible ? person.attribute.label : '正体不明'} '
          '${person.verdictState.label}',
      button: enabled,
      child: AnimatedOpacity(
        opacity: targeting && !enabled ? .5 : 1,
        duration: const Duration(milliseconds: 140),
        child: AnimatedScale(
          scale: highlighted ? 1.03 : 1,
          duration: const Duration(milliseconds: 140),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('person-${person.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? onTap : null,
              child: AnimatedContainer(
                key: Key('card-surface-${person.verdictState.name}'),
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent,
                    width: confirmed || highlighted ? 2.2 : 1.1,
                  ),
                  boxShadow: [
                    if (highlighted || confirmed)
                      BoxShadow(
                        color: accent.withValues(alpha: .4),
                        blurRadius: 10,
                        spreadRadius: .5,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.5),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final compact = c.maxHeight < 150;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _Portrait(
                            person: person,
                            attributeVisible: attributeVisible,
                            dimmed: !enabled && !confirmed && !highlighted,
                          ),
                          if (confirmed)
                            DecoratedBox(
                              key: Key(
                                person.isAlive
                                    ? 'confirmed-tint-alive'
                                    : 'confirmed-tint-dead',
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: person.isAlive
                                      ? const [
                                          Color(0x183DE6C3),
                                          Color(0x6630B99C),
                                        ]
                                      : const [
                                          Color(0x18FF4D55),
                                          Color(0x667B1721),
                                        ],
                                ),
                              ),
                            ),
                          const _Scrim(),
                          _Corners(
                            coordinate: coordinate,
                            attributeVisible: attributeVisible,
                            attribute: person.attribute,
                            viewerEyeKnown: viewerEyeKnown,
                            opponentEyeKnown: opponentEyeKnown,
                            viewerLabel: viewerLabel,
                            opponentLabel: opponentLabel,
                            confirmed: confirmed,
                            accent: accent,
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: _Footer(
                              person: person,
                              attributeVisible: attributeVisible,
                              accent: accent,
                              selected: selected,
                              compact: compact,
                              scoreDetail: scoreDetail,
                            ),
                          ),
                        ],
                      );
                    },
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

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.person,
    required this.attributeVisible,
    required this.dimmed,
  });

  final PersonCard person;
  final bool attributeVisible;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      attributeVisible
          ? CardAssets.portrait(person)
          : CardAssets.unknownPortrait(person.id),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF15131B)),
    );
    return dimmed
        ? ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0x88101015),
              BlendMode.darken,
            ),
            child: image,
          )
        : image;
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, .42, .72, 1],
        colors: [
          Color(0x22000000),
          Color(0x00000000),
          Color(0xC0090910),
          Color(0xF6070709),
        ],
      ),
    ),
  );
}

class _Corners extends StatelessWidget {
  const _Corners({
    required this.coordinate,
    required this.attributeVisible,
    required this.attribute,
    required this.viewerEyeKnown,
    required this.opponentEyeKnown,
    required this.viewerLabel,
    required this.opponentLabel,
    required this.confirmed,
    required this.accent,
  });

  final String coordinate;
  final bool attributeVisible;
  final PersonAttribute attribute;
  final bool viewerEyeKnown;
  final bool opponentEyeKnown;
  final String viewerLabel;
  final String opponentLabel;
  final bool confirmed;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge + coordinate chip: wrapped in FittedBox so this group scales
        // down as a whole instead of ever hard-overflowing, no matter how
        // narrow the card gets (down to the smallest supported phone width).
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AssetBadge(
                  asset: attributeVisible
                      ? CardAssets.attributeBadge(attribute)
                      : CardAssets.unknownBadge,
                  badgeKey: Key(
                    attributeVisible
                        ? 'attribute-icon-${attribute.name}'
                        : 'attribute-icon-hidden',
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: accent.withValues(alpha: .6)),
                  ),
                  child: Text(
                    coordinate,
                    key: Key('coordinate-$coordinate'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFEAD9A4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (!confirmed && (viewerEyeKnown || opponentEyeKnown))
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (viewerEyeKnown)
                    _EyeMark(label: viewerLabel, color: AppTheme.eye),
                  if (opponentEyeKnown)
                    _EyeMark(label: opponentLabel, color: AppTheme.executor),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// EYE marker: the sliced eye badge tagged with who has seen the attribute
/// (`YOU` / `CPU`, or the faction name in hotseat).
class _EyeMark extends StatelessWidget {
  const _EyeMark({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withValues(alpha: .8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.asset(
            CardAssets.eyeBadge,
            width: 12,
            height: 12,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                Icon(Icons.visibility, size: 10, color: color),
          ),
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 7,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AssetBadge extends StatelessWidget {
  const _AssetBadge({required this.asset, this.badgeKey});

  final String asset;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 22,
    child: ClipOval(
      child: Image.asset(
        asset,
        key: badgeKey,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.person,
    required this.attributeVisible,
    required this.accent,
    required this.selected,
    required this.compact,
    required this.scoreDetail,
  });

  final PersonCard person;
  final bool attributeVisible;
  final Color accent;
  final bool selected;
  final bool compact;
  final ({Faction faction, int points})? scoreDetail;

  @override
  Widget build(BuildContext context) {
    final confirmed = person.isConfirmed;
    final deliberating = person.verdictState == VerdictState.deliberating;
    // Priority order for a still-undecided card is attribute > portrait >
    // history > "審議中": every unconfirmed card used to shout "審議中" at the
    // same weight as a real verdict, so it's shrunk and muted here instead of
    // competing with the more useful information above and below it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            attributeVisible ? person.attribute.label : '正体不明',
            key: Key(attributeVisible ? 'attribute-known' : 'attribute-hidden'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: attributeVisible
                  ? _attributeColor(person.attribute)
                  : const Color(0xFFCBC3B4),
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  person.verdictState.label,
                  key: Key('verdict-${person.verdictState.name}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: deliberating
                        ? _stateColor(person.verdictState).withValues(alpha: .6)
                        : _stateColor(person.verdictState),
                    fontSize: confirmed
                        ? (compact ? 9 : 12)
                        : (compact ? 7 : 9),
                    fontWeight: deliberating
                        ? FontWeight.w600
                        : FontWeight.w900,
                  ),
                ),
              ),
              if (confirmed) ...[
                const SizedBox(width: 2),
                Icon(
                  person.isAlive ? Icons.check_circle : Icons.cancel,
                  key: const Key('confirmed-label'),
                  size: compact ? 11 : 14,
                  color: accent,
                ),
                const SizedBox(width: 2),
                Text(
                  person.isAlive ? 'ALIVE' : 'DEAD',
                  style: TextStyle(
                    color: accent,
                    fontSize: compact ? 8 : 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          _HistoryPips(history: person.verdictHistory),
          if (scoreDetail case final detail?)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '${detail.faction.label} +${detail.points}',
                maxLines: 1,
                style: const TextStyle(fontSize: 7, color: Color(0xFFE7DBC0)),
              ),
            )
          else if (selected)
            const Text(
              '選択中',
              key: Key('selected-label'),
              style: TextStyle(
                color: Color(0xFFFFD76A),
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryPips extends StatelessWidget {
  const _HistoryPips({required this.history});
  final List<VerdictActionType> history;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < 3; i++)
        _Pip(action: i < history.length ? history[i] : null, index: i),
    ],
  );
}

class _Pip extends StatelessWidget {
  const _Pip({required this.action, required this.index});
  final VerdictActionType? action;
  final int index;

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
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: action == null ? Colors.black26 : color.withValues(alpha: .22),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
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
