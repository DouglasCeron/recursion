import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/application/boss_intel_controller.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/progression/application/progress_controller.dart';

import '../../support/battle_driver.dart';

final _mk2 = BossCatalog.sentinelMk2.id;
const _mk2Order = ['sentinel_mk2.core'];

ProviderContainer newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a Sentinel battle unlocks the Mk II, reinforced where the player hit, '
      'and the Blaster can still beat it', () {
    final container = newContainer();
    expect(
      container.read(progressControllerProvider).isBossUnlocked(_mk2),
      isFalse,
    );

    playBattle(container);
    expect(
      container.read(progressControllerProvider).isBossUnlocked(_mk2),
      isTrue,
    );

    final (:session, :events) = playBattle(
      container,
      bossId: _mk2,
      targetOrder: _mk2Order,
    );

    final boss = session.state.boss;
    expect(boss.definition.name, 'Sentinel Mk II');
    expect(
      boss.modifiers.reinforcement?.zone,
      BossZone.center,
      reason: 'every Sentinel shot went to its center',
    );
    expect(boss.modifiers.damageMultipliers, isEmpty);
    expect(boss.modifiers.coreWindowOpenDuration, isNull);
    expect(boss.component('sentinel_mk2.armor')!.maxIntegrity, 150);
    expect(
      container.read(battleHudProvider(_mk2)).reinforcedZone,
      BossZone.center,
    );
    final destroyed = [
      for (final e in events.whereType<BossComponentDestroyed>()) e.componentId,
    ];
    expect(
      destroyed.indexOf('boss.sentinel_mk2.reinforcement_center'),
      lessThan(destroyed.indexOf('sentinel_mk2.armor')),
    );
    expect(session.state.outcome, BattleOutcome.victory);
    expect(container.read(progressControllerProvider).battlesFought, 2);
  });

  test('without transmitted intel the Mk II keeps its default armor', () {
    final container = newContainer();

    playBattle(container, shootObserver: true);

    final modifiers = container
        .read(battleSessionProvider(_mk2))
        .state
        .boss
        .modifiers;
    expect(modifiers.isAdapted, isFalse);
  });

  test('the Sentinel never adapts, even with intel', () {
    final container = newContainer();
    playBattle(container);

    final sentinel = container
        .read(battleSessionProvider(BossCatalog.sentinel.id))
        .state
        .boss;

    expect(sentinel.modifiers.isAdapted, isFalse);
  });

  test('a Mk II rematch learns from the Sentinel, not from the Mk II', () {
    final container = newContainer();
    playBattle(container);
    playBattle(container, bossId: _mk2, targetOrder: _mk2Order);

    final intel = container.read(bossIntelControllerProvider);
    expect(intel.reports.map((r) => r.bossId), [BossCatalog.sentinel.id, _mk2]);
    expect(container.read(bossEvolutionProvider(_mk2)).basedOnReport, 1);
  });
}
