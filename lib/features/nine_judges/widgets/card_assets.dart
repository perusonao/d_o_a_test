import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

/// Central registry that maps game concepts to the artwork sliced from the
/// board mockup. Keeping every asset path here means the card, action and
/// header widgets stay free of hard-coded file names.
abstract final class CardAssets {
  static const _persons = 'assets/images/persons';
  static const _icons = 'assets/icons';

  static const goodPortrait = '$_persons/good.png';
  static const evilPortrait = '$_persons/evil.png';
  static const neutralPortrait = '$_persons/neutral.png';
  static const concealedPortrait = '$_persons/unknown.png';

  /// Centralized so nine individual portraits can be introduced later without
  /// changing PersonCardWidget or any visibility rule.
  static String portrait(PersonCard person) => switch (person.attribute) {
    PersonAttribute.good => goodPortrait,
    PersonAttribute.evil => evilPortrait,
    PersonAttribute.neutral => neutralPortrait,
  };

  /// Every concealed person deliberately shares one neutral hooded portrait;
  /// no face, gender or true attribute can be inferred before knowledge exists.
  static String unknownPortrait(String personId) => concealedPortrait;

  static String attributeBadge(PersonAttribute attribute) =>
      switch (attribute) {
        PersonAttribute.good => '$_icons/badge_good.png',
        PersonAttribute.evil => '$_icons/badge_evil.png',
        PersonAttribute.neutral => '$_icons/badge_neutral.png',
      };

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
