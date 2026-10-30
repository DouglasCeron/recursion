import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/ship/domain/ship_state.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';

void main() {
  const arena = ArenaBounds(width: 360, height: 640);

  ShipState newShip({double x = 180, double y = 500}) => ShipState(
    arena: arena,
    weapon: WeaponCatalog.blaster,
    maxSpeed: 100,
    halfWidth: 10,
    halfHeight: 10,
    x: x,
    y: y,
  );

  group('movement', () {
    test('moves toward the steering point at most maxSpeed per second', () {
      final ship = newShip()..steerBy(100, 0);

      ship.update(0.5);

      expect(ship.x, closeTo(230, 1e-9));
      expect(ship.y, 500);
    });

    test('stops exactly at the steering point', () {
      final ship = newShip()..steerBy(30, -40);

      ship.update(1);

      expect(ship.x, 210);
      expect(ship.y, 460);
    });

    test('steering point is clamped inside the arena', () {
      final ship = newShip()..steerBy(-1000, 1000);

      expect(ship.destinationX, 10);
      expect(ship.destinationY, 630);

      ship.update(100);
      expect(ship.x, 10);
      expect(ship.y, 630);
    });

    test('initial position is clamped inside the arena', () {
      final ship = newShip(x: -50, y: 9999);

      expect(ship.x, 10);
      expect(ship.y, 630);
    });
  });

  group('firing', () {
    test('fires immediately and then respects the weapon interval', () {
      final ship = newShip();
      final interval = WeaponCatalog.blaster.fireInterval;

      expect(ship.tryFire(), isTrue);
      expect(ship.tryFire(), isFalse);

      ship.update(interval / 2);
      expect(ship.tryFire(), isFalse);

      ship.update(interval / 2);
      expect(ship.tryFire(), isTrue);
    });
  });
}
