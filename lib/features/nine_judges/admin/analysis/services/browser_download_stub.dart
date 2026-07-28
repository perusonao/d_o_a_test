/// No-op fallback used wherever `dart:html` isn't available (e.g. `flutter
/// test`, which runs on the Dart VM) — see browser_download.dart's
/// conditional export. Real Flutter Web builds use browser_download_web.dart
/// instead.
void downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) {
  throw UnsupportedError(
    'ファイルダウンロードはWeb版でのみ利用できます(filename=$filename)',
  );
}
