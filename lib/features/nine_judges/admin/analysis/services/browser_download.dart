/// Conditional export: `dart:html` (browser_download_web.dart) only exists
/// when compiled for Flutter Web; `flutter test` (Dart VM) falls back to the
/// no-op stub. Never guard this with a runtime `kIsWeb` check instead — an
/// unconditional `import 'dart:html'` would fail to even *compile* under
/// `flutter test`.
library;

export 'browser_download_stub.dart'
    if (dart.library.html) 'browser_download_web.dart';
