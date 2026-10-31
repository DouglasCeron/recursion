import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/inventory/application/inventory_controller.dart';
import 'package:recursion/features/progression/application/progress_controller.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

import '../../support/battle_driver.dart';

final _warden = BossCatalog.warden.id;
const _wardenOrder = [
  'warden.cannon_left',
  'warden.cannon_right',
  'warden.core',
];

ProviderContainer newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// Gives the player the Heavy Cannon without fighting for it.
void ownHeavyCannon(ProviderContainer container, {required bool equip}) {
  final inventory = container.read(inventoryControllerProvider.notifier);
  inventory.collect(WeaponCatalog.heavyCannon.id);
  if (equip) inventory.equipWeapon(WeaponCatalog.heavyCannon.id);
}

void main() {
  test('different weapon usage leads to different Warden setups', () {
    final blasterPlayer = newContainer();
    playBattle(blasterPlayer);

    final heavyPlayer = newContainer();
    ownHeavyCannon(heavyPlayer, equip: true);
    playBattle(heavyPlayer);

    final blasterWarden = blasterPlayer
        .read(battleSessionProvider(_warden))
        .state
        .boss
        .modifiers;
    final heavyWarden = heavyPlayer
        .read(battleSessionProvider(_warden))
        .state
        .boss
        .modifiers;

    expect(blasterWarden.damageMultipliers, {WeaponType.blaster: 0.7});
    expect(heavyWarden.damageMultipliers, {WeaponType.heavyCannon: 0.6});
  });

  test('owning a weapon without using it is never countered', () {
    final container = newContainer();
    ownHeavyCannon(container, equip: false);

    playBattle(container);

    final modifiers = container
        .read(battleSessionProvider(_warden))
        .state
        .boss
        .modifiers;
    expect(modifiers.damageMultiplierFor(WeaponType.heavyCannon), 1);
  });

  test('without transmitted intel the Warden does not adapt', () {
    final container = newContainer();

    playBattle(container, shootObserver: true);

    final modifiers = container
        .read(battleSessionProvider(_warden))
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

  test('a Sentinel battle unlocks the Warden, which can then be beaten', () {
    final container = newContainer();
    expect(
      container.read(progressControllerProvider).isBossUnlocked(_warden),
      isFalse,
    );

    playBattle(container);
    expect(
      container.read(progressControllerProvider).isBossUnlocked(_warden),
      isTrue,
    );

    final (:session, :events) = playBattle(
      container,
      bossId: _warden,
      targetOrder: _wardenOrder,
    );

    expect(events.whereType<CoreShieldDropped>(), hasLength(2));
    expect(events.whereType<BossComponentHit>().any((e) => e.resisted), isTrue);
    expect(session.state.boss.definition.id, _warden);
    expect(container.read(progressControllerProvider).battlesFought, 2);
  });
}
