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

    expect(generation.steps, hasLength(EvolutionDirector.budget));
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
      [(ArmorUpgrade, BossZone.left), (ExtraPlate, BossZone.left)],
      [(ArmorUpgrade, BossZone.left)],
      [(ArmorUpgrade, BossZone.left)],
      isEmpty,
    ]);
    expect(boss.component('sentinel.hull_left').armorLevel, 3);
    expect(boss.component('evolved.plate_left').armorLevel, 3);
    expect(boss.component('evolved.plate_left').maxIntegrity, 160);
  });

  test('a destroyed cannon takes one budget slot and goes to the most hit '
      'side', () {
    final generation = EvolutionDirector.next(
      sentinel,
      reportOf(
        {BossZone.left: 0.8, BossZone.center: 0.2},
        destroyedWeaponIds: ['sentinel.cannon'],
      ),
    );

    expect(mutationsOf(generation.steps.map((s) => s.mutation)), [
      (ArmorUpgrade, BossZone.left),
      (ExtraPlate, BossZone.left),
      (CannonSplit, BossZone.left),
    ]);
    final boss = generation.steps.fold(
      sentinel,
      (b, s) => s.mutation.applyTo(b),
    );
    expect(
      boss.components
          .where((c) => c.kind == BossComponentKind.cannon)
          .map((c) => c.zone),
      [BossZone.left, BossZone.left],
    );
  });

  test('when the center was hit most, the cannons spread over the wings', () {
    final generation = EvolutionDirector.next(
      sentinel,
      reportOf(
        {BossZone.center: 0.6, BossZone.left: 0.4},
        destroyedWeaponIds: ['sentinel.cannon'],
      ),
    );

    expect(
      generation.steps.last.mutation,
      isA<CannonSplit>().having((m) => m.zone, 'zone', BossZone.center),
    );
  });

  test('a cannon destroyed on another boss does not split this one', () {
    final generation = EvolutionDirector.next(
      sentinel,
      reportOf({BossZone.left: 1}, destroyedWeaponIds: ['evolved.cannon_left']),
    );

    expect(
      generation.steps.map((s) => s.mutation),
      isNot(contains(isA<CannonSplit>())),
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
    ]);
  });
}
