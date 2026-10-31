import '../../../ship/domain/weapon_definition.dart';

/// Adjustments applied to a boss for one battle.
///
/// Combat only knows these neutral numbers; why they were chosen (enemy
/// intel and adaptation rules) lives in the boss evolution feature.
class BossModifiers {
  const BossModifiers({
    this.damageMultipliers = const {},
    this.coreWindowOpenDuration,
  });

  static const none = BossModifiers();

  /// Damage multiplier per weapon type for hits that do not land on an
  /// exposed core. Missing types take normal damage.
  final Map<WeaponType, double> damageMultipliers;

  /// Replaces how long the core stays exposed in each window, if set.
  final double? coreWindowOpenDuration;

  bool get isAdapted =>
      damageMultipliers.values.any((m) => m < 1) ||
      coreWindowOpenDuration != null;

  double damageMultiplierFor(WeaponType type) => damageMultipliers[type] ?? 1;
}
