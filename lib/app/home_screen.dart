import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/boss_evolution/application/boss_intel_controller.dart';
import '../features/boss_evolution/domain/boss_intel.dart';
import '../features/inventory/application/inventory_controller.dart';
import '../features/save_game/application/save_game_providers.dart';
import 'router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final weapon = ref.watch(inventoryControllerProvider).equippedWeapon;
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
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.campaign),
                child: const Text('Campaign'),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => _confirmReset(context, ref),
                child: const Text(
                  'Reset progress',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'Your items, campaign progress and everything the enemy learned '
          'about you will be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) ref.read(resetGameProvider)();
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
