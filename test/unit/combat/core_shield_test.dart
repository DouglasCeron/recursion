import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/entities/boss_modifiers.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

import '../../support/shielded_boss.dart';

void main() {
  const arena = ArenaBounds.standard;
  const warden = shieldedBoss;
  const coreId = 'warden.core';
  const plateId = 'warden.plate';
  const leftId = 'warden.cannon_left';
  const leftHousingId = 'warden.housing_left';
  const rightId = 'warden.cannon_right';
  const rightHousingId = 'warden.housing_right';

  var nextProjectile = 0;
  BossState newWarden([BossModifiers modifiers = BossModifiers.none]) =>
      BossState(definition: warden, arena: arena, modifiers: modifiers);

  List<BattleEvent> shoot(
    BossState boss,
    String id,
    int damage, {
    WeaponType type = WeaponType.blaster,
  }) => boss.applyHit(
    componentId: id,
    projectileId: nextProjectile++,
    baseDamage: damage,
    weaponType: type,
  )!;

  BossComponentHit hit(
    BossState boss,
    String id,
    int damage, {
    WeaponType type = WeaponType.blaster,
  }) =>
      shoot(boss, id, damage, type: type).whereType<BossComponentHit>().single;

  /// Destroys [id] with one overwhelming shot, after breaking its covers.
  List<BattleEvent> destroy(BossState boss, String id) {
    for (final cover in warden.component(id).coveredBy) {
      if (!boss.component(cover)!.isDestroyed) destroy(boss, cover);
    }
    return shoot(boss, id, 10000);
  }

  BossUpdate tick(BossState boss, double dt) =>
      boss.update(dt, targetX: arena.width / 2, targetY: arena.height - 50);

  group('covers', () {
    test('a covered cannon passes hits to its housing', () {
      final boss = newWarden();

      final absorbed = hit(boss, leftId, 30);

      expect(boss.isCovered(leftId), isTrue);
      expect(absorbed.componentId, leftHousingId);
      expect(boss.component(leftHousingId)!.integrity, 50);
      expect(boss.component(leftId)!.integrity, 120);
    });

    test('destroying the housing exposes the cannon', () {
      final boss = newWarden();

      destroy(boss, leftHousingId);
      final direct = hit(boss, leftId, 30);

      expect(boss.isCovered(leftId), isFalse);
      expect(direct.componentId, leftId);
      expect(boss.component(leftId)!.integrity, 90);
    });

    test('the front plate takes core hits before the shield matters', () {
      final boss = newWarden();

      final absorbed = hit(boss, coreId, 40);

      expect(absorbed.componentId, plateId);
      expect(absorbed.blocked, isFalse);
      expect(boss.component(plateId)!.integrity, 60);
    });

    test('a cover takes the hit even if the shot overkills it', () {
      final boss = newWarden();

      final events = shoot(boss, leftId, 500);

      expect(
        events.whereType<BossComponentDestroyed>().single.componentId,
        leftHousingId,
      );
      expect(boss.component(leftId)!.integrity, 120);
    });
  });

  group('core shield', () {
    test('blocks all core damage while both cannons work', () {
      final boss = newWarden();
      destroy(boss, plateId);

      final blocked = hit(boss, coreId, 50);

      expect(boss.isCoreShielded, isTrue);
      expect(blocked.blocked, isTrue);
      expect(blocked.damage, 0);
      expect(boss.component(coreId)!.integrity, 360);
    });

    test('drops for 3s when a cannon is destroyed, then returns', () {
      final boss = newWarden();
      destroy(boss, plateId);

      final events = destroy(boss, leftId);

      expect(events.whereType<CoreShieldDropped>().single.duration, 3);
      expect(boss.isCoreShielded, isFalse);
      expect(hit(boss, coreId, 10).damage, 10);

      expect(tick(boss, 2.9).events.whereType<CoreShieldRestored>(), isEmpty);
      final restored = tick(boss, 0.2).events;
      expect(restored.whereType<CoreShieldRestored>(), hasLength(1));
      expect(boss.isCoreShielded, isTrue);
    });

    test('stays down for good once both cannons are destroyed', () {
      final boss = newWarden();
      destroy(boss, leftId);

      final events = destroy(boss, rightId);

      expect(events.whereType<CoreShieldDropped>().single.duration, isNull);
      expect(events.whereType<BossBehaviorChanged>(), hasLength(1));
      tick(boss, 10);
      expect(boss.isCoreShielded, isFalse);
    });

    test('the core is never exposed while shielded', () {
      final boss = newWarden();

      tick(boss, 5.5);

      expect(warden.coreWindow.isOpenAt(5.5), isTrue);
      expect(boss.isCoreVulnerable, isFalse);
    });
  });

  test('both cannons fire from their own side', () {
    final boss = newWarden();

    final shots = tick(boss, warden.initialAttackDelay).shots;

    expect(shots, hasLength(2));
    expect(
      shots.map((shot) => shot.originX > boss.x),
      containsAll([true, false]),
    );
  });

  group('modifiers', () {
    const plating = BossModifiers(
      damageMultipliers: {WeaponType.heavyCannon: 0.6},
      coreWindowOpenDuration: 2,
    );

    test('reduce damage only for the countered weapon type', () {
      final boss = newWarden(plating);

      final heavy = hit(boss, leftHousingId, 50, type: WeaponType.heavyCannon);
      final blaster = hit(boss, rightHousingId, 50);

      expect(heavy.damage, 30);
      expect(heavy.resisted, isTrue);
      expect(blaster.damage, 50);
      expect(blaster.resisted, isFalse);
    });

    test('an exposed core always takes full doubled damage', () {
      final boss = newWarden(plating);
      destroy(boss, plateId);
      destroy(boss, leftId);
      destroy(boss, rightId);
      for (var i = 0; i < 400 && !boss.isCoreVulnerable; i++) {
        tick(boss, 0.05);
      }
      expect(boss.isCoreVulnerable, isTrue);

      final exposed = hit(boss, coreId, 10, type: WeaponType.heavyCannon);

      expect(exposed.damage, 20);
      expect(exposed.resisted, isFalse);
    });

    test('a closed core still resists the countered weapon', () {
      final boss = newWarden(plating);
      destroy(boss, plateId);
      destroy(boss, leftId);
      destroy(boss, rightId);

      final closed = hit(boss, coreId, 10, type: WeaponType.heavyCannon);

      expect(boss.isCoreVulnerable, isFalse);
      expect(closed.damage, 6);
    });

    test('shorten the core exposure window', () {
      final adapted = newWarden(plating);
      final normal = newWarden();

      expect(adapted.coreWindow.openDuration, 2);
      expect(normal.coreWindow.openDuration, 3);
      expect(adapted.coreWindow.isOpenAt(5.5), isFalse);
      expect(adapted.coreWindow.isOpenAt(6.5), isTrue);
    });
  });

  test('parts know their zone from their position', () {
    expect(warden.component(leftId).zone.name, 'left');
    expect(warden.component(plateId).zone.name, 'center');
    expect(warden.component(rightHousingId).zone.name, 'right');
  });
}
