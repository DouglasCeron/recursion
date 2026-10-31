import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

void main() {
  const arena = ArenaBounds.standard;
  const sentinel = BossCatalog.sentinel;
  const coreId = 'sentinel.core';
  const armorId = 'sentinel.armor';
  const cannonId = 'sentinel.cannon';

  var nextProjectile = 0;
  BossState newBoss() => BossState(definition: sentinel, arena: arena);

  List<BattleEvent>? hit(BossState boss, String id, int damage) =>
      boss.applyHit(
        componentId: id,
        projectileId: nextProjectile++,
        baseDamage: damage,
        weaponType: WeaponType.blaster,
      );

  BossUpdate tick(BossState boss, double dt) =>
      boss.update(dt, targetX: arena.width / 2, targetY: arena.height - 50);

  group('attacks', () {
    test('waits for the initial delay, then fires an aimed shot', () {
      final boss = newBoss();

      expect(tick(boss, 1.4).shots, isEmpty);
      final shots = tick(boss, 0.2).shots;

      expect(shots, hasLength(1));
      final shot = shots.single;
      final speed = math.sqrt(
        shot.velocityX * shot.velocityX + shot.velocityY * shot.velocityY,
      );
      expect(speed, closeTo(sentinel.aimedShot.speed, 1e-6));
      expect(shot.velocityY, greaterThan(0), reason: 'aimed down at the ship');
      expect(shot.damage, sentinel.aimedShot.damage);
    });

    test('destroying the cannon switches to radial bursts, once', () {
      final boss = newBoss();

      final events = hit(boss, cannonId, 100)!;
      final again = hit(boss, cannonId, 100);

      expect(events.whereType<BossComponentDestroyed>(), hasLength(1));
      expect(
        events.whereType<BossBehaviorChanged>().single.pattern,
        BossAttackPattern.radialBurst,
      );
      expect(again, isNull);
      expect(boss.attackPattern, BossAttackPattern.radialBurst);

      final shots = tick(boss, sentinel.initialAttackDelay).shots;
      expect(shots, hasLength(sentinel.burst.count));
      expect(shots.every((s) => s.damage == sentinel.burst.damage), isTrue);
    });

    test('destroying the armor does not change behavior', () {
      final boss = newBoss();

      final events = hit(boss, armorId, 100)!;

      expect(events.whereType<BossBehaviorChanged>(), isEmpty);
      expect(boss.attackPattern, BossAttackPattern.aimedCannon);
    });

    test('losing the cannon makes the boss drift faster', () {
      final calm = newBoss();
      final enraged = newBoss();
      hit(enraged, cannonId, 100);

      tick(calm, 0.5);
      tick(enraged, 0.5);

      final center = arena.width / 2;
      expect((enraged.x - center).abs(), greaterThan((calm.x - center).abs()));
    });
  });

  group('core vulnerability window', () {
    test('core takes base damage while closed', () {
      final boss = newBoss();
      tick(boss, 1);

      final event = hit(boss, coreId, 10)!.whereType<BossComponentHit>().single;

      expect(boss.isCoreVulnerable, isFalse);
      expect(event.damage, 10);
      expect(event.weakPointBonus, isFalse);
    });

    test('core takes the multiplier only while exposed', () {
      final boss = newBoss();

      final opening = tick(boss, 5.5).events;
      final exposedHit = hit(
        boss,
        coreId,
        10,
      )!.whereType<BossComponentHit>().single;
      final closing = tick(boss, 3).events;
      final closedHit = hit(
        boss,
        coreId,
        10,
      )!.whereType<BossComponentHit>().single;

      expect(opening.whereType<WeakPointExposed>(), hasLength(1));
      expect(exposedHit.damage, 20);
      expect(exposedHit.weakPointBonus, isTrue);
      expect(closing.whereType<WeakPointClosed>(), hasLength(1));
      expect(closedHit.damage, 10);
    });

    test('other parts never receive the weak point bonus', () {
      final boss = newBoss();
      tick(boss, 5.5);

      final event = hit(
        boss,
        armorId,
        10,
      )!.whereType<BossComponentHit>().single;

      expect(event.damage, 10);
      expect(event.weakPointBonus, isFalse);
    });
  });

  group('escape', () {
    void bringToThreshold(BossState boss) {
      hit(boss, cannonId, 100);
      hit(boss, armorId, 100);
      // Total integrity: 600 max; 400 core left. 250 more reaches 150 (25%).
      hit(boss, coreId, 249);
    }

    test('is announced once when total integrity reaches 25%', () {
      final boss = newBoss();
      bringToThreshold(boss);
      expect(boss.phase, BossPhase.engaged);

      final events = hit(boss, coreId, 1)!;
      final later = hit(boss, coreId, 1)!;

      final warning = events.whereType<BossEscapeWarning>().single;
      expect(warning.secondsUntilEscape, 5);
      expect(later.whereType<BossEscapeWarning>(), isEmpty);
      expect(boss.phase, BossPhase.escaping);
    });

    test('happens only after the warning duration', () {
      final boss = newBoss();
      bringToThreshold(boss);
      hit(boss, coreId, 1);

      expect(tick(boss, 4.9).events.whereType<BossEscaped>(), isEmpty);
      expect(boss.phase, BossPhase.escaping);

      final events = tick(boss, 0.2).events;
      expect(events.whereType<BossEscaped>(), hasLength(1));
      expect(boss.phase, BossPhase.escaped);
      expect(tick(boss, 1).events, isEmpty);
      expect(hit(boss, coreId, 10), isNull);
    });

    test('defeating the core during the warning prevents the escape', () {
      final boss = newBoss();
      bringToThreshold(boss);
      hit(boss, coreId, 1);

      final events = hit(boss, coreId, 1000)!;

      expect(events.whereType<BossDefeated>(), hasLength(1));
      expect(boss.phase, BossPhase.defeated);
      expect(tick(boss, 10).events, isEmpty);
    });
  });

  test('unknown parts are ignored', () {
    expect(hit(newBoss(), 'nope', 10), isNull);
  });
}
