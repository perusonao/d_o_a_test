import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_settings_tab.dart';
import 'package:dead_or_alive/features/nine_judges/promo/screens/promo_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('「🎬 プロモーション動画」ボタンがPromoPlayerScreenを開く', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminSettingsTab(
          userEmail: 'admin@example.com',
          projectId: 'test-project',
          lastUpdated: null,
          loadedCount: 0,
        ),
        routes: {'/promo': (_) => const PromoPlayerScreen()},
      ),
    );

    final button = find.byKey(const Key('admin-open-promo'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(PromoPlayerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
