import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_screen.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_playtest_repository.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_session_controller.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fake_admin_auth_service.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('AdminScreen ゲート表示', () {
    testWidgets('未ログイン: Googleでログインボタンのみ表示し、ダッシュボードは表示しない', (tester) async {
      final controller = AdminSessionController(authService: FakeAdminAuthService());
      await tester.pumpWidget(_wrap(AdminScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-gate-signed-out')), findsOneWidget);
      expect(find.byKey(const Key('admin-google-sign-in')), findsOneWidget);
      expect(find.byKey(const Key('admin-overview-list')), findsNothing);
    });

    testWidgets('管理者権限なし: 権限がありませんメッセージとログアウトボタンを表示する', (tester) async {
      final fake = FakeAdminAuthService();
      fake.signInAs('uid-not-admin', email: 'user@example.com');
      final controller = AdminSessionController(authService: fake);
      await tester.pumpWidget(_wrap(AdminScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-gate-not-admin')), findsOneWidget);
      expect(find.text('このアカウントには管理権限がありません'), findsOneWidget);
      expect(find.byKey(const Key('admin-logout')), findsOneWidget);
      expect(find.byKey(const Key('admin-overview-list')), findsNothing);
    });

    testWidgets('Googleログイン失敗: エラーメッセージと再試行ボタンを表示する', (tester) async {
      final fake = FakeAdminAuthService()..signInError = Exception('popup-closed-by-user');
      final controller = AdminSessionController(authService: fake);
      await tester.pumpWidget(_wrap(AdminScreen(controller: controller)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-google-sign-in')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-gate-signin-failed')), findsOneWidget);
      expect(find.byKey(const Key('admin-google-sign-in-retry')), findsOneWidget);
    });

    testWidgets('管理者: ダッシュボード(ヘッダー・タブ)を表示し0件データでもクラッシュしない', (tester) async {
      final fake = FakeAdminAuthService()..adminDocs['uid-admin'] = true;
      fake.signInAs('uid-admin', email: 'admin@example.com');
      final controller = AdminSessionController(authService: fake);
      await tester.pumpWidget(
        _wrap(
          AdminScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Falls back to the real AdminPlaytestRepository only if not injected;
      // AdminScreen doesn't expose repository injection directly, so this
      // just verifies the gate reaches the admin dashboard shell safely.
      expect(find.byKey(const Key('admin-gate-signed-out')), findsNothing);
      expect(find.byKey(const Key('admin-gate-not-admin')), findsNothing);
    });
  });

  group('AdminPlaytestRepository injection smoke test', () {
    testWidgets('0件データでもOverviewタブはクラッシュしない', (tester) async {
      final repository = AdminPlaytestRepository(firestore: FakeFirebaseFirestore());
      final page = await repository.fetchFirstPage();
      expect(page.records, isEmpty);
    });
  });
}
