import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_screen.dart';
import 'package:dead_or_alive/features/nine_judges/promo/screens/promo_player_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/screens/demo_showcase_screen.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class NineVerdictsApp extends StatelessWidget {
  const NineVerdictsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9人の審判 / Nine Verdicts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      initialRoute: '/',
      // '/admin', '/showcase' and '/promo' are hidden routes reachable only
      // by typing the URL directly (see lib/features/nine_judges/admin/,
      // lib/features/nine_judges/showcase/ and lib/features/nine_judges/
      // promo/) — no normal player screen links to any of them (the admin
      // dashboard's own "🎬 プロモーション動画" tile is the one exception,
      // per section2's launcher requirement). Everything else (including an
      // unrecognized route on reload) falls back to the regular game,
      // matching the previous `home:`-only behavior exactly.
      //
      // '/admins' is a plural alias for '/admin' — kept in sync so either
      // spelling reaches the same AdminScreen (and its unchanged internal
      // Firebase auth/`admins/{uid}` gate); it exists only so both spellings
      // resolve to a real route instead of silently falling through to the
      // game via onUnknownRoute.
      routes: {
        // autoStartTutorial: true — a brand-new player who has never
        // completed/skipped the tutorial is taken straight into it instead
        // of the mode-select menu (see game_screen.dart); every later
        // launch goes straight to the menu as before.
        '/': (context) =>
            const NineJudgesGameScreen(autoStartTutorial: true),
        '/admin': (context) => const AdminScreen(),
        '/admins': (context) => const AdminScreen(),
        '/showcase': (context) => const DemoShowcaseScreen(),
        '/promo': (context) => const PromoPlayerScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) =>
            const NineJudgesGameScreen(autoStartTutorial: true),
      ),
    );
  }
}

@Deprecated('Use NineVerdictsApp. Kept to avoid breaking existing tests.')
typedef DeadOrAliveApp = NineVerdictsApp;
