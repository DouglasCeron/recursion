import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/application/boss_intel_controller.dart';
import 'package:recursion/features/boss_evolution/application/boss_lineage_controller.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_component_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_mutation.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/progression/application/progress_controller.dart';

import '../../support/battle_driver.dart';

const _gen2 = 'boss.sentinel.gen2';
const _centerPlate = 'evolved.plate_center';

ProviderContainer newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('fighting the latest boss evolves the next one where the player hit, '
      'and the Blaster can still beat it', () {
    final container = newContainer();
    expect(container.read(bossLineageControllerProvider).length, 1);

    playBattle(container);
    final lineage = container.read(bossLineageControllerProvider);
    expect(lineage.latestId, _gen2);
    expect(
      lineage.generations.last.steps.map((s) => s.mutation),
      [
        isA<ArmorUpgrade>().having((m) => m.zone, 'zone', BossZone.center),
        isA<ExtraPlate>().having((m) => m.zone, 'zone', BossZone.center),
      ],
      reason: 'every Sentinel shot went to its center',
    );

    final (:session, :events) = playBattle(container, bossId: _gen2);

    final boss = session.state.boss;
    expect(boss.definition.name, 'Sentinel Mk II');
    expect(boss.component('sentinel.armor')!.maxIntegrity, 150);
    expect(boss.component(_centerPlate), isNotNull);
    expect(container.read(battleHudProvider(_gen2)).evolutions, [
      'center armor Lv2',
      'center extra plate',
    ]);
    final destroyed = [
      for (final e in events.whereType<BossComponentDestroyed>()) e.componentId,
    ];
    expect(
      destroyed.indexOf(_centerPlate),
      lessThan(destroyed.indexOf('sentinel.armor')),
    );
    expect(session.state.outcome, BattleOutcome.victory);
    expect(container.read(progressControllerProvider).battlesFought, 2);
  });

  test('evolutions accumulate: the third boss builds on the second', () {
    final container = newContainer();
    playBattle(container);
    playBattle(container, bossId: _gen2);

    final lineage = container.read(bossLineageControllerProvider);
    expect(lineage.length, 3);
    expect(lineage.generations.last.basedOnReport, 2);
    final third = lineage.definitionOf(lineage.latestId)!;
    expect(third.name, 'Sentinel Mk III');
    expect(third.component('sentinel.armor').armorLevel, 3);
    expect(third.component('sentinel.armor').maxIntegrity, 200);
    expect(
      third.components.where((c) => c.id == _centerPlate),
      hasLength(1),
      reason: 'a zone gets at most one extra plate',
    );
    expect(third.component('sentinel.hull_left').armorLevel, 1);
  });

  test('an observer that flees before seeing boss damage leaves the next '
      'boss unchanged', () {
    final container = newContainer();

    playBattle(container, shootObserver: true);

    final lineage = container.read(bossLineageControllerProvider);
    expect(lineage.length, 2);
    expect(lineage.generations.last.steps, isEmpty);
    expect(lineage.generations.last.basedOnReport, 1);
  });

  test('destroying the cannon spreads two cannons over the wings', () {
    final container = newContainer();

    playBattle(
      container,
      targetOrder: const ['sentinel.cannon', 'sentinel.core'],
    );

    final next = container
        .read(bossLineageControllerProvider)
        .definitionOf(_gen2)!;
    final cannons = [
      for (final part in next.components)
        if (part.kind == BossComponentKind.cannon) part,
    ];

    expect(cannons.map((c) => c.zone), [BossZone.left, BossZone.right]);
    expect(cannons.where((c) => c.dropItemId != null), hasLength(1));
    expect(next.components.where((c) => c.id == 'sentinel.cannon'), isEmpty);
  });

  test('replaying an older boss does not grow the lineage', () {
    final container = newContainer();
    playBattle(container);
    playBattle(container);

    expect(container.read(bossLineageControllerProvider).length, 2);
    final sentinel = container
        .read(battleSessionProvider(BossCatalog.sentinel.id))
        .state
        .boss;
    expect(sentinel.definition.components, BossCatalog.sentinel.components);
    expect(container.read(bossIntelControllerProvider).reports, hasLength(2));
  });
}
