import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_modifiers.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

void main() {
  const arena = ArenaBounds.standard;
  const warden = BossCatalog.warden;
  const coreId = 'warden.core';
  const leftId = 'warden.cannon_left';
  const rightId = 'warden.cannon_right';

  var nextProjectile = 0;
  BossState newWarden([BossModifiers modifiers = BossModifiers.none]) =>
      BossState(definition: warden, arena: arena, modifiers: modifiers);

  BossComponentHit hit(
    BossState boss,
    String id,
    int damage, {
    WeaponType type = WeaponType.blaster,
  }) => boss
      .applyHit(
        componentId: id,
        projectileId: nextProjectile++,
        baseDamage: damage,
        weaponType: type,
      )!
      .whereType<BossComponentHit>()
      .single;

  BossUpdate tick(BossState boss, double dt) =>
      boss.update(dt, targetX: arena.width / 2, targetY: arena.height - 50);

  group('core shield', () {
    test('blocks all core damage while both cannons work', () {
      final boss = newWarden();

      final blocked = hit(boss, coreId, 50);

      expect(boss.isCoreShielded, isTrue);
      expect(blocked.blocked, isTrue);
      expect(blocked.damage, 0);
      expect(boss.component(coreId)!.integrity, 360);
    });

    test('drops for 3s when a cannon is destroyed, then returns', () {
      final boss = newWarden();

      final events = boss.applyHit(
        componentId: leftId,
        projectileId: nextProjectile++,
        baseDamage: 1000,
        weaponType: WeaponType.blaster,
      )!;

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
      hit(boss, leftId, 1000);

      final events = boss.applyHit(
        componentId: rightId,
        projectileId: nextProjectile++,
        baseDamage: 1000,
        weaponType: WeaponType.blaster,
      )!;

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

  test('cannons fire in turns from both sides', () {
    final boss = newWarden();

    final first = tick(boss, warden.initialAttackDelay).shots.single;
    final second = tick(boss, warden.aimedShot.interval).shots.single;

    expect(first.originX, lessThan(boss.x));
    expect(second.originX, greaterThan(boss.x));
  });

  group('modifiers', () {
    const plating = BossModifiers(
      damageMultipliers: {WeaponType.heavyCannon: 0.6},
      coreWindowOpenDuration: 2,
    );

    test('reduce damage only for the countered weapon type', () {
      final boss = newWarden(plating);

      final heavy = hit(boss, leftId, 50, type: WeaponType.heavyCannon);
      final blaster = hit(boss, rightId, 50);

      expect(heavy.damage, 30);
      expect(heavy.resisted, isTrue);
      expect(blaster.damage, 50);
      expect(blaster.resisted, isFalse);
    });

    test('an exposed core always takes full doubled damage', () {
      final boss = newWarden(plating);
      hit(boss, leftId, 1000);
      hit(boss, rightId, 1000);
      while (!boss.isCoreVulnerable) {
        tick(boss, 0.05);
      }

      final exposed = hit(boss, coreId, 10, type: WeaponType.heavyCannon);

      expect(exposed.damage, 20);
      expect(exposed.resisted, isFalse);
    });

    test('a closed core still resists the countered weapon', () {
      final boss = newWarden(plating);
      hit(boss, leftId, 1000);
      hit(boss, rightId, 1000);

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
}
