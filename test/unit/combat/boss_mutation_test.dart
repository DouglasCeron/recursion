import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_component_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_mutation.dart';

void main() {
  const sentinel = BossCatalog.sentinel;

  group('ArmorUpgrade', () {
    test('raises armor and hull parts of its zone by half their base '
        'integrity per level', () {
      final once = const ArmorUpgrade(BossZone.left).applyTo(sentinel);
      final twice = const ArmorUpgrade(BossZone.left).applyTo(once);

      expect(once.component('sentinel.hull_left').armorLevel, 2);
      expect(once.component('sentinel.hull_left').maxIntegrity, 105);
      expect(once.component('sentinel.hull_left').evolved, isTrue);
      expect(twice.component('sentinel.hull_left').armorLevel, 3);
      expect(twice.component('sentinel.hull_left').maxIntegrity, 140);
      expect(twice.component('sentinel.hull_right').armorLevel, 1);
    });

    test('never touches the core or weapons', () {
      final boss = const ArmorUpgrade(BossZone.center).applyTo(sentinel);

      expect(boss.component('sentinel.armor').armorLevel, 2);
      expect(boss.component('sentinel.armor').maxIntegrity, 150);
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
}
