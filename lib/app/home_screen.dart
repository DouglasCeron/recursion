import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/inventory/application/inventory_controller.dart';
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
                    Navigator.of(context).pushNamed(AppRoutes.battle),
                child: const Text('Start battle'),
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
            ],
          ),
        ),
      ),
    );
  }
}
