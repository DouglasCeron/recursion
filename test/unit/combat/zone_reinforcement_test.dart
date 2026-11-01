import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_component_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_modifiers.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/entities/observer_drone.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/ship/domain/ship_state.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

import '../../support/shielded_boss.dart';

const arena = ArenaBounds.standard;

BossState reinforcedMk2(BossZone zone) => BossState(
  definition: BossCatalog.sentinelMk2,
  arena: arena,
  modifiers: BossModifiers(
    reinforcement: ZoneReinforcement(
      zone: zone,
      integrityMultiplier: 1.5,
      plateIntegrity: 80,
    ),
  ),
);

/// The part that actually took a 1-damage hit aimed at [id].
String absorberOf(BossState boss, String id) => boss
    .applyHit(
      componentId: id,
      projectileId: 0,
      baseDamage: 1,
      weaponType: WeaponType.blaster,
    )!
    .whereType<BossComponentHit>()
    .single
    .componentId;

void main() {
  group('a reinforced zone', () {
    test('has stronger structures but the same core', () {
      final boss = reinforcedMk2(BossZone.center);

      expect(boss.component('sentinel_mk2.armor')!.maxIntegrity, 150);
      expect(boss.component('sentinel_mk2.cannon')!.maxIntegrity, 150);
      expect(boss.component('sentinel_mk2.core')!.maxIntegrity, 400);
      expect(boss.component('sentinel_mk2.hull_left')!.maxIntegrity, 70);
      expect(
        boss.definition.component('sentinel_mk2.armor').reinforced,
        isTrue,
      );
      expect(
        boss.definition.component('sentinel_mk2.core').reinforced,
        isFalse,
      );
    });

    test('gets an extra plate in front of its outer layer', () {
      final boss = reinforcedMk2(BossZone.center);
      const plateId = 'boss.sentinel_mk2.reinforcement_center';

      final plate = boss.definition.component(plateId);
      expect(plate.kind, BossComponentKind.armor);
      expect(plate.zone, BossZone.center);
      expect(boss.component(plateId)!.maxIntegrity, 80);
      expect(boss.isCovered('sentinel_mk2.armor'), isTrue);
      expect(boss.isCovered('sentinel_mk2.cannon'), isTrue);
      expect(absorberOf(boss, 'sentinel_mk2.core'), plateId);
    });

    test('works on the side zones too', () {
      final boss = reinforcedMk2(BossZone.left);
      const plateId = 'boss.sentinel_mk2.reinforcement_left';

      expect(boss.component('sentinel_mk2.hull_left')!.maxIntegrity, 105);
      expect(boss.component('sentinel_mk2.hull_right')!.maxIntegrity, 70);
      expect(absorberOf(boss, 'sentinel_mk2.hull_left'), plateId);
      expect(
        absorberOf(boss, 'sentinel_mk2.hull_right'),
        'sentinel_mk2.hull_right',
      );
    });

    test('keeps its plate inside the zone, below every part of it', () {
      for (final boss in [...BossCatalog.all, shieldedBoss]) {
        for (final zone in BossZone.values) {
          final reinforcement = ZoneReinforcement(
            zone: zone,
            integrityMultiplier: 1.5,
            plateIntegrity: 80,
          );
          final reinforced = reinforcement.applyTo(boss);
          final plate = reinforced.component(reinforcement.plateIdFor(boss));
          for (final part in boss.components) {
            if (part.zone == zone) {
              expect(plate.top, greaterThan(part.bottom));
            } else {
              final overlaps =
                  plate.left < part.right && part.left < plate.right;
              expect(overlaps, isFalse, reason: '${plate.id} vs ${part.id}');
            }
          }
        }
      }
    });

    test('leaves the catalog boss untouched without a reinforcement', () {
      final boss = BossState(definition: BossCatalog.sentinelMk2, arena: arena);

      expect(boss.definition, same(BossCatalog.sentinelMk2));
    });
  });

  group('damage per zone', () {
    test('is logged by the zone of the part that took the hit', () {
      final battle = BattleState(
        ship: ShipState(arena: arena, weapon: WeaponCatalog.blaster),
        boss: BossState(definition: BossCatalog.sentinelMk2, arena: arena),
      )..start();

      int fire() => battle
          .update(WeaponCatalog.blaster.fireInterval)
          .whereType<WeaponFired>()
          .single
          .projectileId;

      battle.resolveHit(
        projectileId: fire(),
        componentId: 'sentinel_mk2.hull_left',
      );
      battle.resolveHit(projectileId: fire(), componentId: 'sentinel_mk2.core');
      battle.resolveObserverHit(projectileId: fire());

      final zones = battle.record.stats.zoneDamage;
      expect(zones, {BossZone.left: 10, BossZone.center: 10});
    });

    test('is part of what the observer transmits', () {
      final observer = ObserverDrone()
        ..observeHit(WeaponType.blaster, damage: 10, zone: BossZone.right)
        ..observeHit(WeaponType.blaster, damage: 5);

      expect(observer.transmit()!.zoneDamage, {BossZone.right: 10});
    });
  });
}
