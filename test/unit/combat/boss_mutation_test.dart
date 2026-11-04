import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_component_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_mutation.dart';

void main() {
  const sentinel = BossCatalog.sentinel;

  group('ArmorUpgrade', () {
    test('raises armor and hull parts of its zone by a quarter of their base '
        'integrity per level', () {
      final once = const ArmorUpgrade(BossZone.left).applyTo(sentinel);
      final twice = const ArmorUpgrade(BossZone.left).applyTo(once);

      expect(once.component('sentinel.hull_left').armorLevel, 2);
      expect(once.component('sentinel.hull_left').maxIntegrity, 88);
      expect(once.component('sentinel.hull_left').evolved, isTrue);
      expect(twice.component('sentinel.hull_left').armorLevel, 3);
      expect(twice.component('sentinel.hull_left').maxIntegrity, 105);
      expect(twice.component('sentinel.hull_right').armorLevel, 1);
    });

    test('never touches the core or weapons', () {
      final boss = const ArmorUpgrade(BossZone.center).applyTo(sentinel);

      expect(boss.component('sentinel.armor').armorLevel, 2);
      expect(boss.component('sentinel.armor').maxIntegrity, 125);
      expect(boss.component('sentinel.core').armorLevel, 1);
      expect(boss.component('sentinel.core').maxIntegrity, 400);
      expect(boss.component('sentinel.cannon').armorLevel, 1);
    });

    test('stops at the maximum level', () {
      const upgrade = ArmorUpgrade(BossZone.right);
      var boss = sentinel;
      while (upgrade.canApply(boss)) {
        boss = upgrade.applyTo(boss);
      }

      expect(
        boss.component('sentinel.hull_right').armorLevel,
        ArmorUpgrade.maxLevel,
      );
      expect(upgrade.applyTo(boss).components, boss.components);
    });
  });

  group('ExtraPlate', () {
    test('adds a plate below its zone that covers the uncovered parts', () {
      const plate = ExtraPlate(BossZone.left);
      final boss = plate.applyTo(sentinel);
      final added = boss.component(plate.plateId);
      final wing = boss.component('sentinel.hull_left');

      expect(added.kind, BossComponentKind.armor);
      expect(added.maxIntegrity, ExtraPlate.integrity);
      expect(added.zone, BossZone.left);
      expect(added.top, greaterThan(wing.bottom));
      expect(added.left, lessThan(wing.left));
      expect(added.right, greaterThan(wing.right));
      expect(wing.coveredBy, [plate.plateId]);
      expect(boss.component('sentinel.hull_right').coveredBy, isEmpty);
    });

    test('keeps the existing cover of parts that already had one', () {
      final boss = const ExtraPlate(BossZone.center).applyTo(sentinel);

      expect(boss.component('sentinel.core').coveredBy, ['sentinel.armor']);
      expect(boss.component('sentinel.armor').coveredBy, [
        'evolved.plate_center',
      ]);
    });

    test('a zone gets at most one plate', () {
      const plate = ExtraPlate(BossZone.left);
      final boss = plate.applyTo(sentinel);

      expect(plate.canApply(boss), isFalse);
      expect(plate.applyTo(boss).components, hasLength(6));
    });
  });

  group('CannonSplit', () {
    test('puts both cannons on the given side and keeps a single drop', () {
      final boss = const CannonSplit(BossZone.left).applyTo(sentinel);
      final cannons = [
        for (final part in boss.components)
          if (part.kind == BossComponentKind.cannon) part,
      ];

      expect(boss.components.where((c) => c.id == 'sentinel.cannon'), isEmpty);
      expect(cannons.map((c) => c.zone), [BossZone.left, BossZone.left]);
      expect(cannons.map((c) => c.id), [
        'evolved.cannon_left_inner',
        'evolved.cannon_left_outer',
      ]);
      expect(cannons.where((c) => c.dropItemId != null), hasLength(1));
      expect(
        cannons.singleWhere((c) => c.dropItemId != null).id,
        'evolved.cannon_left_inner',
      );
      expect(cannons.every((c) => c.evolved), isTrue);
      expect(cannons.every((c) => c.maxIntegrity == 100), isTrue);
    });

    test('a center split spreads the cannons under the two wings', () {
      final boss = const CannonSplit(BossZone.center).applyTo(sentinel);
      final cannons = [
        for (final part in boss.components)
          if (part.kind == BossComponentKind.cannon) part,
      ];

      expect(cannons.map((c) => c.zone), [BossZone.left, BossZone.right]);
      expect(cannons.map((c) => c.offsetX), containsAll([-76, 76]));
    });

    test('stops at two cannons', () {
      const split = CannonSplit(BossZone.left);
      final boss = split.applyTo(sentinel);

      expect(split.canApply(boss), isFalse);
      expect(split.applyTo(boss).components, boss.components);
    });

    test('both cannons fire on each volley', () {
      final boss = BossState(
        definition: const CannonSplit(BossZone.center).applyTo(sentinel),
        arena: ArenaBounds.standard,
      );
      final volleys = <Set<double>>[];
      for (final step in [1.5, 1.2, 1.2, 1.2]) {
        final update = boss.update(step, targetX: 180, targetY: 500);
        volleys.add({for (final shot in update.shots) shot.originX - boss.x});
      }

      expect(volleys, everyElement({-76, 76}));
    });

    group('weapon ladder', () {
      test('a surviving cannon gets faster, then hits harder, then stops', () {
        const faster = WeaponUpgrade(BossZone.center, faster: true);
        const harder = WeaponUpgrade(BossZone.center, faster: false);
        final quick = faster.applyTo(sentinel);
        final heavy = harder.applyTo(quick);

        expect(quick.component('sentinel.cannon').weaponLevel, 2);
        expect(heavy.component('sentinel.cannon').weaponLevel, 3);
        expect(harder.canApply(heavy), isFalse);
      });

      test(
        'a destroyed center cannon adds a brace and a second cannon there',
        () {
          final boss = const WeaponReinforcement(
            BossZone.center,
          ).applyTo(sentinel);
          final cannons = [
            for (final part in boss.components)
              if (part.kind == BossComponentKind.cannon) part,
          ];
          final added = boss.component('evolved.cannon_center');
          final brace = boss.component('evolved.brace_center');

          expect(cannons, hasLength(2));
          expect(added.zone, BossZone.center);
          expect(added.weaponLevel, 1);
          expect(added.dropItemId, isNull);
          expect(
            added.top,
            greaterThan(sentinel.component('sentinel.cannon').bottom),
          );
          expect(brace.kind, BossComponentKind.armor);
          expect(brace.maxIntegrity, WeaponReinforcement.braceIntegrity);
          expect(
            const WeaponReinforcement(BossZone.center).canApply(boss),
            isFalse,
          );
        },
      );
    });
  });
}
