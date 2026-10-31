import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/application/boss_intel_controller.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

import '../../support/battle_driver.dart';

void main() {
  test('a surviving observer makes the intel available afterwards', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    playBattle(container);

    final intel = container.read(bossIntelControllerProvider);
    expect(intel.reports, hasLength(1));
    final profile = intel.latest!.profile;
    expect(profile.levelOf(WeaponType.blaster), ExposureLevel.high);
    expect(profile.levelOf(WeaponType.heavyCannon), isNull);
  });

  test('destroying the observer keeps the new battle out of the intel, '
      'without erasing earlier reports', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    playBattle(container);
    playBattle(container, shootObserver: true);

    expect(container.read(bossIntelControllerProvider).reports, hasLength(1));
  });

  test('without any transmission the enemy knows nothing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    playBattle(container, shootObserver: true);

    expect(container.read(bossIntelControllerProvider).isEmpty, isTrue);
  });
}
