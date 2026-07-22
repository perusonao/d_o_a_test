import 'package:dead_or_alive/app/app.dart';
import 'package:dead_or_alive/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // グローバルな GoRouter はテスト間で状態を保持するため、毎回タイトルへ戻す。
  setUp(() => appRouter.go(AppRoutes.title));

  testWidgets('タイトル→役割選択→ゲーム画面に入れる', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DeadOrAliveApp()));
    await tester.pumpAndSettle();

    expect(find.text('DEAD OR ALIVE'), findsOneWidget);
    await tester.tap(find.text('ゲーム開始'));
    await tester.pumpAndSettle();

    expect(find.text('救済者'), findsOneWidget);
    expect(find.text('執行者'), findsOneWidget);

    // 救済者=先手なので、選ぶと即プレイヤーのターン。
    await tester.tap(find.text('救済者'));
    await tester.pumpAndSettle();

    expect(find.text('決定'), findsOneWidget);
  });
}
