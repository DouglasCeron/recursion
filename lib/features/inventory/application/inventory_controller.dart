import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ship/domain/weapon_catalog.dart';
import '../../ship/domain/weapon_definition.dart';
import '../domain/inventory.dart';

class PlayerInventoryState {
  const PlayerInventoryState({required this.inventory, required this.loadout});

  factory PlayerInventoryState.starter() => PlayerInventoryState(
    inventory: Inventory.starter(),
    loadout: Loadout.starter(),
  );

  final Inventory inventory;
  final Loadout loadout;

  WeaponDefinition get equippedWeapon =>
      WeaponCatalog.byId(loadout.weaponId) ?? WeaponCatalog.blaster;

  List<WeaponDefinition> get ownedWeapons => [
    for (final weapon in WeaponCatalog.all)
      if (inventory.contains(weapon.id)) weapon,
  ];
}

/// State the inventory starts from; overridden with the restored save.
final initialInventoryStateProvider = Provider<PlayerInventoryState>(
  (ref) => PlayerInventoryState.starter(),
);

final inventoryControllerProvider =
    NotifierProvider<InventoryController, PlayerInventoryState>(
      InventoryController.new,
    );

/// Use cases for the player's items: collecting drops and equipping weapons.
class InventoryController extends Notifier<PlayerInventoryState> {
  @override
  PlayerInventoryState build() => ref.read(initialInventoryStateProvider);

  /// Adds a collected item. Returns false if it was already owned.
  bool collect(String itemId) {
    final inventory = state.inventory.add(itemId);
    if (identical(inventory, state.inventory)) return false;
    state = PlayerInventoryState(inventory: inventory, loadout: state.loadout);
    return true;
  }

  /// Equips an owned weapon. Returns false if the weapon cannot be equipped.
  bool equipWeapon(String weaponId) {
    final loadout = state.loadout.equipWeapon(
      weaponId,
      inventory: state.inventory,
    );
    if (loadout == null) return false;
    state = PlayerInventoryState(inventory: state.inventory, loadout: loadout);
    return true;
  }
}
