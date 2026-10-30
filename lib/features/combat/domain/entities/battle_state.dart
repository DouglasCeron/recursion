import '../../../ship/domain/ship_state.dart';
import '../../../ship/domain/weapon_definition.dart';
import '../events/battle_event.dart';
import '../rules/damage_rules.dart';
import 'target_state.dart';

enum BattleStatus { notStarted, inProgress, completed }

/// Authoritative state of the battle in progress.
///
/// Rendering components only report what they observe (collisions, projectiles
/// leaving the arena); every rule decision happens here and is returned as
/// [BattleEvent]s.
class BattleState {
  BattleState({required this.ship, required List<TargetState> targets})
    : assert(targets.isNotEmpty),
      _targets = {for (final target in targets) target.id: target};

  final ShipState ship;
  final Map<String, TargetState> _targets;

  /// Projectiles that were fired and have not hit anything yet. A projectile
  /// leaves this map on its first resolution, which makes duplicate collision
  /// reports harmless.
  final Map<int, WeaponDefinition> _projectilesInFlight = {};

  BattleStatus _status = BattleStatus.notStarted;
  int _nextProjectileId = 0;
  double _elapsed = 0;
  int _shotsFired = 0;
  int _hitsLanded = 0;

  BattleStatus get status => _status;
  double get elapsed => _elapsed;
  int get shotsFired => _shotsFired;
  int get hitsLanded => _hitsLanded;
  Iterable<TargetState> get targets => _targets.values;
  TargetState? target(String id) => _targets[id];
  bool isProjectileInFlight(int projectileId) =>
      _projectilesInFlight.containsKey(projectileId);

  List<BattleEvent> start() {
    if (_status != BattleStatus.notStarted) return const [];
    _status = BattleStatus.inProgress;
    return const [BattleStarted()];
  }

  /// Advances the battle by [dt] seconds. The ship fires automatically
  /// whenever its weapon is ready.
  List<BattleEvent> update(double dt) {
    if (_status != BattleStatus.inProgress || dt <= 0) return const [];
    _elapsed += dt;
    ship.update(dt);
    if (!ship.tryFire()) return const [];

    final weapon = ship.weapon;
    final projectileId = _nextProjectileId++;
    _projectilesInFlight[projectileId] = weapon;
    _shotsFired++;
    return [
      WeaponFired(
        projectileId: projectileId,
        weaponId: weapon.id,
        weaponType: weapon.type,
        originX: ship.x,
        originY: ship.y - ship.halfHeight,
        projectileSpeed: weapon.projectileSpeed,
      ),
    ];
  }

  /// Resolves a reported collision between a projectile and a target.
  List<BattleEvent> resolveHit({
    required int projectileId,
    required String targetId,
  }) {
    if (_status != BattleStatus.inProgress) return const [];
    final target = _targets[targetId];
    if (target == null || target.isDestroyed) return const [];
    final weapon = _projectilesInFlight.remove(projectileId);
    if (weapon == null) return const [];

    final outcome = target.receiveDamage(
      DamageRules.damageFor(baseDamage: weapon.damage),
    );
    _hitsLanded++;
    final events = <BattleEvent>[
      TargetHit(
        targetId: targetId,
        projectileId: projectileId,
        damage: outcome.damageApplied,
        remainingIntegrity: outcome.remainingIntegrity,
      ),
    ];
    if (outcome.destroyedNow) {
      events.add(TargetDestroyed(targetId: targetId));
      if (_targets.values.every((t) => t.isDestroyed)) {
        _status = BattleStatus.completed;
        _projectilesInFlight.clear();
        events.add(const BattleCompleted(outcome: BattleOutcome.victory));
      }
    }
    return events;
  }

  /// Forgets a projectile that left the arena without hitting anything.
  void discardProjectile(int projectileId) {
    _projectilesInFlight.remove(projectileId);
  }
}
