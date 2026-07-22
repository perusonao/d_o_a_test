import 'package:go_router/go_router.dart';

import '../features/faction_select/faction_select_screen.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/result/result_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/title/title_screen.dart';

/// 画面遷移の定義。go_router を使用する。
class AppRoutes {
  AppRoutes._();
  static const String title = '/';
  static const String factionSelect = '/faction';
  static const String game = '/game';
  static const String result = '/result';
  static const String rules = '/rules';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.title,
  routes: [
    GoRoute(
      path: AppRoutes.title,
      builder: (context, state) => const TitleScreen(),
    ),
    GoRoute(
      path: AppRoutes.factionSelect,
      builder: (context, state) => const FactionSelectScreen(),
    ),
    GoRoute(
      path: AppRoutes.game,
      builder: (context, state) => const GameScreen(),
    ),
    GoRoute(
      path: AppRoutes.result,
      builder: (context, state) => const ResultScreen(),
    ),
    GoRoute(
      path: AppRoutes.rules,
      builder: (context, state) => const RulesScreen(),
    ),
  ],
);
