import 'package:go_router/go_router.dart';

import '../features/game/presentation/game_screen.dart';
import '../features/result/result_screen.dart';
import '../features/title/title_screen.dart';

/// 画面遷移の定義（Ver.0.4：タイトル / ゲーム / リザルトのみ）。
class AppRoutes {
  AppRoutes._();
  static const String title = '/';
  static const String game = '/game';
  static const String result = '/result';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.title,
  routes: [
    GoRoute(
      path: AppRoutes.title,
      builder: (context, state) => const TitleScreen(),
    ),
    GoRoute(
      path: AppRoutes.game,
      builder: (context, state) => const GameScreen(),
    ),
    GoRoute(
      path: AppRoutes.result,
      builder: (context, state) => const ResultScreen(),
    ),
  ],
);
