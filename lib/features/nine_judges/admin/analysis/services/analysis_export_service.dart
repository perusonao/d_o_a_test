import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_report.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/analysis_markdown_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/browser_download.dart';
import 'package:flutter/services.dart';

/// Section 7/9/10: clipboard copy + file download for the generated
/// [AnalysisReport] — everything happens on-device (see
/// AdminAnalysisScreen's "この端末内で生成されます" notice); nothing here
/// ever calls an external API.
abstract final class AnalysisExportService {
  static String jsonFileName(DateTime now) =>
      'nine_verdicts_analysis_report_${_datePart(now)}.json';

  static String markdownFileName(DateTime now) =>
      'nine_verdicts_analysis_report_${_datePart(now)}.md';

  static String _datePart(DateTime now) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${pad(now.month)}-${pad(now.day)}';
  }

  static String buildJson(AnalysisReport report) =>
      const JsonEncoder.withIndent('  ').convert(report.toJson());

  static String buildMarkdown(AnalysisReport report) => buildMarkdownReport(report);

  static Future<void> copyToClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  /// Throws if the current platform can't trigger a browser download (e.g.
  /// running under `flutter test`) — callers should catch this and fall
  /// back to "コピーをご利用ください" (section 15: distinguish "download
  /// failed" from other errors).
  static void downloadJson(AnalysisReport report) => downloadTextFile(
    filename: jsonFileName(DateTime.now()),
    content: buildJson(report),
    mimeType: 'application/json',
  );

  static void downloadMarkdown(AnalysisReport report) => downloadTextFile(
    filename: markdownFileName(DateTime.now()),
    content: buildMarkdown(report),
    mimeType: 'text/markdown',
  );
}
