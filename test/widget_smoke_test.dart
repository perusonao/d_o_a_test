import 'package:dead_or_alive/app/app.dart';
import 'package:dead_or_alive/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // グローバルな GoRouter はテスト間で状態を保持するため、毎回タイトルへ戻す。
  setUp(() => appRouter.go(AppRoutes.title));

  testWidgets('タイトル画面が表示され、陣営選択へ遷移できる', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DeadOrAliveApp()),
    );
    await tester.pumpAndSettle();

    // タイトルが表示される。
    expect(find.text('DEAD OR ALIVE'), findsOneWidget);
    expect(find.text('ゲーム開始'), findsOneWidget);

    // ゲーム開始 -> 陣営選択画面。
    await tester.tap(find.text('ゲーム開始'));
    await tester.pumpAndSettle();

    expect(find.text('善人陣営'), findsOneWidget);
    expect(find.text('悪人陣営'), findsOneWidget);
  });

  testWidgets('陣営を選ぶとゲーム画面に入り、手札と場が並ぶ', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DeadOrAliveApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ゲーム開始'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('善人陣営'));
    await tester.pumpAndSettle();

    // ターン表示が出る（プレイヤー先攻）。
    expect(find.text('あなたのターン'), findsOneWidget);
    expect(find.text('あなたの場'), findsOneWidget);
    // 決定ボタンが存在する。
    expect(find.text('決定'), findsOneWidget);
  });
}
