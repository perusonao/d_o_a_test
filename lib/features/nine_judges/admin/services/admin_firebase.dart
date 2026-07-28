import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// A secondary, named Firebase App/Auth/Firestore stack used ONLY by the
/// admin dashboard, completely separate from the default app
/// [FirebaseBootstrap] uses for the regular player's anonymous session (see
/// services/firebase_bootstrap.dart). Firebase Auth only ever holds one
/// "current user" per app instance — by giving the admin flow its own named
/// app, signing in as Google here never signs the regular gameplay's
/// anonymous user out, and leaving the admin screen never requires
/// "regenerating" anonymous auth, because it was never touched.
abstract final class AdminFirebase {
  static const _appName = 'nine-verdicts-admin';

  static FirebaseApp? _app;

  /// Set when [_ensureApp] most recently failed, so the UI can show a clear
  /// "Firebase初期化に失敗しました" state instead of crashing.
  static String? initError;

  static Future<FirebaseApp> _ensureApp() async {
    final existing = _app;
    if (existing != null) return existing;
    final alreadyRegistered = Firebase.apps.where((a) => a.name == _appName);
    if (alreadyRegistered.isNotEmpty) {
      _app = alreadyRegistered.first;
      initError = null;
      return alreadyRegistered.first;
    }
    try {
      final app = await Firebase.initializeApp(
        name: _appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _app = app;
      initError = null;
      return app;
    } catch (exception) {
      initError = exception.toString();
      rethrow;
    }
  }

  static Future<FirebaseAuth> auth() async =>
      FirebaseAuth.instanceFor(app: await _ensureApp());

  static Future<FirebaseFirestore> firestore() async =>
      FirebaseFirestore.instanceFor(app: await _ensureApp());

  /// projectId to display in the admin "設定" tab (section 5/21).
  static String get projectId => DefaultFirebaseOptions.web.projectId;
}
