import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/domain/boss_intel.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/combat/domain/entities/combat_log.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

CombatStats statsWith(
  Map<WeaponType, WeaponUsage> weapons, {
  int coreDamage = 0,
  int coreDamageWhileExposed = 0,
}) => CombatStats(
  weapons: weapons,
  coreDamage: coreDamage,
  coreDamageWhileExposed: coreDamageWhileExposed,
);

void main() {
  group('classify', () {
    test('uses the documented damage share limits', () {
      expect(WeaponExposureProfile.classify(0), ExposureLevel.low);
      expect(WeaponExposureProfile.classify(0.149), ExposureLevel.low);
      expect(WeaponExposureProfile.classify(0.15), ExposureLevel.medium);
      expect(WeaponExposureProfile.classify(0.5), ExposureLevel.medium);
      expect(WeaponExposureProfile.classify(0.51), ExposureLevel.high);
    });
  });

  group('fromStats', () {
    test('only weapons that were fired appear', () {
      final profile = WeaponExposureProfile.fromStats(
        statsWith({
          WeaponType.blaster: const WeaponUsage(shots: 10, hits: 8, damage: 80),
        }),
      );

      expect(profile.weapons.keys, [WeaponType.blaster]);
      expect(profile.levelOf(WeaponType.heavyCannon), isNull);
      expect(profile.levelOf(WeaponType.blaster), ExposureLevel.high);
    });

    test('levels follow each weapon share of total damage', () {
      final profile = WeaponExposureProfile.fromStats(
        statsWith({
          WeaponType.blaster: const WeaponUsage(shots: 20, damage: 100),
          WeaponType.heavyCannon: const WeaponUsage(shots: 10, damage: 300),
          WeaponType.laser: const WeaponUsage(shots: 2, damage: 0),
        }),
      );

      expect(profile.weapons[WeaponType.blaster]!.damageShare, 0.25);
      expect(profile.levelOf(WeaponType.blaster), ExposureLevel.medium);
      expect(profile.levelOf(WeaponType.heavyCannon), ExposureLevel.high);
      expect(profile.levelOf(WeaponType.laser), ExposureLevel.low);
    });

    test('weapons fired without damage are low exposure', () {
      final profile = WeaponExposureProfile.fromStats(
        statsWith({WeaponType.blaster: const WeaponUsage(shots: 5)}),
      );

      expect(profile.levelOf(WeaponType.blaster), ExposureLevel.low);
    });

    test('weak point focus is the share of core damage while exposed', () {
      final focused = WeaponExposureProfile.fromStats(
        statsWith({}, coreDamage: 100, coreDamageWhileExposed: 60),
      );
      final careless = WeaponExposureProfile.fromStats(
        statsWith({}, coreDamage: 100, coreDamageWhileExposed: 20),
      );
      final untouched = WeaponExposureProfile.fromStats(statsWith({}));

      expect(focused.weakPointFocus, 0.6);
      expect(focused.exploitsWeakPoint, isTrue);
      expect(careless.exploitsWeakPoint, isFalse);
      expect(untouched.weakPointFocus, isNull);
      expect(untouched.exploitsWeakPoint, isFalse);
    });
  });

  group('BossIntel', () {
    test('accumulates reports in order and never forgets them', () {
      final profile = WeaponExposureProfile.fromStats(CombatStats.empty);

      final intel = const BossIntel().withReport(profile).withReport(profile);

      expect(intel.reports.map((r) => r.sequence), [1, 2]);
      expect(intel.latest!.sequence, 2);
      expect(const BossIntel().isEmpty, isTrue);
    });
  });
}
