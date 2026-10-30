import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/entities/target_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/ship/domain/ship_state.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';

void main() {
  const targetId = 'target';
  final blaster = WeaponCatalog.blaster;

  BattleState newBattle({int targetIntegrity = 100}) {
    final battle = BattleState(
      ship: ShipState(arena: ArenaBounds.standard, weapon: blaster),
      targets: [TargetState(id: targetId, maxIntegrity: targetIntegrity)],
    );
    battle.start();
    return battle;
  }

  int fireOnce(BattleState battle) {
    final fired = battle
        .update(blaster.fireInterval)
        .whereType<WeaponFired>()
        .single;
    return fired.projectileId;
  }

  test('start emits BattleStarted only once', () {
    final battle = BattleState(
      ship: ShipState(arena: ArenaBounds.standard, weapon: blaster),
      targets: [TargetState(id: targetId, maxIntegrity: 10)],
    );

    expect(battle.start(), [isA<BattleStarted>()]);
    expect(battle.start(), isEmpty);
    expect(battle.status, BattleStatus.inProgress);
  });

  test('does not fire before the battle starts', () {
    final battle = BattleState(
      ship: ShipState(arena: ArenaBounds.standard, weapon: blaster),
      targets: [TargetState(id: targetId, maxIntegrity: 10)],
    );

    expect(battle.update(1), isEmpty);
    expect(battle.shotsFired, 0);
  });

  test('fires at the weapon cadence with unique projectile ids', () {
    final battle = newBattle();

    final ids = [fireOnce(battle), fireOnce(battle), fireOnce(battle)];

    expect(ids.toSet(), hasLength(3));
    expect(battle.shotsFired, 3);
  });

  test('a hit applies the weapon damage to the target', () {
    final battle = newBattle();
    final projectileId = fireOnce(battle);

    final events = battle.resolveHit(
      projectileId: projectileId,
      targetId: targetId,
    );

    final hit = events.whereType<TargetHit>().single;
    expect(hit.damage, blaster.damage);
    expect(battle.target(targetId)!.integrity, 100 - blaster.damage);
    expect(battle.hitsLanded, 1);
  });

  test('duplicate collision reports for the same projectile are ignored', () {
    final battle = newBattle();
    final projectileId = fireOnce(battle);

    battle.resolveHit(projectileId: projectileId, targetId: targetId);
    final duplicate = battle.resolveHit(
      projectileId: projectileId,
      targetId: targetId,
    );

    expect(duplicate, isEmpty);
    expect(battle.target(targetId)!.integrity, 100 - blaster.damage);
    expect(battle.hitsLanded, 1);
  });

  test('unknown or discarded projectiles deal no damage', () {
    final battle = newBattle();
    final projectileId = fireOnce(battle);
    battle.discardProjectile(projectileId);

    expect(
      battle.resolveHit(projectileId: projectileId, targetId: targetId),
      isEmpty,
    );
    expect(battle.resolveHit(projectileId: 999, targetId: targetId), isEmpty);
    expect(battle.target(targetId)!.integrity, 100);
  });

  test('destroying the last target completes the battle exactly once', () {
    final battle = newBattle(targetIntegrity: blaster.damage * 2);
    final first = fireOnce(battle);
    final second = fireOnce(battle);
    final third = fireOnce(battle);

    battle.resolveHit(projectileId: first, targetId: targetId);
    final killing = battle.resolveHit(projectileId: second, targetId: targetId);
    final afterDeath = battle.resolveHit(
      projectileId: third,
      targetId: targetId,
    );

    expect(killing.whereType<TargetDestroyed>(), hasLength(1));
    expect(
      killing.whereType<BattleCompleted>().single.outcome,
      BattleOutcome.victory,
    );
    expect(afterDeath, isEmpty);
    expect(battle.status, BattleStatus.completed);
    expect(battle.update(1), isEmpty);
  });
}
