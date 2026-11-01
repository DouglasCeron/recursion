import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/domain/boss_evolution.dart';
import 'package:recursion/features/boss_evolution/domain/boss_intel.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/combat_log.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

final sentinel = BossCatalog.sentinel.id;
final mk2 = BossCatalog.sentinelMk2.id;

WeaponExposureProfile profileWith(
  Map<BossZone, int> zoneDamage, {
  Map<WeaponType, int> damageByType = const {WeaponType.blaster: 100},
}) => WeaponExposureProfile.fromStats(
  CombatStats(
    weapons: {
      for (final MapEntry(key: type, value: damage) in damageByType.entries)
        type: WeaponUsage(shots: 10, hits: 10, damage: damage),
    },
    coreDamage: 100,
    coreDamageWhileExposed: 100,
    zoneDamage: zoneDamage,
  ),
);

BossIntel intelFrom(String bossId, Map<BossZone, int> zoneDamage) =>
    const BossIntel().withReport(profileWith(zoneDamage), bossId: bossId);

BossEvolutionState evolveMk2(BossIntel intel) =>
    AdaptationRules.evolve(intel, bossId: mk2);

void main() {
  test('every boss after the first adapts', () {
    expect(AdaptationRules.adaptiveBossIds, {
      for (final boss in BossCatalog.all.skip(1)) boss.id,
    });
    expect(AdaptationRules.adaptiveBossIds, isNot(contains(sentinel)));
  });

  test('each boss evolves from the previous one in the campaign', () {
    expect(AdaptationRules.previousBossOf(mk2), sentinel);
    expect(AdaptationRules.previousBossOf(sentinel), isNull);
    expect(AdaptationRules.previousBossOf('boss.removed'), isNull);
  });

  test('the first boss never adapts, even with intel', () {
    final evolution = AdaptationRules.evolve(
      intelFrom(sentinel, {BossZone.center: 100}),
      bossId: sentinel,
    );

    expect(evolution.isEmpty, isTrue);
    expect(evolution.toModifiers().isAdapted, isFalse);
  });

  test('no intel means no countermeasures', () {
    final evolution = evolveMk2(const BossIntel());

    expect(evolution.isEmpty, isTrue);
    expect(evolution.basedOnReport, isNull);
    expect(evolution.previousBossId, sentinel);
    expect(evolution.toModifiers().isAdapted, isFalse);
  });

  group('zone focus', () {
    test('the most hit zone is reinforced from 45% of the damage', () {
      final evolution = evolveMk2(
        intelFrom(sentinel, {
          BossZone.left: 45,
          BossZone.center: 30,
          BossZone.right: 25,
        }),
      );

      final reinforcement = evolution.countermeasures.single;
      expect(reinforcement.kind, CountermeasureKind.zoneReinforcement);
      expect(reinforcement.zoneShare, 0.45);
      expect(evolution.basedOnReport, 1);
      final modifiers = evolution.toModifiers();
      expect(modifiers.reinforcement?.zone, BossZone.left);
      expect(modifiers.reinforcement?.integrityMultiplier, 1.5);
      expect(modifiers.reinforcement?.plateIntegrity, 80);
      expect(modifiers.isAdapted, isTrue);
    });

    test('spread damage below 45% reinforces nothing', () {
      final evolution = evolveMk2(
        intelFrom(sentinel, {
          BossZone.left: 44,
          BossZone.center: 30,
          BossZone.right: 26,
        }),
      );

      expect(evolution.basedOnReport, 1);
      expect(evolution.isEmpty, isTrue);
      expect(evolution.toModifiers().reinforcement, isNull);
    });

    test('only the latest battle against the previous boss counts', () {
      final intel = intelFrom(sentinel, {BossZone.left: 100})
          .withReport(profileWith({BossZone.right: 100}), bossId: sentinel)
          .withReport(profileWith({BossZone.center: 100}), bossId: mk2)
          .withReport(profileWith({BossZone.center: 100}));

      final evolution = evolveMk2(intel);

      expect(evolution.basedOnReport, 2);
      expect(evolution.toModifiers().reinforcement?.zone, BossZone.right);
    });
  });

  test('only the armor adapts, whatever weapons were used', () {
    final modifiers = evolveMk2(
      const BossIntel().withReport(
        profileWith(
          {BossZone.center: 100},
          damageByType: {WeaponType.heavyCannon: 1000},
        ),
        bossId: sentinel,
      ),
    ).toModifiers();

    expect(modifiers.damageMultipliers, isEmpty);
    expect(modifiers.coreWindowOpenDuration, isNull);
    expect(modifiers.reinforcement?.zone, BossZone.center);
  });
}
