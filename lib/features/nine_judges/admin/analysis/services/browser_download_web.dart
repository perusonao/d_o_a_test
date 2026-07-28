// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Real Flutter Web implementation of the "Markdownをダウンロード"/
/// "JSONをダウンロード" buttons (section 6/7): builds a `Blob` URL and
/// triggers a browser download via a transient anchor element. Only ever
/// compiled in when `dart:html` is available (see browser_download.dart's
/// conditional export) — `flutter test` (Dart VM) uses
/// browser_download_stub.dart instead.
void downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) {
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
