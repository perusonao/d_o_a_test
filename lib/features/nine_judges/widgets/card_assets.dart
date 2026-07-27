import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

/// Central registry that maps game concepts to the artwork sliced from the
/// board mockup. Keeping every asset path here means the card, action and
/// header widgets stay free of hard-coded file names.
abstract final class CardAssets {
  static const _characters = 'assets/characters';
  static const _icons = 'assets/icons';

  static const _portraitPools = <PersonAttribute, List<String>>{
    PersonAttribute.good: ['good_1', 'good_2'],
    PersonAttribute.evil: ['evil_1', 'evil_2'],
    PersonAttribute.neutral: ['neutral_1'],
  };
  static const _unknownPortraits = ['unknown_1', 'unknown_2', 'unknown_3'];

  /// A stable index derived from a person id (e.g. `good-2` -> 1) so the same
  /// person always shows the same face.
  static int _slotOf(String personId) {
    final dash = personId.lastIndexOf('-');
    final n = dash >= 0 ? int.tryParse(personId.substring(dash + 1)) : null;
    return (n ?? 1) - 1;
  }

  /// Portrait shown once the attribute is known/confirmed.
  static String portrait(PersonCard person) {
    final pool = _portraitPools[person.attribute]!;
    return '$_characters/${pool[_slotOf(person.id) % pool.length]}.png';
  }

  /// Hooded portrait used while the attribute is still secret.
  static String unknownPortrait(String personId) =>
      '$_characters/${_unknownPortraits[_slotOf(personId) % _unknownPortraits.length]}.png';

  static String attributeBadge(PersonAttribute attribute) => switch (attribute) {
    PersonAttribute.good => '$_icons/badge_good.png',
    PersonAttribute.evil => '$_icons/badge_evil.png',
    PersonAttribute.neutral => '$_icons/badge_neutral.png',
  };

  static const unknownBadge = '$_icons/badge_unknown.png';
  static const eyeBadge = '$_icons/badge_eye.png';

  static const crestSavior = '$_icons/crest_savior.png';
  static const crestExecutor = '$_icons/crest_executor.png';

  static String crest(Faction faction) =>
      faction == Faction.savior ? crestSavior : crestExecutor;

  static String actionIcon(ActionType action) => switch (action) {
    ActionType.life => '$_icons/act_life.png',
    ActionType.death => '$_icons/act_death.png',
    ActionType.eye => '$_icons/act_eye.png',
    ActionType.specialVerdict => '$_icons/act_judge.png',
  };

  static const reverseIcon = '$_icons/act_reverse.png';
}
