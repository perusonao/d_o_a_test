import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The admin dashboard's minimal view of a signed-in user — deliberately
/// not `firebase_auth`'s `User` (which is awkward to construct in tests and
/// carries far more than this screen needs), so
/// [AdminSessionController]/screens can be tested without a live/mocked
/// FirebaseAuth platform channel.
class AdminIdentity {
  const AdminIdentity({required this.uid, required this.email});
  final String uid;
  final String? email;
}

/// Google Sign-In + `admins/{uid}` permission check for the admin dashboard.
///
/// Deliberately does NOT reuse [FirebaseBootstrap]'s anonymous auth: admin
/// determination must come from a real Google-authenticated Firebase Auth
/// user, never from comparing an email string client-side, and never from
/// the anonymous uid regular players sign in with (see
/// services/firebase_bootstrap.dart). The actual access-control enforcement
/// lives in firestore.rules' `isAdmin()`; the check here only drives what
/// the UI shows and avoids issuing reads that would be denied anyway.
class AdminAuthService {
  AdminAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  Future<FirebaseAuth> get _auth async =>
      _authOverride ?? await AdminFirebase.auth();
  Future<FirebaseFirestore> get _firestore async =>
      _firestoreOverride ?? await AdminFirebase.firestore();

  static AdminIdentity? _toIdentity(User? user) =>
      user == null ? null : AdminIdentity(uid: user.uid, email: user.email);

  Future<Stream<AdminIdentity?>> authStateChanges() async =>
      (await _auth).authStateChanges().map(_toIdentity);

  Future<AdminIdentity?> currentUser() async =>
      _toIdentity((await _auth).currentUser);

  Future<AdminIdentity> signInWithGoogle() async {
    final auth = await _auth;
    final credential = await auth.signInWithPopup(GoogleAuthProvider());
    final identity = _toIdentity(credential.user);
    if (identity == null) {
      throw StateError('Googleログインに失敗しました(ユーザー情報を取得できません)');
    }
    return identity;
  }

  Future<void> signOut() async => (await _auth).signOut();

  /// True iff `admins/{uid}` exists and `enabled == true` (section 3). This
  /// is a UI-convenience check only — firestore.rules' `isAdmin()` is the
  /// real gate on every read.
  Future<bool> isAdmin(String uid) async {
    final firestore = await _firestore;
    final doc = await firestore.collection('admins').doc(uid).get();
    if (!doc.exists) return false;
    return doc.data()?['enabled'] == true;
  }
}
