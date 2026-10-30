import 'package:flutter/material.dart';

import '../features/combat/presentation/battle_screen.dart';
import 'home_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const battle = '/battle';
}

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRoutes.battle => const BattleScreen(),
      _ => const HomeScreen(),
    };
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }
}
