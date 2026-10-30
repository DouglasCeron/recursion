import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/application/inventory_controller.dart';
import '../../ship/domain/weapon_catalog.dart';
import '../application/battle_session.dart';
import '../domain/entities/battle_state.dart';
import '../domain/entities/boss_state.dart';
import '../domain/entities/dropped_item.dart';
import '../domain/events/battle_event.dart';

/// A battle using the currently equipped weapon. Collected drops are added
/// to the inventory as soon as the battle confirms the pickup.
final battleSessionProvider = Provider.autoDispose<BattleSession>((ref) {
  final weapon = ref.read(inventoryControllerProvider).equippedWeapon;
  final session = BattleSession.boss(weapon: weapon);
  final subscription = session.events.listen((event) {
    if (event is ItemCollected) {
      ref.read(inventoryControllerProvider.notifier).collect(event.itemId);
    }
  });
  ref.onDispose(() {
    subscription.cancel();
    session.dispose();
  });
  return session;
});

class BossPartHud {
  const BossPartHud({
    required this.name,
    required this.integrity,
    required this.maxIntegrity,
  });

  final String name;
  final int integrity;
  final int maxIntegrity;

  bool get isDestroyed => integrity == 0;
  double get ratio => integrity / maxIntegrity;
}

/// Snapshot of the battle shown by the Flutter HUD. Refreshed on battle
/// events rather than every frame.
class BattleHudState {
  const BattleHudState({
    required this.status,
    required this.outcome,
    required this.weaponName,
    required this.hull,
    required this.maxHull,
    required this.bossName,
    required this.bossParts,
    required this.bossPattern,
    required this.coreVulnerable,
    required this.escapeTimeLeft,
    required this.availableDrop,
    required this.collectedItems,
    required this.lostItems,
  });

  factory BattleHudState.fromBattle(BattleState battle) {
    final boss = battle.boss;
    final available = battle.drops.where((d) => d.isAvailable);
    return BattleHudState(
      status: battle.status,
      outcome: battle.outcome,
      weaponName: battle.ship.weapon.name,
      hull: battle.ship.hull,
      maxHull: battle.ship.maxHull,
      bossName: boss.definition.name,
      bossParts: [
        for (final definition in boss.definition.components)
          BossPartHud(
            name: definition.name,
            integrity: boss.component(definition.id)!.integrity,
            maxIntegrity: definition.maxIntegrity,
          ),
      ],
      bossPattern: boss.attackPattern,
      coreVulnerable: boss.isCoreVulnerable,
      escapeTimeLeft: boss.phase == BossPhase.escaping
          ? boss.escapeTimeLeft
          : null,
      availableDrop: available.isEmpty
          ? null
          : (
              name: _itemName(available.first.itemId),
              timeLeft: available.first.timeLeft,
            ),
      collectedItems: battle.collectedItemIds.map(_itemName).toList(),
      lostItems: [
        for (final drop in battle.drops)
          if (drop.status == DropStatus.expired) _itemName(drop.itemId),
      ],
    );
  }

  final BattleStatus status;
  final BattleOutcome? outcome;
  final String weaponName;
  final int hull;
  final int maxHull;
  final String bossName;
  final List<BossPartHud> bossParts;
  final BossAttackPattern bossPattern;
  final bool coreVulnerable;

  /// Seconds until the boss escapes, or null when no escape is announced.
  final double? escapeTimeLeft;

  /// A drop waiting to be picked up, if any.
  final ({String name, double timeLeft})? availableDrop;
  final List<String> collectedItems;
  final List<String> lostItems;

  double get hullRatio => hull / maxHull;

  static String _itemName(String itemId) =>
      WeaponCatalog.byId(itemId)?.name ?? itemId;
}

final battleHudProvider =
    NotifierProvider.autoDispose<BattleHudController, BattleHudState>(
      BattleHudController.new,
    );

class BattleHudController extends Notifier<BattleHudState> {
  @override
  BattleHudState build() {
    final session = ref.watch(battleSessionProvider);
    final subscription = session.events.listen(
      (_) => state = BattleHudState.fromBattle(session.state),
    );
    ref.onDispose(subscription.cancel);
    return BattleHudState.fromBattle(session.state);
  }
}
