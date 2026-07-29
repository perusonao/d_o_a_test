import 'package:dead_or_alive/app/app.dart';
import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_screen.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/screens/demo_showcase_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Section: PWA entry points for /nine-verdicts/showcase/ and
/// /nine-verdicts/admin/ redirect into `#/showcase` / `#/admin` — this only
/// works if those named routes actually resolve to the right screens, and
/// (new) `/admins` — the plural spelling used in the PWA request — resolves
/// to the same AdminScreen as `/admin` rather than silently falling through
/// to the game via onUnknownRoute.
///
/// Route→widget mappings are checked by calling each route's WidgetBuilder
/// directly (never pumped into the tree), rather than navigating and
/// letting the real screen mount — DemoShowcaseScreen in particular always
/// schedules a real, looping chain of multi-second Future.delayed timers on
/// mount (by design, for screen recording), which a widget test could never
/// cleanly drain.
void main() {
  testWidgets('/ は通常のゲーム画面を表示する', (tester) async {
    await tester.pumpWidget(const NineVerdictsApp());
    expect(find.byType(NineJudgesGameScreen), findsOneWidget);
  });

  testWidgets('ルートテーブルの解決先が正しい', (tester) async {
    await tester.pumpWidget(const NineVerdictsApp());
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(MaterialApp));
    final routes = materialApp.routes!;

    expect(routes['/']!(context), isA<NineJudgesGameScreen>());
    expect(routes['/showcase']!(context), isA<DemoShowcaseScreen>());
    expect(routes['/admin']!(context), isA<AdminScreen>());
    // Plural alias — the PWA request's own wording — must resolve to the
    // same screen as the canonical singular route.
    expect(routes['/admins']!(context), isA<AdminScreen>());

    expect(materialApp.onUnknownRoute, isNotNull);
  });
}
