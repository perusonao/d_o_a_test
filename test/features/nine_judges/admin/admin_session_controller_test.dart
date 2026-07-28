import 'package:dead_or_alive/features/nine_judges/admin/services/admin_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fake_admin_auth_service.dart';

void main() {
  group('AdminSessionController', () {
    test('未ログイン状態ではsignedOutになり、管理者チェックを行わない', () async {
      final fake = FakeAdminAuthService();
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.signedOut);
      expect(controller.user, isNull);
    });

    test('ログイン済みかつadmins/{uid}が存在し有効ならadminになる', () async {
      final fake = FakeAdminAuthService()..adminDocs['uid-1'] = true;
      fake.signInAs('uid-1', email: 'a@example.com');
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.admin);
      expect(controller.user?.uid, 'uid-1');
    });

    test('admins/{uid}が存在しない場合はnotAdminになりplaytestデータを扱わない', () async {
      final fake = FakeAdminAuthService();
      fake.signInAs('uid-2');
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.notAdmin);
    });

    test('admins/{uid}のenabled=falseはnotAdmin扱い', () async {
      final fake = FakeAdminAuthService()..adminDocs['uid-3'] = false;
      fake.signInAs('uid-3');
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.notAdmin);
    });

    test('管理者チェック中にエラーが発生した場合はadminCheckFailedになる', () async {
      final fake = FakeAdminAuthService()..isAdminError = Exception('permission-denied');
      fake.signInAs('uid-4');
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.adminCheckFailed);
      expect(controller.errorDetail, isNotNull);
    });

    test('Googleログイン失敗時はgoogleSignInFailedになる', () async {
      final fake = FakeAdminAuthService()..signInError = Exception('popup-closed-by-user');
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.signedOut);
      await controller.signIn();
      expect(controller.status, AdminSessionStatus.googleSignInFailed);
      expect(controller.signingIn, isFalse);
    });

    test('サインイン成功後は自動的に管理者チェックへ遷移する', () async {
      final fake = FakeAdminAuthService()..adminDocs['google-uid-1'] = true;
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.signedOut);
      await controller.signIn();
      expect(controller.status, AdminSessionStatus.admin);
    });

    test('ログアウトするとsignedOutへ戻る', () async {
      final fake = FakeAdminAuthService()..adminDocs['uid-1'] = true;
      fake.signInAs('uid-1');
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.admin);
      await controller.signOut();
      expect(controller.status, AdminSessionStatus.signedOut);
      expect(controller.user, isNull);
    });

    test('Firebase初期化(authStateChanges取得)に失敗した場合はinitFailedになる', () async {
      final fake = FakeAdminAuthService()..initialStreamError = Exception('network-error');
      final controller = AdminSessionController(authService: fake);
      await controller.initialize();
      expect(controller.status, AdminSessionStatus.initFailed);
    });
  });
}
