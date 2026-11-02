import 'dart:math' as math;

import '../../../../core/geometry/arena_bounds.dart';
import '../../../ship/domain/weapon_definition.dart';
import '../rules/damage_rules.dart';
import 'boss_component_state.dart';
import 'boss_definition.dart';
import 'combat_log.dart';

/// Enemy drone that watches the fight and reports to its faction.
///
/// It only records a limited set of metrics (weapon usage, damage per boss
/// zone and core targeting). It cannot be destroyed: once it has taken
/// [maxIntegrity] damage it flees, stops watching, and still transmits what
/// it saw until then when the battle ends.
///
/// Every hit that does not make it flee sends it to a new spot along the
/// left or right edge, below the boss, at least [minJump] away from where it
/// was, so it is hard to hit twice in a row.
class ObserverDrone {
  ObserverDrone({required this.arena, this.maxIntegrity = 60, int? seed})
    : assert(maxIntegrity > 0),
      _integrity = maxIntegrity,
      _random = math.Random(seed),
      _x = edgeMargin,
      _y = arena.height * 0.45;

  /// Distance from the side edges to the drone's center.
  static const edgeMargin = 36.0;

  /// Vertical band the drone moves in, as shares of the arena height. It
  /// starts below the boss so it never hides behind it.
  static const minYShare = 0.32;
  static const maxYShare = 0.6;
  static const minJump = 90.0;
  static const _relocationTries = 8;

  final ArenaBounds arena;
  final int maxIntegrity;
  final CombatLog _log = CombatLog();
  final math.Random _random;
  int _integrity;
  double _x;
  double _y;
  bool _transmitted = false;

  int get integrity => _integrity;
  bool get hasFled => _integrity == 0;
  bool get hasTransmitted => _transmitted;

  /// Where the drone is, or is heading to, in arena units.
  double get x => _x;
  double get y => _y;

  void observeDestroyedWeapon(String componentId) {
    if (!hasFled) _log.recordDestroyedWeapon(componentId);
  }

  void observeShot(WeaponType type) {
    if (!hasFled) _log.recordShot(type);
  }

  void observeHit(
    WeaponType type, {
    required int damage,
    BossZone? zone,
    bool onCore = false,
    bool coreExposed = false,
  }) {
    if (hasFled) return;
    _log.recordHit(
      type,
      damage: damage,
      zone: zone,
      onCore: onCore,
      coreExposed: coreExposed,
    );
  }

  /// Applies [damage]. Fleeing is reported exactly once, as `destroyedNow`;
  /// a hit it survives moves it to a new spot.
  DamageOutcome receiveDamage(int damage) {
    if (hasFled) return DamageOutcome.ignored;
    final before = _integrity;
    _integrity = DamageRules.integrityAfter(integrity: before, damage: damage);
    if (!hasFled) _relocate();
    return DamageOutcome(
      damageApplied: before - _integrity,
      remainingIntegrity: _integrity,
      destroyedNow: _integrity == 0,
    );
  }

  /// Sends what the drone recorded, even if it fled. Returns null once it
  /// has already transmitted.
  CombatStats? transmit() {
    if (_transmitted) return null;
    _transmitted = true;
    return _log.snapshot();
  }

  void _relocate() {
    final minY = arena.height * minYShare;
    final maxY = arena.height * maxYShare;
    for (var i = 0; i < _relocationTries; i++) {
      final x = _random.nextBool() ? edgeMargin : arena.width - edgeMargin;
      final y = minY + (maxY - minY) * _random.nextDouble();
      if (math.sqrt(math.pow(x - _x, 2) + math.pow(y - _y, 2)) >= minJump) {
        _x = x;
        _y = y;
        return;
      }
    }
    _x = arena.width - _x;
  }
}
