import '../../../ship/domain/weapon_definition.dart';
import '../rules/damage_rules.dart';
import 'boss_component_state.dart';
import 'boss_definition.dart';
import 'combat_log.dart';

/// Enemy drone that watches the fight and reports to its faction.
///
/// It only sees what happens while it is alive and only records a limited
/// set of metrics (weapon usage, damage per boss zone and core targeting). It can transmit only if
/// it survives until the end of the battle.
class ObserverDrone {
  ObserverDrone({this.maxIntegrity = 60})
    : assert(maxIntegrity > 0),
      _integrity = maxIntegrity;

  final int maxIntegrity;
  final CombatLog _log = CombatLog();
  int _integrity;
  bool _transmitted = false;

  int get integrity => _integrity;
  bool get isDestroyed => _integrity == 0;
  bool get hasTransmitted => _transmitted;

  void observeShot(WeaponType type) {
    if (!isDestroyed) _log.recordShot(type);
  }

  void observeHit(
    WeaponType type, {
    required int damage,
    BossZone? zone,
    bool onCore = false,
    bool coreExposed = false,
  }) {
    if (isDestroyed) return;
    _log.recordHit(
      type,
      damage: damage,
      zone: zone,
      onCore: onCore,
      coreExposed: coreExposed,
    );
  }

  /// Applies [damage]; destruction is reported exactly once.
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

  /// Sends what the drone recorded. Returns null if it was destroyed or has
  /// already transmitted.
  CombatStats? transmit() {
    if (isDestroyed || _transmitted) return null;
    _transmitted = true;
    return _log.snapshot();
  }
}
