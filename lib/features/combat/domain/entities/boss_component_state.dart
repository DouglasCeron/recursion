import '../rules/damage_rules.dart';

/// Kinds of boss parts. Each kind carries different rules: losing the cannon
/// changes the attack pattern and destroying the core defeats the boss.
enum BossComponentKind { cannon, armor, core }

/// Result of applying damage to a [BossComponentState].
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

  /// True only for the hit that moved the component into the destroyed state.
  final bool destroyedNow;
}

/// Runtime integrity of one destructible boss part.
class BossComponentState {
  BossComponentState({
    required this.id,
    required this.kind,
    required this.maxIntegrity,
  }) : assert(maxIntegrity > 0),
       _integrity = maxIntegrity;

  final String id;
  final BossComponentKind kind;
  final int maxIntegrity;
  int _integrity;

  int get integrity => _integrity;
  bool get isDestroyed => _integrity == 0;

  /// Applies [damage]. Hits on an already destroyed component are ignored, so
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
