import '../../../ship/domain/ship_state.dart';
import '../../../ship/domain/weapon_definition.dart';
import '../events/battle_event.dart';
import '../rules/damage_rules.dart';
import 'battle_record.dart';
import 'boss_component_state.dart';
import 'boss_definition.dart';
import 'boss_state.dart';
import 'combat_log.dart';
import 'dropped_item.dart';
import 'observer_drone.dart';

enum BattleStatus { notStarted, inProgress, completed }

/// Authoritative state of the battle in progress.
///
/// Rendering components only report what they observe (collisions, projectiles
/// leaving the arena); every rule decision happens here and is returned as
/// [BattleEvent]s.
class BattleState {
  BattleState({
    required this.ship,
    required this.boss,
    ObserverDrone? observer,
    this.dropLifetime = defaultDropLifetime,
  }) : observer = observer ?? ObserverDrone();

  /// Seconds a drop stays on the battlefield before it is lost.
  static const defaultDropLifetime = 8.0;

  final ShipState ship;
  final BossState boss;
  final ObserverDrone observer;
  final double dropLifetime;

  /// Everything that really happened, regardless of what the observer saw.
  final CombatLog _log = CombatLog();
  bool _intelTransmitted = false;
  final Map<int, DroppedItem> _drops = {};
  final List<String> _collectedItemIds = [];
  int _nextDropId = 0;

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
  Iterable<DroppedItem> get drops => _drops.values;
  DroppedItem? drop(int dropId) => _drops[dropId];

  /// Items the player actually picked up during this battle.
  List<String> get collectedItemIds => List.unmodifiable(_collectedItemIds);

  bool get intelTransmitted => _intelTransmitted;

  BattleRecord get record => BattleRecord(
    bossId: boss.definition.id,
    outcome: _outcome,
    duration: _elapsed,
    stats: _log.snapshot(),
    destroyedComponentIds: [
      for (final c in boss.components)
        if (c.isDestroyed) c.id,
    ],
    collectedItemIds: collectedItemIds,
    observerDestroyed: observer.isDestroyed,
    intelTransmitted: _intelTransmitted,
  );

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

    final events = <BattleEvent>[];
    for (final drop in _drops.values) {
      if (drop.tick(dt)) {
        events.add(ItemExpired(dropId: drop.id, itemId: drop.itemId));
      }
    }

    final bossUpdate = boss.update(dt, targetX: ship.x, targetY: ship.y);
    events.addAll(bossUpdate.events);
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
      _log.recordShot(weapon.type);
      observer.observeShot(weapon.type);
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
      weaponType: weapon.type,
    );
    if (events == null) return const [];

    _playerProjectiles.remove(projectileId);
    _hitsLanded++;
    final hit = events.whereType<BossComponentHit>().single;
    _recordHit(
      weapon.type,
      damage: hit.damage,
      zone: boss.definition.component(hit.componentId).zone,
      onCore: boss.component(hit.componentId)!.kind == BossComponentKind.core,
      coreExposed: hit.weakPointBonus,
    );
    for (final destroyed
        in events.whereType<BossComponentDestroyed>().toList()) {
      final itemId = boss.definition
          .component(destroyed.componentId)
          .dropItemId;
      if (itemId != null) events.add(_spawnDrop(itemId, destroyed.componentId));
    }
    if (boss.phase == BossPhase.defeated) {
      _complete(BattleOutcome.victory, events);
    }
    return events;
  }

  /// Resolves a player projectile hitting the observer drone. The projectile
  /// stays in flight if the drone is already destroyed.
  List<BattleEvent> resolveObserverHit({required int projectileId}) {
    if (_status != BattleStatus.inProgress || observer.isDestroyed) {
      return const [];
    }
    final weapon = _playerProjectiles.remove(projectileId);
    if (weapon == null) return const [];

    _hitsLanded++;
    final damage = DamageRules.damageFor(baseDamage: weapon.damage);
    _recordHit(weapon.type, damage: damage);
    final outcome = observer.receiveDamage(damage);
    return [
      ObserverHit(
        projectileId: projectileId,
        damage: outcome.damageApplied,
        remainingIntegrity: outcome.remainingIntegrity,
      ),
      if (outcome.destroyedNow) const ObserverDestroyed(),
    ];
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

  /// Resolves the ship touching a drop. The item is granted at most once and
  /// only while the drop is still available and the battle is running.
  List<BattleEvent> collectDrop(int dropId) {
    if (_status != BattleStatus.inProgress) return const [];
    final drop = _drops[dropId];
    if (drop == null || !drop.collect()) return const [];
    _collectedItemIds.add(drop.itemId);
    return [ItemCollected(dropId: drop.id, itemId: drop.itemId)];
  }

  /// Forgets a projectile that left the arena without hitting anything.
  void discardProjectile(int projectileId) {
    _playerProjectiles.remove(projectileId);
    _enemyProjectileDamage.remove(projectileId);
  }

  ItemDropped _spawnDrop(String itemId, String componentId) {
    final (x, y) = boss.componentPosition(componentId);
    final drop = DroppedItem(
      id: _nextDropId++,
      itemId: itemId,
      x: x,
      y: y,
      lifetime: dropLifetime,
    );
    _drops[drop.id] = drop;
    return ItemDropped(
      dropId: drop.id,
      itemId: itemId,
      x: x,
      y: y,
      lifetime: dropLifetime,
    );
  }

  void _recordHit(
    WeaponType type, {
    required int damage,
    BossZone? zone,
    bool onCore = false,
    bool coreExposed = false,
  }) {
    _log.recordHit(
      type,
      damage: damage,
      zone: zone,
      onCore: onCore,
      coreExposed: coreExposed,
    );
    observer.observeHit(
      type,
      damage: damage,
      zone: zone,
      onCore: onCore,
      coreExposed: coreExposed,
    );
  }

  /// Ends the battle. Drops that were not collected are lost, and a surviving
  /// observer transmits what it recorded.
  void _complete(BattleOutcome outcome, List<BattleEvent> events) {
    _status = BattleStatus.completed;
    _outcome = outcome;
    _playerProjectiles.clear();
    _enemyProjectileDamage.clear();
    for (final drop in _drops.values) {
      if (drop.expire()) {
        events.add(ItemExpired(dropId: drop.id, itemId: drop.itemId));
      }
    }
    final transmitted = observer.transmit();
    if (transmitted != null) {
      _intelTransmitted = true;
      events.add(ObserverTransmitted(stats: transmitted));
    }
    events.add(BattleCompleted(outcome: outcome));
  }
}
