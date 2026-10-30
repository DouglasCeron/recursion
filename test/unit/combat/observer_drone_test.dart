import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/entities/observer_drone.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

void main() {
  test('records weapon usage while alive and transmits it once', () {
    final drone = ObserverDrone()
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

  test('is destroyed exactly once', () {
    final drone = ObserverDrone(maxIntegrity: 20);

    final first = drone.receiveDamage(20);
    final second = drone.receiveDamage(20);

    expect(first.destroyedNow, isTrue);
    expect(second.destroyedNow, isFalse);
    expect(drone.isDestroyed, isTrue);
  });

  test('a destroyed drone records nothing and cannot transmit', () {
    final drone = ObserverDrone(maxIntegrity: 10)
      ..observeShot(WeaponType.blaster)
      ..receiveDamage(10)
      ..observeShot(WeaponType.heavyCannon);

    expect(drone.transmit(), isNull);
    expect(drone.hasTransmitted, isFalse);
  });

  test('tracks core damage dealt while exposed', () {
    final drone = ObserverDrone()
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
