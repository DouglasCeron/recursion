import '../rules/damage_rules.dart';

/// Result of applying damage to a [TargetState].
class DamageOutcome {
  const DamageOutcome({
    required this.damageApplied,
    required this.remainingIntegrity,
    required this.destroyedNow,
  });

  static const ignored = DamageOutcome(
    damageApplied: 0,
    remainingIntegrity: 0,
    destroyedNow: false,
  );

  final int damageApplied;
  final int remainingIntegrity;

  /// True only for the hit that moved the target into the destroyed state.
  final bool destroyedNow;
}

/// A simple destructible target with its own integrity.
class TargetState {
  TargetState({required this.id, required this.maxIntegrity})
    : assert(maxIntegrity > 0),
      _integrity = maxIntegrity;

  final String id;
  final int maxIntegrity;
  int _integrity;

  int get integrity => _integrity;
  bool get isDestroyed => _integrity == 0;

  /// Applies [damage]. Hits on an already destroyed target are ignored, so
  /// destruction is reported exactly once.
  DamageOutcome receiveDamage(int damage) {
    if (isDestroyed) return DamageOutcome.ignored;
    final before = _integrity;
    _integrity = DamageRules.integrityAfter(integrity: before, damage: damage);
    return DamageOutcome(
      damageApplied: before - _integrity,
      remainingIntegrity: _integrity,
      destroyedNow: _integrity == 0,
    );
  }
}
