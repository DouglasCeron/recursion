import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/boss_evolution/application/boss_intel_controller.dart';
import '../features/boss_evolution/domain/boss_evolution.dart';
import '../features/boss_evolution/domain/boss_intel.dart';
import '../features/combat/domain/content/boss_catalog.dart';
import '../features/inventory/application/inventory_controller.dart';
import '../features/progression/application/progress_controller.dart';
import 'router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final weapon = ref.watch(inventoryControllerProvider).equippedWeapon;
    final progress = ref.watch(progressControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RECURSION',
                style: textTheme.displaySmall?.copyWith(letterSpacing: 6),
              ),
              const SizedBox(height: 8),
              Text('Prototype', style: textTheme.bodyMedium),
              const SizedBox(height: 40),
              for (final boss in BossCatalog.all) ...[
                FilledButton(
                  onPressed: progress.isBossUnlocked(boss.id)
                      ? () => Navigator.of(context).pushNamed(
                          AdaptationRules.adaptiveBossIds.contains(boss.id)
                              ? AppRoutes.briefing
                              : AppRoutes.battle,
                          arguments: boss.id,
                        )
                      : null,
                  child: Text(
                    progress.isBossUnlocked(boss.id)
                        ? 'Fight ${boss.name}'
                        : '${boss.name} — fight the Sentinel first',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.inventory),
                child: const Text('Inventory'),
              ),
              const SizedBox(height: 16),
              Text(
                'Equipped: ${weapon.name}',
                style: textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 4),
              Text(
                _intelSummary(ref.watch(bossIntelControllerProvider)),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFB39DDB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _intelSummary(BossIntel intel) {
    final latest = intel.latest;
    if (latest == null) return 'Enemy intel: none';
    final weapons = latest.profile.weapons.values
        .map((w) => '${w.type.name} (${w.level.name})')
        .join(', ');
    return 'Enemy intel: ${intel.reports.length} report(s)'
        '${weapons.isEmpty ? '' : '\nLatest: $weapons'}';
  }
}
