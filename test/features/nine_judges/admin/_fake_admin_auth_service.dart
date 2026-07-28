import 'dart:async';

import 'package:dead_or_alive/features/nine_judges/admin/services/admin_auth_service.dart';

/// A fake [AdminAuthService] that never touches Firebase — lets the admin
/// auth/permission state machine (section 3/21) and gate screens be tested
/// without a live/mocked FirebaseAuth platform channel. All of
/// [AdminAuthService]'s methods are overridable.
class FakeAdminAuthService implements AdminAuthService {
  final _authStateController = StreamController<AdminIdentity?>.broadcast();
  AdminIdentity? _currentUser;
  final Map<String, bool> adminDocs = {};

  Object? signInError;
  Object? isAdminError;
  Object? initialStreamError;

  @override
  Future<Stream<AdminIdentity?>> authStateChanges() async {
    if (initialStreamError != null) {
      // Mirrors a real Firebase initialization failure (section 21): the
      // stream is never obtained at all, caught synchronously by the
      // caller's own try/catch — not an error event on an otherwise-working
      // stream.
      throw initialStreamError!;
    }
    return _authStateController.stream;
  }

  @override
  Future<AdminIdentity?> currentUser() async => _currentUser;

  @override
  Future<AdminIdentity> signInWithGoogle() async {
    if (signInError != null) throw signInError!;
    final identity = const AdminIdentity(uid: 'google-uid-1', email: 'admin@example.com');
    _currentUser = identity;
    _authStateController.add(identity);
    return identity;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<bool> isAdmin(String uid) async {
    if (isAdminError != null) throw isAdminError!;
    return adminDocs[uid] ?? false;
  }

  void signInAs(String uid, {String? email}) {
    final identity = AdminIdentity(uid: uid, email: email);
    _currentUser = identity;
    _authStateController.add(identity);
  }
}
