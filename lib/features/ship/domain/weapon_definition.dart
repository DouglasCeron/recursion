/// Broad weapon families. Enemy intel and adaptations reason about these
/// categories rather than individual weapons.
enum WeaponType { blaster, heavyCannon, missile, laser }

/// Immutable content definition of a weapon.
///
/// This describes what a weapon *is*; whether the player owns or has it
/// equipped is tracked separately by inventory and loadout.
class WeaponDefinition {
  const WeaponDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.damage,
    required this.fireInterval,
    required this.projectileSpeed,
  }) : assert(damage >= 0),
       assert(fireInterval > 0),
       assert(projectileSpeed > 0);

  /// Stable identifier, safe to persist.
  final String id;
  final String name;
  final WeaponType type;

  /// Base damage dealt by a single projectile.
  final int damage;

  /// Seconds between consecutive shots.
  final double fireInterval;

  /// Projectile speed in arena units per second.
  final double projectileSpeed;
}
