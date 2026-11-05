import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/domain/boss_intel.dart';
import 'package:recursion/features/boss_evolution/domain/evolution_director.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_component_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_mutation.dart';

IntelReport reportOf(
  Map<BossZone, double> shares, {
  int sequence = 1,
  List<String> destroyedWeaponIds = const [],
}) => IntelReport(
  sequence: sequence,
  profile: WeaponExposureProfile(
    weapons: const {},
    weakPointFocus: null,
    zoneShares: shares,
    destroyedWeaponIds: destroyedWeaponIds,
  ),
);

List<(Type, BossZone)> mutationsOf(Iterable<BossMutation> mutations) => [
  for (final m in mutations) (m.runtimeType, m.zone),
];

void main() {
  const sentinel = BossCatalog.sentinel;

  test('without a report the next boss changes nothing', () {
    final generation = EvolutionDirector.next(sentinel, null);

    expect(generation.steps, isEmpty);
    expect(generation.basedOnReport, isNull);
  });

  test('only zones above the threshold evolve, the most hit first', () {
    final generation = EvolutionDirector.next(
      sentinel,
      reportOf({
        BossZone.left: 0.5,
        BossZone.right: 0.31,
        BossZone.center: 0.19,
      }),
    );

    expect(mutationsOf(generation.steps.map((s) => s.mutation)), [
      (ArmorUpgrade, BossZone.left),
      (ExtraPlate, BossZone.left),
      (ArmorUpgrade, BossZone.right),
      (WeaponUpgrade, BossZone.left),
    ]);
    expect(generation.steps.first.zoneShare, 0.5);
    expect(generation.basedOnReport, 1);
  });

  test('never spends more than the budget', () {
    final generation = EvolutionDirector.next(
      sentinel,
      reportOf({
        BossZone.left: 0.34,
        BossZone.center: 0.33,
        BossZone.right: 0.33,
      }),
    );

    expect(
      generation.steps.where((s) => s.mutation is! WeaponUpgrade),
      hasLength(EvolutionDirector.budget),
    );
    expect(generation.steps.last.mutation, isA<WeaponUpgrade>());
  });

  test('keeps upgrading the same zone, plate included, until it is maxed '
      'out', () {
    final report = reportOf({BossZone.left: 1});
    var boss = sentinel;
    final perGeneration = <List<(Type, BossZone)>>[];
    for (var i = 0; i < 4; i++) {
      final generation = EvolutionDirector.next(boss, report);
      perGeneration.add(mutationsOf(generation.steps.map((s) => s.mutation)));
      for (final step in generation.steps) {
        boss = step.mutation.applyTo(boss);
      }
    }

    expect(perGeneration, [
      [
        (ArmorUpgrade, BossZone.left),
        (ExtraPlate, BossZone.left),
        (WeaponUpgrade, BossZone.left),
      ],
      [(ArmorUpgrade, BossZone.left), (WeaponUpgrade, BossZone.left)],
      [(ArmorUpgrade, BossZone.left), (AddedWeapon, BossZone.left)],
      [(ArmorUpgrade, BossZone.left), (AddedWeapon, BossZone.left)],
    ]);
    expect(boss.component('sentinel.cannon').weaponLevel, 3);
    expect(
      boss.components.map((c) => c.kind),
      containsAll([BossComponentKind.laser, BossComponentKind.missile]),
    );
    expect(boss.component('sentinel.hull_left').armorLevel, 5);
    expect(boss.component('evolved.plate_left').armorLevel, 4);
    expect(boss.component('evolved.plate_left').maxIntegrity, 140);
  });

  test('a destroyed cannon adds a brace and a second cannon on its side, '
      'without spending the armor budget', () {
    final generation = EvolutionDirector.next(
      sentinel,
      reportOf({BossZone.center: 1}, destroyedWeaponIds: ['sentinel.cannon']),
    );

    expect(mutationsOf(generation.steps.map((s) => s.mutation)), [
      (ArmorUpgrade, BossZone.center),
      (ExtraPlate, BossZone.center),
      (WeaponReinforcement, BossZone.center),
    ]);
    final boss = generation.steps.fold(
      sentinel,
      (b, s) => s.mutation.applyTo(b),
    );
    expect(
      boss.components.where((c) => c.kind == BossComponentKind.cannon),
      hasLength(2),
    );
    expect(boss.component('evolved.brace_center'), isNotNull);
  });

  test('a maxed zone spills the remaining budget onto the next zone', () {
    var boss = sentinel;
    final focused = reportOf({BossZone.left: 1});
    for (var i = 0; i < 6; i++) {
      for (final step in EvolutionDirector.next(boss, focused).steps) {
        boss = step.mutation.applyTo(boss);
      }
    }

    final generation = EvolutionDirector.next(
      boss,
      reportOf({BossZone.left: 0.9, BossZone.right: 0.1}),
    );

    expect(
      generation.steps.map((s) => s.mutation),
      containsAll([
        isA<ArmorUpgrade>().having((m) => m.zone, 'zone', BossZone.right),
        isA<ExtraPlate>().having((m) => m.zone, 'zone', BossZone.right),
      ]),
    );
  });

  test('a cannon destroyed on another boss does not reinforce this one', () {
    final generation = EvolutionDirector.next(
      sentinel,
      reportOf({BossZone.left: 1}, destroyedWeaponIds: ['evolved.cannon_left']),
    );

    expect(
      generation.steps.map((s) => s.mutation),
      isNot(contains(isA<WeaponReinforcement>())),
    );
  });

  test('the same boss and report always give the same evolution', () {
    final report = reportOf({BossZone.left: 0.5, BossZone.right: 0.5});

    final first = EvolutionDirector.next(sentinel, report);
    final second = EvolutionDirector.next(sentinel, report);

    expect(
      mutationsOf(first.steps.map((s) => s.mutation)),
      mutationsOf(second.steps.map((s) => s.mutation)),
    );
    expect(mutationsOf(first.steps.map((s) => s.mutation)), [
      (ArmorUpgrade, BossZone.left),
      (ArmorUpgrade, BossZone.right),
      (ExtraPlate, BossZone.left),
      (WeaponUpgrade, BossZone.left),
    ]);
  });
}
