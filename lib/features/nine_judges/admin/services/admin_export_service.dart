import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';

/// Section 19: JSON export of currently-loaded game logs, in the same shape
/// [GameSession.fromJson]/`tool/run_external_test_analysis.dart` expect (a
/// JSON array of `session.toJson()`-shaped objects), plus `firebaseUid` and
/// `createdAt` and, for any record whose detail view was already opened,
/// its `actions`. Never force-fetches all Firestore data — only exports
/// what the admin has already loaded in this session (section 19).
abstract final class AdminExportService {
  static String fileName(DateTime now) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return 'nine_verdicts_external_test_'
        '${now.year}-${pad(now.month)}-${pad(now.day)}.json';
  }

  static String buildJson(List<PlaytestRecord> records) {
    final payload = records.map((record) {
      final json = record.session.toJson();
      json['firebaseUid'] = record.firebaseUid;
      json['createdAt'] = record.createdAt?.toIso8601String();
      if (record.actions != null) {
        json['actions'] = record.actions!.map((a) => a.toJson()).toList();
      }
      return json;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// e.g. "現在20件を出力します。actions未取得のゲームは3件あります(actionsを含みません)。"
  static String warningMessage(List<PlaytestRecord> records) {
    final withoutActions = records.where((r) => r.actions == null).length;
    final buffer = StringBuffer('現在${records.length}件を出力します。');
    if (withoutActions > 0) {
      buffer.write('actions未取得のゲームが$withoutActions件あります(actionsを含みません)。');
    }
    return buffer.toString();
  }
}
