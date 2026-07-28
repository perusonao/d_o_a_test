import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
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
      // '/admin' is an admin-only route reachable only by typing the URL
      // directly (see lib/features/nine_judges/admin/) — no normal player
      // screen links to it. Everything else (including an unrecognized
      // route on reload) falls back to the regular game, matching the
      // previous `home:`-only behavior exactly.
      routes: {
        '/': (context) => const NineJudgesGameScreen(),
        '/admin': (context) => const AdminScreen(),
      },
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (context) => const NineJudgesGameScreen()),
    );
  }
}

@Deprecated('Use NineVerdictsApp. Kept to avoid breaking existing tests.')
typedef DeadOrAliveApp = NineVerdictsApp;
