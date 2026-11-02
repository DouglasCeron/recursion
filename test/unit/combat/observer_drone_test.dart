import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/entities/observer_drone.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

void main() {
  const arena = ArenaBounds.standard;

  ObserverDrone newDrone({int maxIntegrity = 60, int seed = 7}) =>
      ObserverDrone(arena: arena, maxIntegrity: maxIntegrity, seed: seed);

  test('records weapon usage and transmits it once', () {
    final drone = newDrone()
      ..observeShot(WeaponType.blaster)
      ..observeShot(WeaponType.blaster)
      ..observeHit(WeaponType.blaster, damage: 10);

    final stats = drone.transmit();

    final usage = stats!.weapons[WeaponType.blaster]!;
    expect(usage.shots, 2);
    expect(usage.hits, 1);
    expect(usage.damage, 10);
    expect(drone.hasTransmitted, isTrue);
    expect(drone.transmit(), isNull);
  });

  test('flees exactly once, after taking all its integrity', () {
    final drone = newDrone(maxIntegrity: 20);

    final first = drone.receiveDamage(10);
    final second = drone.receiveDamage(10);
    final third = drone.receiveDamage(10);

    expect(first.destroyedNow, isFalse);
    expect(second.destroyedNow, isTrue);
    expect(third.destroyedNow, isFalse);
    expect(drone.hasFled, isTrue);
  });

  test('a drone that fled still transmits what it saw before leaving', () {
    final drone = newDrone(maxIntegrity: 10)
      ..observeShot(WeaponType.blaster)
      ..receiveDamage(10)
      ..observeShot(WeaponType.heavyCannon);

    final stats = drone.transmit()!;

    expect(stats.weapons.keys, [WeaponType.blaster]);
    expect(stats.weapons[WeaponType.blaster]!.shots, 1);
  });

  test('each hit it survives sends it far away, along a side edge, '
      'below the boss', () {
    final drone = newDrone(maxIntegrity: 1000);
    var (x, y) = (drone.x, drone.y);

    for (var i = 0; i < 50; i++) {
      drone.receiveDamage(1);
      final jump = math.sqrt(
        math.pow(drone.x - x, 2) + math.pow(drone.y - y, 2),
      );
      expect(jump, greaterThanOrEqualTo(ObserverDrone.minJump), reason: '$i');
      expect(
        drone.x,
        anyOf(ObserverDrone.edgeMargin, arena.width - ObserverDrone.edgeMargin),
      );
      expect(
        drone.y,
        inInclusiveRange(
          arena.height * ObserverDrone.minYShare,
          arena.height * ObserverDrone.maxYShare,
        ),
      );
      (x, y) = (drone.x, drone.y);
    }
  });

  test('the same seed gives the same moves', () {
    List<(double, double)> movesOf(ObserverDrone drone) {
      final moves = <(double, double)>[];
      for (var i = 0; i < 5; i++) {
        drone.receiveDamage(1);
        moves.add((drone.x, drone.y));
      }
      return moves;
    }

    expect(movesOf(newDrone()), movesOf(newDrone()));
  });

  test('tracks core damage dealt while exposed', () {
    final drone = newDrone()
      ..observeHit(WeaponType.blaster, damage: 10, onCore: true)
      ..observeHit(
        WeaponType.blaster,
        damage: 20,
        onCore: true,
        coreExposed: true,
      )
      ..observeHit(WeaponType.blaster, damage: 10);

    final stats = drone.transmit()!;

    expect(stats.coreDamage, 30);
    expect(stats.coreDamageWhileExposed, 20);
    expect(stats.totalDamage, 40);
  });
}
