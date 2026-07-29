import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_screen.dart';
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
      // '/admin' and '/showcase' are hidden routes reachable only by typing
      // the URL directly (see lib/features/nine_judges/admin/ and
      // lib/features/nine_judges/showcase/) — no normal player screen links
      // to either. Everything else (including an unrecognized route on
      // reload) falls back to the regular game, matching the previous
      // `home:`-only behavior exactly.
      //
      // '/admins' is a plural alias for '/admin' — kept in sync so either
      // spelling reaches the same AdminScreen (and its unchanged internal
      // Firebase auth/`admins/{uid}` gate); it exists only so both spellings
      // resolve to a real route instead of silently falling through to the
      // game via onUnknownRoute.
      routes: {
        '/': (context) => const NineJudgesGameScreen(),
        '/admin': (context) => const AdminScreen(),
        '/admins': (context) => const AdminScreen(),
        '/showcase': (context) => const DemoShowcaseScreen(),
      },
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (context) => const NineJudgesGameScreen()),
    );
  }
}

@Deprecated('Use NineVerdictsApp. Kept to avoid breaking existing tests.')
typedef DeadOrAliveApp = NineVerdictsApp;
