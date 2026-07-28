/// One onboarding-measurement event: tutorial start/step/complete/skip, or
/// rules-guide open/close. Kept as its own small log (separate from
/// [GameSession]) since it can happen with no game in progress at all.
///
/// Deliberately Hive-free (unlike tutorial_event_log.dart's repository
/// classes) so command-line tools — which run on the bare Dart VM, not
/// through Flutter's build pipeline — can import this shape without pulling
/// in a Flutter-plugin dependency the standalone VM can't compile.
class TutorialEventRecord {
  const TutorialEventRecord({
    required this.type,
    required this.sessionId,
    required this.testerId,
    required this.timestamp,
    this.step,
    this.rulesReadDurationMs,
  });

  /// One of: tutorialStarted, tutorialStepReached, tutorialCompleted,
  /// tutorialSkipped, rulesOpened, rulesClosed.
  final String type;
  final String sessionId;
  final String? testerId;
  final DateTime timestamp;

  /// 1-based tutorial step (1..11) for tutorial* events; null otherwise.
  final int? step;

  /// Only set on rulesClosed. Simple wall-clock duration — not corrected for
  /// e.g. a backgrounded browser tab.
  final int? rulesReadDurationMs;

  Map<String, dynamic> toJson() => {
    'type': type,
    'sessionId': sessionId,
    'testerId': testerId,
    'timestamp': timestamp.toIso8601String(),
    'step': step,
    'rulesReadDurationMs': rulesReadDurationMs,
  };

  factory TutorialEventRecord.fromJson(Map<String, dynamic> json) =>
      TutorialEventRecord(
        type: json['type'] as String,
        sessionId: json['sessionId'] as String,
        testerId: json['testerId'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        step: json['step'] as int?,
        rulesReadDurationMs: json['rulesReadDurationMs'] as int?,
      );
}
