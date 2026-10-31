import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/domain/boss_evolution.dart';
import 'package:recursion/features/boss_evolution/domain/boss_intel.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/combat/domain/entities/combat_log.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

BossIntel intelWith(
  Map<WeaponType, int> damageByType, {
  int coreDamage = 0,
  int coreDamageWhileExposed = 0,
}) => const BossIntel().withReport(
  WeaponExposureProfile.fromStats(
    CombatStats(
      weapons: {
        for (final MapEntry(key: type, value: damage) in damageByType.entries)
          type: WeaponUsage(shots: 10, hits: 10, damage: damage),
      },
      coreDamage: coreDamage,
      coreDamageWhileExposed: coreDamageWhileExposed,
    ),
  ),
);

void main() {
  test('no intel means no countermeasures', () {
    final evolution = AdaptationRules.evolve(const BossIntel());

    expect(evolution.isEmpty, isTrue);
    expect(evolution.basedOnReport, isNull);
    expect(evolution.toModifiers().isAdapted, isFalse);
  });

  test('high heavy cannon exposure brings strong impact plating', () {
    final evolution = AdaptationRules.evolve(
      intelWith({WeaponType.heavyCannon: 900, WeaponType.blaster: 100}),
    );

    final plating = evolution.countermeasures.single;
    expect(plating.kind, CountermeasureKind.impactPlating);
    expect(plating.exposure, ExposureLevel.high);
    expect(plating.damageMultiplier, 0.6);
    expect(evolution.basedOnReport, 1);
  });

  test('medium exposure brings milder resistance to both weapons', () {
    final evolution = AdaptationRules.evolve(
      intelWith({WeaponType.heavyCannon: 500, WeaponType.blaster: 500}),
    );

    final modifiers = evolution.toModifiers();
    expect(modifiers.damageMultiplierFor(WeaponType.heavyCannon), 0.8);
    expect(modifiers.damageMultiplierFor(WeaponType.blaster), 0.85);
  });

  test('high blaster exposure brings a deflector screen', () {
    final evolution = AdaptationRules.evolve(
      intelWith({WeaponType.blaster: 1000}),
    );

    expect(
      evolution.countermeasures.single.kind,
      CountermeasureKind.deflectorScreen,
    );
    expect(
      evolution.toModifiers().damageMultiplierFor(WeaponType.blaster),
      0.7,
    );
  });

  test('low exposure and unused weapons are never countered', () {
    final evolution = AdaptationRules.evolve(
      intelWith({WeaponType.blaster: 950, WeaponType.heavyCannon: 50}),
    );

    final modifiers = evolution.toModifiers();
    expect(modifiers.damageMultiplierFor(WeaponType.heavyCannon), 1);
    expect(modifiers.damageMultiplierFor(WeaponType.laser), 1);
  });

  test('exploiting the weak point shortens the core window', () {
    final evolution = AdaptationRules.evolve(
      intelWith({}, coreDamage: 100, coreDamageWhileExposed: 70),
    );

    expect(
      evolution.countermeasures.single.kind,
      CountermeasureKind.shortenedCoreWindow,
    );
    expect(evolution.toModifiers().coreWindowOpenDuration, 2);
  });

  test('no countermeasure reduces damage by more than the cap', () {
    final evolution = AdaptationRules.evolve(
      intelWith({WeaponType.heavyCannon: 1000, WeaponType.blaster: 1}),
    );

    for (final c in evolution.countermeasures) {
      expect(
        c.damageReduction,
        lessThanOrEqualTo(AdaptationRules.maxDamageReduction),
      );
    }
  });

  test('only the latest report is used', () {
    final intel = intelWith({WeaponType.heavyCannon: 1000}).withReport(
      WeaponExposureProfile.fromStats(
        const CombatStats(
          weapons: {
            WeaponType.blaster: WeaponUsage(shots: 5, hits: 5, damage: 50),
          },
          coreDamage: 0,
          coreDamageWhileExposed: 0,
        ),
      ),
    );

    final evolution = AdaptationRules.evolve(intel);

    expect(evolution.basedOnReport, 2);
    expect(evolution.countermeasures.map((c) => c.kind), [
      CountermeasureKind.deflectorScreen,
    ]);
  });

  test('different usage profiles produce different configurations', () {
    final heavy = AdaptationRules.evolve(
      intelWith({WeaponType.heavyCannon: 1000}),
    ).toModifiers();
    final blaster = AdaptationRules.evolve(
      intelWith({WeaponType.blaster: 1000}),
    ).toModifiers();

    expect(heavy.damageMultipliers, {WeaponType.heavyCannon: 0.6});
    expect(blaster.damageMultipliers, {WeaponType.blaster: 0.7});
  });
}
