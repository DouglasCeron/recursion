import '../../../ship/domain/weapon_definition.dart';

/// Aggregated usage of one weapon type.
class WeaponUsage {
  const WeaponUsage({this.shots = 0, this.hits = 0, this.damage = 0});

  final int shots;
  final int hits;
  final int damage;

  WeaponUsage add({int shots = 0, int hits = 0, int damage = 0}) => WeaponUsage(
    shots: this.shots + shots,
    hits: this.hits + hits,
    damage: this.damage + damage,
  );
}

/// Immutable snapshot of combat metrics.
class CombatStats {
  const CombatStats({
    required this.weapons,
    required this.coreDamage,
    required this.coreDamageWhileExposed,
  });

  static const empty = CombatStats(
    weapons: {},
    coreDamage: 0,
    coreDamageWhileExposed: 0,
  );

  /// Usage per weapon type. Types that were never fired are absent.
  final Map<WeaponType, WeaponUsage> weapons;

  /// Damage dealt to the boss core, and the part of it dealt while exposed.
  final int coreDamage;
  final int coreDamageWhileExposed;

  int get totalDamage => weapons.values.fold(0, (sum, w) => sum + w.damage);
}

/// In-memory aggregation of combat metrics during a battle. Nothing here is
/// persisted per shot; only snapshots are taken at defined points.
class CombatLog {
  final Map<WeaponType, WeaponUsage> _weapons = {};
  int _coreDamage = 0;
  int _coreDamageWhileExposed = 0;

  void recordShot(WeaponType type) => _update(type, shots: 1);

  void recordHit(
    WeaponType type, {
    required int damage,
    bool onCore = false,
    bool coreExposed = false,
  }) {
    _update(type, hits: 1, damage: damage);
    if (!onCore) return;
    _coreDamage += damage;
    if (coreExposed) _coreDamageWhileExposed += damage;
  }

  CombatStats snapshot() => CombatStats(
    weapons: Map.unmodifiable(_weapons),
    coreDamage: _coreDamage,
    coreDamageWhileExposed: _coreDamageWhileExposed,
  );

  void _update(WeaponType type, {int shots = 0, int hits = 0, int damage = 0}) {
    _weapons[type] = (_weapons[type] ?? const WeaponUsage()).add(
      shots: shots,
      hits: hits,
      damage: damage,
    );
  }
}
