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

const arena = ArenaBounds.standard;

BossState reinforcedWarden(BossZone zone) => BossState(
  definition: BossCatalog.warden,
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
      final boss = reinforcedWarden(BossZone.center);

      expect(boss.component('warden.plate')!.maxIntegrity, 150);
      expect(boss.component('warden.core')!.maxIntegrity, 360);
      expect(boss.component('warden.cannon_left')!.maxIntegrity, 120);
      expect(boss.definition.component('warden.plate').reinforced, isTrue);
      expect(boss.definition.component('warden.core').reinforced, isFalse);
    });

    test('gets an extra plate in front of its outer layer', () {
      final boss = reinforcedWarden(BossZone.center);
      const plateId = 'boss.warden.reinforcement_center';

      final plate = boss.definition.component(plateId);
      expect(plate.kind, BossComponentKind.armor);
      expect(plate.zone, BossZone.center);
      expect(boss.component(plateId)!.maxIntegrity, 80);
      expect(boss.isCovered('warden.plate'), isTrue);
      expect(absorberOf(boss, 'warden.core'), plateId);
    });

    test('works on the side zones too', () {
      final boss = reinforcedWarden(BossZone.left);
      const plateId = 'boss.warden.reinforcement_left';

      expect(boss.component('warden.housing_left')!.maxIntegrity, 120);
      expect(boss.component('warden.cannon_left')!.maxIntegrity, 180);
      expect(boss.component('warden.housing_right')!.maxIntegrity, 80);
      expect(absorberOf(boss, 'warden.cannon_left'), plateId);
      expect(absorberOf(boss, 'warden.cannon_right'), 'warden.housing_right');
    });

    test('keeps its plate inside the zone, below every part of it', () {
      for (final boss in BossCatalog.all) {
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
      final boss = BossState(definition: BossCatalog.warden, arena: arena);

      expect(boss.definition, same(BossCatalog.warden));
    });
  });

  group('damage per zone', () {
    test('is logged by the zone of the part that took the hit', () {
      final battle = BattleState(
        ship: ShipState(arena: arena, weapon: WeaponCatalog.blaster),
        boss: BossState(definition: BossCatalog.warden, arena: arena),
      )..start();

      int fire() => battle
          .update(WeaponCatalog.blaster.fireInterval)
          .whereType<WeaponFired>()
          .single
          .projectileId;

      battle.resolveHit(
        projectileId: fire(),
        componentId: 'warden.cannon_left',
      );
      battle.resolveHit(projectileId: fire(), componentId: 'warden.core');
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
