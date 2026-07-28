import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_record.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

export 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_record.dart';

abstract interface class TutorialEventRepository {
  Future<void> record(TutorialEventRecord event);
  Future<List<TutorialEventRecord>> listEvents();
}

class LocalTutorialEventRepository implements TutorialEventRepository {
  LocalTutorialEventRepository._();

  static final LocalTutorialEventRepository instance =
      LocalTutorialEventRepository._();
  static const _boxName = 'nine_judges_tutorial_events_v01';
  Box<dynamic>? _box;

  Future<Box<dynamic>> _open() async {
    if (_box case final box?) return box;
    await Hive.initFlutter();
    return _box = await Hive.openBox<dynamic>(_boxName);
  }

  @override
  Future<void> record(TutorialEventRecord event) async {
    final box = await _open();
    await box.add(event.toJson());
  }

  @override
  Future<List<TutorialEventRecord>> listEvents() async {
    final box = await _open();
    return box.values
        .map(
          (value) => TutorialEventRecord.fromJson(
            (value as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }
}

class MemoryTutorialEventRepository implements TutorialEventRepository {
  final List<TutorialEventRecord> events = [];

  @override
  Future<void> record(TutorialEventRecord event) async => events.add(event);

  @override
  Future<List<TutorialEventRecord>> listEvents() async =>
      List.unmodifiable(events);
}
