import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/application/battle_session.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/inventory/application/inventory_controller.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

const _cannonId = 'sentinel.cannon';
final _sentinel = BossCatalog.sentinel.id;
const _step = 1 / 60;

/// Plays the current battle, hitting the cannon until it drops its item.
({BattleSession session, ItemDropped drop, List<BattleEvent> events})
breakCannon(ProviderContainer container) {
  container.listen(battleSessionProvider(_sentinel), (_, _) {});
  final session = container.read(battleSessionProvider(_sentinel));
  final events = <BattleEvent>[];
  session.events.listen(events.add);
  session.start();
  for (var frame = 0; frame < 60 * 60; frame++) {
    final before = events.length;
    session.update(_step);
    for (final shot in events.skip(before).whereType<WeaponFired>().toList()) {
      session.reportHit(
        projectileId: shot.projectileId,
        componentId: _cannonId,
      );
    }
    final drops = events.whereType<ItemDropped>();
    if (drops.isNotEmpty) {
      return (session: session, drop: drops.single, events: events);
    }
  }
  fail('the cannon never dropped its item');
}

void main() {
  final heavyId = WeaponCatalog.heavyCannon.id;

  test('not collecting the drop does not grant the item', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final (:session, :drop, :events) = breakCannon(container);

    for (var i = 0; i < (drop.lifetime / _step).ceil() + 1; i++) {
      session.update(_step);
    }

    expect(events.whereType<ItemExpired>(), hasLength(1));
    expect(
      container.read(inventoryControllerProvider).inventory.contains(heavyId),
      isFalse,
    );
  });

  test('collecting the drop adds it, and it can be equipped and used', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final (:session, :drop, events: _) = breakCannon(container);

    session.reportDropTouched(drop.dropId);
    session.reportDropTouched(drop.dropId);

    final inventory = container.read(inventoryControllerProvider);
    expect(inventory.inventory.contains(heavyId), isTrue);
    expect(inventory.ownedWeapons.where((w) => w.id == heavyId), hasLength(1));

    final equipped = container
        .read(inventoryControllerProvider.notifier)
        .equipWeapon(heavyId);
    expect(equipped, isTrue);

    container.invalidate(battleSessionProvider(_sentinel));
    final nextBattle = container.read(battleSessionProvider(_sentinel));
    final fired = <WeaponFired>[];
    nextBattle.events.listen((e) {
      if (e is WeaponFired) fired.add(e);
    });
    nextBattle
      ..start()
      ..update(_step);

    expect(nextBattle.state.ship.weapon.id, heavyId);
    expect(fired.single.weaponType, WeaponType.heavyCannon);
  });

  test('a weapon that was never collected cannot be equipped', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final equipped = container
        .read(inventoryControllerProvider.notifier)
        .equipWeapon(heavyId);

    expect(equipped, isFalse);
    expect(
      container.read(inventoryControllerProvider).equippedWeapon.id,
      WeaponCatalog.blaster.id,
    );
  });
}
