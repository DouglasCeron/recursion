import 'package:flutter/material.dart';

import '../features/boss_evolution/domain/boss_evolution.dart';
import '../features/boss_evolution/presentation/briefing_screen.dart';
import '../features/combat/domain/content/boss_catalog.dart';
import '../features/combat/presentation/battle_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/progression/presentation/campaign_map_screen.dart';
import 'home_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const campaign = '/campaign';

  /// Arguments: the boss id (defaults to the first boss).
  static const battle = '/battle';

  /// Arguments: the boss id. Leads into [battle].
  static const briefing = '/briefing';
  static const inventory = '/inventory';
}

abstract final class AppRouter {
  /// Boss routes also accept `?boss=<id>`, so they can be opened directly
  /// with `flutter run --route`.
  static Route<void> onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? AppRoutes.home);
    final bossId =
        settings.arguments as String? ??
        uri.queryParameters['boss'] ??
        BossCatalog.sentinel.id;
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => switch (uri.path) {
        AppRoutes.campaign => CampaignMapScreen(
          onBossSelected: (id) => Navigator.of(context).pushNamed(
            AdaptationRules.adaptiveBossIds.contains(id)
                ? AppRoutes.briefing
                : AppRoutes.battle,
            arguments: id,
          ),
        ),
        AppRoutes.battle => BattleScreen(bossId: bossId),
        AppRoutes.briefing => BriefingScreen(
          bossId: bossId,
          onLaunch: () => Navigator.of(
            context,
          ).pushReplacementNamed(AppRoutes.battle, arguments: bossId),
        ),
        AppRoutes.inventory => const InventoryScreen(),
        _ => const HomeScreen(),
      },
    );
  }
}
