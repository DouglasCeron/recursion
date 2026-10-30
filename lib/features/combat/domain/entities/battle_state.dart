import '../../../ship/domain/ship_state.dart';
import '../../../ship/domain/weapon_definition.dart';
import '../events/battle_event.dart';
import 'boss_state.dart';

enum BattleStatus { notStarted, inProgress, completed }

/// Authoritative state of the battle in progress.
///
/// Rendering components only report what they observe (collisions, projectiles
/// leaving the arena); every rule decision happens here and is returned as
/// [BattleEvent]s.
class BattleState {
  BattleState({required this.ship, required this.boss});

  final ShipState ship;
  final BossState boss;

  /// Projectiles that were fired and have not been resolved yet. A projectile
  /// leaves its map on first resolution, which makes duplicate collision
  /// reports harmless.
  final Map<int, WeaponDefinition> _playerProjectiles = {};
  final Map<int, int> _enemyProjectileDamage = {};

  BattleStatus _status = BattleStatus.notStarted;
  BattleOutcome? _outcome;
  int _nextProjectileId = 0;
  double _elapsed = 0;
  int _shotsFired = 0;
  int _hitsLanded = 0;

  BattleStatus get status => _status;
  BattleOutcome? get outcome => _outcome;
  double get elapsed => _elapsed;
  int get shotsFired => _shotsFired;
  int get hitsLanded => _hitsLanded;
  bool isProjectileInFlight(int projectileId) =>
      _playerProjectiles.containsKey(projectileId) ||
      _enemyProjectileDamage.containsKey(projectileId);

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

    final bossUpdate = boss.update(dt, targetX: ship.x, targetY: ship.y);
    final events = <BattleEvent>[...bossUpdate.events];
    for (final shot in bossUpdate.shots) {
      final projectileId = _nextProjectileId++;
      _enemyProjectileDamage[projectileId] = shot.damage;
      events.add(
        EnemyFired(
          projectileId: projectileId,
          originX: shot.originX,
          originY: shot.originY,
          velocityX: shot.velocityX,
          velocityY: shot.velocityY,
        ),
      );
    }
    if (boss.phase == BossPhase.escaped) {
      _complete(BattleOutcome.bossEscaped, events);
      return events;
    }

    if (ship.tryFire()) {
      final weapon = ship.weapon;
      final projectileId = _nextProjectileId++;
      _playerProjectiles[projectileId] = weapon;
      _shotsFired++;
      events.add(
        WeaponFired(
          projectileId: projectileId,
          weaponId: weapon.id,
          weaponType: weapon.type,
          originX: ship.x,
          originY: ship.y - ship.halfHeight,
          projectileSpeed: weapon.projectileSpeed,
        ),
      );
    }
    return events;
  }

  /// Resolves a reported collision between a player projectile and a boss
  /// part. The projectile stays in flight if the hit is not accepted.
  List<BattleEvent> resolveHit({
    required int projectileId,
    required String componentId,
  }) {
    if (_status != BattleStatus.inProgress) return const [];
    final weapon = _playerProjectiles[projectileId];
    if (weapon == null) return const [];
    final events = boss.applyHit(
      componentId: componentId,
      projectileId: projectileId,
      baseDamage: weapon.damage,
    );
    if (events == null) return const [];

    _playerProjectiles.remove(projectileId);
    _hitsLanded++;
    if (boss.phase == BossPhase.defeated) {
      _complete(BattleOutcome.victory, events);
    }
    return events;
  }

  /// Resolves a reported collision between an enemy projectile and the ship.
  List<BattleEvent> resolveShipHit({required int projectileId}) {
    if (_status != BattleStatus.inProgress) return const [];
    final damage = _enemyProjectileDamage.remove(projectileId);
    if (damage == null) return const [];

    final taken = ship.receiveDamage(damage);
    if (taken == 0) return const [];
    final events = <BattleEvent>[
      ShipHit(damage: taken, remainingHull: ship.hull),
    ];
    if (ship.isDestroyed) {
      events.add(const ShipDestroyed());
      _complete(BattleOutcome.defeat, events);
    }
    return events;
  }

  /// Forgets a projectile that left the arena without hitting anything.
  void discardProjectile(int projectileId) {
    _playerProjectiles.remove(projectileId);
    _enemyProjectileDamage.remove(projectileId);
  }

  void _complete(BattleOutcome outcome, List<BattleEvent> events) {
    _status = BattleStatus.completed;
    _outcome = outcome;
    _playerProjectiles.clear();
    _enemyProjectileDamage.clear();
    events.add(BattleCompleted(outcome: outcome));
  }
}
