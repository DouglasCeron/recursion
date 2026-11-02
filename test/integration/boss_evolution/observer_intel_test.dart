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

  test('an observer that flees early still reports, but saw no boss '
      'damage, without erasing earlier reports', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    playBattle(container);
    playBattle(container, shootObserver: true);

    final reports = container.read(bossIntelControllerProvider).reports;
    expect(reports, hasLength(2));
    expect(reports.first.profile.zoneShares, isNotEmpty);
    expect(
      reports.last.profile.zoneShares,
      isEmpty,
      reason: 'every shot went to the observer until it fled',
    );
    expect(reports.last.profile.levelOf(WeaponType.blaster), isNotNull);
  });
}
