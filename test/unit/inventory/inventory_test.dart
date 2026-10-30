import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/inventory/domain/inventory.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';

void main() {
  final blasterId = WeaponCatalog.blaster.id;
  final heavyId = WeaponCatalog.heavyCannon.id;

  group('Inventory', () {
    test('starts with the blaster only', () {
      expect(Inventory.starter().itemIds, {blasterId});
    });

    test('adding returns a new inventory with the item', () {
      final starter = Inventory.starter();

      final updated = starter.add(heavyId);

      expect(updated.contains(heavyId), isTrue);
      expect(starter.contains(heavyId), isFalse);
    });

    test('adding an owned item returns the same inventory', () {
      final starter = Inventory.starter();

      expect(identical(starter.add(blasterId), starter), isTrue);
    });
  });

  group('Loadout', () {
    test('starts with the blaster equipped', () {
      expect(Loadout.starter().weaponId, blasterId);
    });

    test('can equip an owned weapon', () {
      final inventory = Inventory.starter().add(heavyId);

      final loadout = Loadout.starter().equipWeapon(
        heavyId,
        inventory: inventory,
      );

      expect(loadout?.weaponId, heavyId);
    });

    test('cannot equip a weapon that is not owned', () {
      expect(
        Loadout.starter().equipWeapon(heavyId, inventory: Inventory.starter()),
        isNull,
      );
    });

    test('cannot equip an owned item that is not a weapon', () {
      final inventory = Inventory.starter().add('part.unknown');

      expect(
        Loadout.starter().equipWeapon('part.unknown', inventory: inventory),
        isNull,
      );
    });
  });
}
