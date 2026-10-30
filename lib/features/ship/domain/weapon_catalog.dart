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

  static const all = <WeaponDefinition>[blaster];

  static WeaponDefinition? byId(String id) {
    for (final weapon in all) {
      if (weapon.id == id) return weapon;
    }
    return null;
  }
}
