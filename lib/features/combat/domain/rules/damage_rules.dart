/// Pure damage calculations shared by every damageable combat entity.
abstract final class DamageRules {
  /// Damage dealt by a hit after applying [multiplier]; never negative.
  static int damageFor({required int baseDamage, double multiplier = 1}) {
    if (baseDamage <= 0 || multiplier <= 0) return 0;
    return (baseDamage * multiplier).round();
  }

  /// Integrity remaining after taking [damage]; never below zero.
  static int integrityAfter({required int integrity, required int damage}) {
    if (damage <= 0) return integrity;
    final remaining = integrity - damage;
    return remaining < 0 ? 0 : remaining;
  }
}
