import 'dart:async';

import '../../../core/geometry/arena_bounds.dart';
import '../../ship/domain/ship_state.dart';
import '../../ship/domain/weapon_catalog.dart';
import '../domain/entities/battle_state.dart';
import '../domain/entities/target_state.dart';
import '../domain/events/battle_event.dart';

/// Coordinates a single battle: forwards player/game input to the
/// authoritative [BattleState] and publishes the resulting events.
class BattleSession {
  BattleSession(this.state);

  /// The training encounter: one static target to shoot at.
  factory BattleSession.training({ArenaBounds arena = ArenaBounds.standard}) {
    return BattleSession(
      BattleState(
        ship: ShipState(arena: arena, weapon: WeaponCatalog.blaster),
        targets: [TargetState(id: trainingTargetId, maxIntegrity: 300)],
      ),
    );
  }

  static const trainingTargetId = 'target.training_drone';

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

  void reportHit({required int projectileId, required String targetId}) =>
      _publish(
        state.resolveHit(projectileId: projectileId, targetId: targetId),
      );

  void reportProjectileLeftArena(int projectileId) =>
      state.discardProjectile(projectileId);

  Future<void> dispose() => _events.close();

  void _publish(List<BattleEvent> events) {
    if (_events.isClosed) return;
    events.forEach(_events.add);
  }
}
