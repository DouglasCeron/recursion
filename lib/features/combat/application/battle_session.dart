import 'dart:async';

import '../../../core/geometry/arena_bounds.dart';
import '../../ship/domain/ship_state.dart';
import '../../ship/domain/weapon_catalog.dart';
import '../../ship/domain/weapon_definition.dart';
import '../domain/content/boss_catalog.dart';
import '../domain/entities/battle_state.dart';
import '../domain/entities/boss_definition.dart';
import '../domain/entities/boss_state.dart';
import '../domain/events/battle_event.dart';

/// Coordinates a single battle: forwards player/game input to the
/// authoritative [BattleState] and publishes the resulting events.
class BattleSession {
  BattleSession(this.state);

  factory BattleSession.boss({
    BossDefinition boss = BossCatalog.sentinel,
    WeaponDefinition weapon = WeaponCatalog.blaster,
    ArenaBounds arena = ArenaBounds.standard,
  }) {
    return BattleSession(
      BattleState(
        ship: ShipState(arena: arena, weapon: weapon),
        boss: BossState(definition: boss, arena: arena),
      ),
    );
  }

  final BattleState state;
  final _events = StreamController<BattleEvent>.broadcast(sync: true);

  Stream<BattleEvent> get events => _events.stream;
  ArenaBounds get arena => state.ship.arena;

  void start() => _publish(state.start());

  void update(double dt) => _publish(state.update(dt));

  void steerShip(double dx, double dy) {
    if (state.status != BattleStatus.inProgress) return;
    state.ship.steerBy(dx, dy);
  }

  /// Reports a player projectile touching a boss part. Returns whether the
  /// projectile was consumed; if not, it should keep flying.
  bool reportHit({required int projectileId, required String componentId}) {
    _publish(
      state.resolveHit(projectileId: projectileId, componentId: componentId),
    );
    return !state.isProjectileInFlight(projectileId);
  }

  void reportShipHit(int projectileId) =>
      _publish(state.resolveShipHit(projectileId: projectileId));

  void reportDropTouched(int dropId) => _publish(state.collectDrop(dropId));

  void reportProjectileLeftArena(int projectileId) =>
      state.discardProjectile(projectileId);

  Future<void> dispose() => _events.close();

  void _publish(List<BattleEvent> events) {
    if (_events.isClosed) return;
    events.forEach(_events.add);
  }
}
