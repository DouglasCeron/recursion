import '../../combat/domain/entities/boss_definition.dart';
import '../../combat/domain/entities/combat_log.dart';
import '../../ship/domain/weapon_definition.dart';

enum ExposureLevel { low, medium, high }

/// How much one weapon type was seen in use.
class WeaponExposure {
  const WeaponExposure({
    required this.type,
    required this.shots,
    required this.damage,
    required this.damageShare,
    required this.level,
  });

  final WeaponType type;
  final int shots;
  final int damage;

  /// Fraction (0..1) of all observed damage dealt with this weapon type.
  final double damageShare;
  final ExposureLevel level;
}

/// Aggregated, categorized view of the weapons actually used in a battle.
///
/// Only weapon types that were fired appear in the profile; owning a weapon
/// without using it never exposes it.
class WeaponExposureProfile {
  const WeaponExposureProfile({
    required this.weapons,
    required this.weakPointFocus,
    this.zoneShares = const {},
  });

  factory WeaponExposureProfile.fromStats(CombatStats stats) {
    final total = stats.totalDamage;
    final zoneTotal = stats.zoneDamage.values.fold(0, (sum, d) => sum + d);
    return WeaponExposureProfile(
      zoneShares: {
        if (zoneTotal > 0)
          for (final MapEntry(key: zone, value: damage)
              in stats.zoneDamage.entries)
            zone: damage / zoneTotal,
      },
      weapons: {
        for (final MapEntry(key: type, value: usage) in stats.weapons.entries)
          if (usage.shots > 0)
            type: WeaponExposure(
              type: type,
              shots: usage.shots,
              damage: usage.damage,
              damageShare: total == 0 ? 0 : usage.damage / total,
              level: classify(total == 0 ? 0 : usage.damage / total),
            ),
      },
      weakPointFocus: stats.coreDamage == 0
          ? null
          : stats.coreDamageWhileExposed / stats.coreDamage,
    );
  }

  /// Damage shares below this are [ExposureLevel.low].
  static const lowShareLimit = 0.15;

  /// Damage shares above this are [ExposureLevel.high].
  static const highShareLimit = 0.5;

  /// Weak point focus at or above this means the player waits for the core
  /// to open before hitting it.
  static const weakPointExploitThreshold = 0.5;

  final Map<WeaponType, WeaponExposure> weapons;

  /// Fraction of core damage dealt while the core was exposed, or null if
  /// the core was never damaged.
  final double? weakPointFocus;

  /// Fraction (0..1) of the damage dealt to boss parts that landed in each
  /// zone. Zones never hit are absent.
  final Map<BossZone, double> zoneShares;

  bool get exploitsWeakPoint =>
      (weakPointFocus ?? 0) >= weakPointExploitThreshold;

  ExposureLevel? levelOf(WeaponType type) => weapons[type]?.level;

  static ExposureLevel classify(double damageShare) {
    if (damageShare < lowShareLimit) return ExposureLevel.low;
    if (damageShare > highShareLimit) return ExposureLevel.high;
    return ExposureLevel.medium;
  }
}
