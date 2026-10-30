import '../../ship/domain/weapon_catalog.dart';

/// Items the player has actually acquired. Item ids are stable content ids
/// (currently weapon ids), so the inventory never stores item definitions.
class Inventory {
  Inventory(Iterable<String> itemIds) : _itemIds = Set.unmodifiable(itemIds);

  factory Inventory.starter() => Inventory([WeaponCatalog.blaster.id]);

  final Set<String> _itemIds;

  Set<String> get itemIds => _itemIds;
  bool contains(String itemId) => _itemIds.contains(itemId);

  /// Returns an inventory that also holds [itemId]. Adding an item that is
  /// already owned returns the same inventory.
  Inventory add(String itemId) =>
      contains(itemId) ? this : Inventory({..._itemIds, itemId});
}

/// The subset of the inventory currently equipped on the ship.
class Loadout {
  const Loadout({required this.weaponId});

  factory Loadout.starter() => Loadout(weaponId: WeaponCatalog.blaster.id);

  final String weaponId;

  /// Equips [weaponId] if it is a known weapon the player owns; otherwise
  /// returns null and the current loadout stays as it is.
  Loadout? equipWeapon(String weaponId, {required Inventory inventory}) {
    if (!inventory.contains(weaponId)) return null;
    if (WeaponCatalog.byId(weaponId) == null) return null;
    return Loadout(weaponId: weaponId);
  }
}
