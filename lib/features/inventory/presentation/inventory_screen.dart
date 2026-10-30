import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ship/domain/weapon_definition.dart';
import '../application/inventory_controller.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryControllerProvider);
    final equippedId = state.loadout.weaponId;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Weapons — tap to equip'),
          ),
          for (final weapon in state.ownedWeapons)
            ListTile(
              title: Text(weapon.name),
              subtitle: Text(_stats(weapon)),
              trailing: weapon.id == equippedId
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () => ref
                  .read(inventoryControllerProvider.notifier)
                  .equipWeapon(weapon.id),
            ),
        ],
      ),
    );
  }

  static String _stats(WeaponDefinition weapon) {
    final rate = (1 / weapon.fireInterval).toStringAsFixed(1);
    return 'Damage ${weapon.damage}  •  $rate shots/s';
  }
}
