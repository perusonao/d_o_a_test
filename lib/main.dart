import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/nine_judges/services/app_stats_repository.dart';
import 'features/nine_judges/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_recordVisit());
  runApp(const ProviderScope(child: NineVerdictsApp()));
}

/// One "site visit" per app load, regardless of which route it lands on
/// (home, admin, showcase, promo) — chained after Firebase init so it can
/// use the anonymous session, but never awaited before [runApp] so it can
/// never delay first paint.
Future<void> _recordVisit() async {
  await FirebaseBootstrap.initialize();
  await const AppStatsRepository().recordVisit();
}
