/// Named beats the recruitment-video showcase (see
/// screens/demo_showcase_screen.dart) fires through as it auto-plays, so a
/// future video edit can hang BGM/SE cues off these without touching Dart
/// code again — no actual audio is wired up here, only the event names
/// (section 10 of the showcase request).
enum ShowcaseEvent {
  titleShown,
  catchCopyShown,
  cardsPlaced,
  eyeUsed,
  judgeUsed,
  reversalUsed,
  scoreAwarded,
  victory,
  defeat,
  ratingShown,
  recruitmentShown,
}
