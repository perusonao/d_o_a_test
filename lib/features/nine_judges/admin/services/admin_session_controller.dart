import 'dart:async';

import 'package:dead_or_alive/features/nine_judges/admin/services/admin_auth_service.dart';
import 'package:flutter/foundation.dart';

/// Every state the admin gate (section 3/21) must distinguish. Each maps to
/// exactly one required Japanese message in the UI — see
/// screens/admin_screen.dart.
enum AdminSessionStatus {
  initializing,
  initFailed,
  signedOut,
  googleSignInFailed,
  checkingAdmin,
  notAdmin,
  adminCheckFailed,
  admin,
}

/// Drives the admin login/permission gate. Never fetches playtest data
/// itself — [AdminSessionStatus.admin] is only reached after a real
/// Google-authenticated user is confirmed present in `admins/{uid}` with
/// `enabled == true` (section 3). The actual enforcement is firestore.rules'
/// `isAdmin()`; this controller only decides what the UI shows and avoids
/// issuing reads that rules would reject anyway.
class AdminSessionController extends ChangeNotifier {
  AdminSessionController({AdminAuthService? authService})
    : _authService = authService ?? AdminAuthService();

  final AdminAuthService _authService;
  StreamSubscription<AdminIdentity?>? _authSubscription;

  AdminSessionStatus status = AdminSessionStatus.initializing;
  AdminIdentity? user;
  String? errorDetail;
  bool signingIn = false;

  Future<void> initialize() async {
    try {
      final stream = await _authService.authStateChanges();
      _authSubscription?.cancel();
      _authSubscription = stream.listen(_onAuthChanged, onError: (Object e) {
        status = AdminSessionStatus.initFailed;
        errorDetail = e.toString();
        notifyListeners();
      });
      user = await _authService.currentUser();
      if (user == null) {
        status = AdminSessionStatus.signedOut;
        notifyListeners();
      } else {
        await _checkAdmin();
      }
    } catch (exception) {
      status = AdminSessionStatus.initFailed;
      errorDetail = exception.toString();
      notifyListeners();
    }
  }

  Future<void> _onAuthChanged(AdminIdentity? nextUser) async {
    user = nextUser;
    if (nextUser == null) {
      status = AdminSessionStatus.signedOut;
      notifyListeners();
      return;
    }
    await _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    status = AdminSessionStatus.checkingAdmin;
    notifyListeners();
    try {
      final isAdmin = await _authService.isAdmin(user!.uid);
      status = isAdmin ? AdminSessionStatus.admin : AdminSessionStatus.notAdmin;
      errorDetail = null;
    } catch (exception) {
      status = AdminSessionStatus.adminCheckFailed;
      errorDetail = exception.toString();
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    signingIn = true;
    notifyListeners();
    try {
      user = await _authService.signInWithGoogle();
      signingIn = false;
      // Drive the admin check directly rather than waiting on whatever
      // order the authStateChanges listener happens to fire in — that
      // listener still runs too (harmless/idempotent) since real auth
      // providers deliver it asynchronously.
      await _checkAdmin();
      return;
    } catch (exception) {
      status = AdminSessionStatus.googleSignInFailed;
      errorDetail = exception.toString();
    }
    signingIn = false;
    notifyListeners();
  }

  /// Re-runs the `admins/{uid}` check without a full sign-out/sign-in — used
  /// by the header's refresh button and by retry actions on failure states.
  Future<void> retry() async {
    if (user != null) {
      await _checkAdmin();
    } else {
      await initialize();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    user = null;
    status = AdminSessionStatus.signedOut;
    errorDetail = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
