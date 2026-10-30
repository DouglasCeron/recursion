import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/ship/domain/ship_state.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

void main() {
  const arena = ArenaBounds.standard;
  const coreId = 'sentinel.core';
  const armorId = 'sentinel.armor';
  const cannonId = 'sentinel.cannon';
  const blaster = WeaponCatalog.blaster;
  const breaker = WeaponDefinition(
    id: 'test.breaker',
    name: 'Breaker',
    type: WeaponType.heavyCannon,
    damage: 1000,
    fireInterval: 0.1,
    projectileSpeed: 100,
  );

  BattleState newBattle({WeaponDefinition weapon = blaster}) {
    final battle = BattleState(
      ship: ShipState(arena: arena, weapon: weapon),
      boss: BossState(definition: BossCatalog.sentinel, arena: arena),
    );
    battle.start();
    return battle;
  }

  int fireOnce(BattleState battle) => battle
      .update(battle.ship.weapon.fireInterval)
      .whereType<WeaponFired>()
      .single
      .projectileId;

  int nextEnemyShot(BattleState battle) {
    for (var i = 0; i < 1000; i++) {
      final fired = battle.update(0.05).whereType<EnemyFired>();
      if (fired.isNotEmpty) return fired.first.projectileId;
    }
    fail('the boss never fired');
  }

  test('start emits BattleStarted only once', () {
    final battle = BattleState(
      ship: ShipState(arena: arena, weapon: blaster),
      boss: BossState(definition: BossCatalog.sentinel, arena: arena),
    );

    expect(battle.start(), [isA<BattleStarted>()]);
    expect(battle.start(), isEmpty);
    expect(battle.status, BattleStatus.inProgress);
  });

  test('does not fire before the battle starts', () {
    final battle = BattleState(
      ship: ShipState(arena: arena, weapon: blaster),
      boss: BossState(definition: BossCatalog.sentinel, arena: arena),
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

  group('player hits', () {
    test('apply the weapon damage to the hit part', () {
      final battle = newBattle();
      final projectileId = fireOnce(battle);

      final events = battle.resolveHit(
        projectileId: projectileId,
        componentId: armorId,
      );

      expect(events.whereType<BossComponentHit>().single.damage, 10);
      expect(battle.boss.component(armorId)!.integrity, 90);
      expect(battle.hitsLanded, 1);
      expect(battle.isProjectileInFlight(projectileId), isFalse);
    });

    test('duplicate collision reports are ignored', () {
      final battle = newBattle();
      final projectileId = fireOnce(battle);

      battle.resolveHit(projectileId: projectileId, componentId: armorId);
      final duplicate = battle.resolveHit(
        projectileId: projectileId,
        componentId: armorId,
      );

      expect(duplicate, isEmpty);
      expect(battle.boss.component(armorId)!.integrity, 90);
      expect(battle.hitsLanded, 1);
    });

    test('a hit on a destroyed part keeps the projectile in flight', () {
      final battle = newBattle(weapon: breaker);
      battle.resolveHit(projectileId: fireOnce(battle), componentId: armorId);
      final projectileId = fireOnce(battle);

      final events = battle.resolveHit(
        projectileId: projectileId,
        componentId: armorId,
      );

      expect(events, isEmpty);
      expect(battle.isProjectileInFlight(projectileId), isTrue);
    });

    test('discarded projectiles deal no damage', () {
      final battle = newBattle();
      final projectileId = fireOnce(battle);
      battle.discardProjectile(projectileId);

      expect(
        battle.resolveHit(projectileId: projectileId, componentId: armorId),
        isEmpty,
      );
      expect(battle.boss.component(armorId)!.integrity, 100);
    });

    test('destroying the core wins the battle exactly once', () {
      final battle = newBattle(weapon: breaker);
      final killing = fireOnce(battle);
      final late = fireOnce(battle);

      final events = battle.resolveHit(
        projectileId: killing,
        componentId: coreId,
      );

      expect(events.whereType<BossDefeated>(), hasLength(1));
      expect(
        events.whereType<BattleCompleted>().single.outcome,
        BattleOutcome.victory,
      );
      expect(
        battle.resolveHit(projectileId: late, componentId: cannonId),
        isEmpty,
      );
      expect(battle.status, BattleStatus.completed);
      expect(battle.outcome, BattleOutcome.victory);
      expect(battle.update(1), isEmpty);
    });
  });

  group('enemy hits', () {
    test('damage the ship once per projectile', () {
      final battle = newBattle();
      final projectileId = nextEnemyShot(battle);

      final events = battle.resolveShipHit(projectileId: projectileId);
      final duplicate = battle.resolveShipHit(projectileId: projectileId);

      expect(events.whereType<ShipHit>().single.damage, 15);
      expect(battle.ship.hull, 85);
      expect(duplicate, isEmpty);
    });

    test('are ignored while the ship is invulnerable after a hit', () {
      final battle = newBattle();
      final first = nextEnemyShot(battle);
      final second = nextEnemyShot(battle);
      battle.ship.receiveDamage(1);

      battle.resolveShipHit(projectileId: first);

      expect(battle.ship.hull, 99);
      expect(battle.isProjectileInFlight(first), isFalse);

      battle.update(battle.ship.invulnerabilityDuration);
      expect(battle.resolveShipHit(projectileId: second), isNotEmpty);
      expect(battle.ship.hull, 84);
    });

    test('destroying the ship loses the battle', () {
      final battle = newBattle();
      final events = <BattleEvent>[];
      while (battle.status == BattleStatus.inProgress) {
        final projectileId = nextEnemyShot(battle);
        events.addAll(battle.resolveShipHit(projectileId: projectileId));
      }

      expect(events.whereType<ShipDestroyed>(), hasLength(1));
      expect(
        events.whereType<BattleCompleted>().single.outcome,
        BattleOutcome.defeat,
      );
      expect(battle.ship.hull, 0);
    });
  });

  group('drops', () {
    ItemDropped destroyCannon(BattleState battle) => battle
        .resolveHit(projectileId: fireOnce(battle), componentId: cannonId)
        .whereType<ItemDropped>()
        .single;

    test('destroying the cannon drops the heavy cannon where it was', () {
      final battle = newBattle(weapon: breaker);
      final projectileId = fireOnce(battle);
      final (x, y) = battle.boss.componentPosition(cannonId);

      final dropped = battle
          .resolveHit(projectileId: projectileId, componentId: cannonId)
          .whereType<ItemDropped>()
          .single;

      expect(dropped.itemId, WeaponCatalog.heavyCannon.id);
      expect(dropped.x, x);
      expect(dropped.y, y);
      expect(dropped.lifetime, BattleState.defaultDropLifetime);
    });

    test('parts without a drop leave nothing behind', () {
      final battle = newBattle(weapon: breaker);

      final events = battle.resolveHit(
        projectileId: fireOnce(battle),
        componentId: armorId,
      );

      expect(events.whereType<ItemDropped>(), isEmpty);
      expect(battle.drops, isEmpty);
    });

    test('destroying a part does not grant its item', () {
      final battle = newBattle(weapon: breaker);
      destroyCannon(battle);

      expect(battle.collectedItemIds, isEmpty);
    });

    test('collecting grants the item exactly once', () {
      final battle = newBattle(weapon: breaker);
      final dropId = destroyCannon(battle).dropId;

      final first = battle.collectDrop(dropId);
      final second = battle.collectDrop(dropId);

      expect(
        first.whereType<ItemCollected>().single.itemId,
        WeaponCatalog.heavyCannon.id,
      );
      expect(second, isEmpty);
      expect(battle.collectedItemIds, [WeaponCatalog.heavyCannon.id]);
    });

    test('an uncollected drop expires after its lifetime', () {
      final battle = newBattle(weapon: breaker);
      final dropId = destroyCannon(battle).dropId;

      final events = <BattleEvent>[];
      for (var i = 0; i < 170; i++) {
        events.addAll(battle.update(0.05));
      }

      expect(events.whereType<ItemExpired>().single.dropId, dropId);
      expect(battle.collectDrop(dropId), isEmpty);
      expect(battle.collectedItemIds, isEmpty);
    });

    test('ending the battle loses uncollected drops', () {
      final battle = newBattle(weapon: breaker);
      final dropId = destroyCannon(battle).dropId;

      final events = battle.resolveHit(
        projectileId: fireOnce(battle),
        componentId: coreId,
      );

      expect(events.whereType<ItemExpired>().single.dropId, dropId);
      expect(events.last, isA<BattleCompleted>());
      expect(battle.collectDrop(dropId), isEmpty);
      expect(battle.collectedItemIds, isEmpty);
    });
  });

  test('the boss escaping ends the battle after the warning', () {
    const piercer = WeaponDefinition(
      id: 'test.piercer',
      name: 'Piercer',
      type: WeaponType.heavyCannon,
      damage: 250,
      fireInterval: 0.1,
      projectileSpeed: 100,
    );
    final battle = newBattle(weapon: piercer);
    battle.resolveHit(projectileId: fireOnce(battle), componentId: cannonId);
    battle.resolveHit(projectileId: fireOnce(battle), componentId: armorId);
    // Core closed: 400 - 250 = 150 left, which is 25% of the 600 total.
    final warning = battle.resolveHit(
      projectileId: fireOnce(battle),
      componentId: coreId,
    );
    expect(warning.whereType<BossEscapeWarning>(), hasLength(1));
    final warnedAt = battle.elapsed;

    final events = <BattleEvent>[];
    for (var i = 0; i < 200 && battle.status == BattleStatus.inProgress; i++) {
      events.addAll(battle.update(0.05));
    }

    expect(events.whereType<BossEscaped>(), hasLength(1));
    expect(
      events.whereType<BattleCompleted>().single.outcome,
      BattleOutcome.bossEscaped,
    );
    expect(battle.elapsed - warnedAt, closeTo(5, 0.06));
  });
}
