import 'weapon_definition.dart';

/// Static weapon content available in the prototype.
abstract final class WeaponCatalog {
  static const blaster = WeaponDefinition(
    id: 'weapon.blaster',
    name: 'Blaster',
    type: WeaponType.blaster,
    damage: 10,
    fireInterval: 0.25,
    projectileSpeed: 520,
  );

  /// Salvaged from the Sentinel's cannon. Slower but hits much harder.
  static const heavyCannon = WeaponDefinition(
    id: 'weapon.heavy_cannon',
    name: 'Heavy Cannon',
    type: WeaponType.heavyCannon,
    damage: 35,
    fireInterval: 0.6,
    projectileSpeed: 420,
  );

  static const all = <WeaponDefinition>[blaster, heavyCannon];

  static WeaponDefinition? byId(String id) {
    for (final weapon in all) {
      if (weapon.id == id) return weapon;
    }
    return null;
  }
}
