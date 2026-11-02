import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boss_evolution/application/boss_intel_controller.dart';
import '../../boss_evolution/application/boss_lineage_controller.dart';
import '../../boss_evolution/domain/boss_lineage.dart';
import '../../inventory/application/inventory_controller.dart';
import '../../progression/application/progress_controller.dart';
import '../../ship/domain/weapon_catalog.dart';
import '../application/battle_session.dart';
import '../domain/entities/battle_state.dart';
import '../domain/entities/boss_state.dart';
import '../domain/entities/dropped_item.dart';
import '../domain/events/battle_event.dart';

/// A battle against the boss with the given id from the campaign lineage
/// (the latest boss for unknown ids), using the currently equipped weapon.
///
/// Collected drops are added to the inventory as soon as the battle confirms
/// the pickup; observer transmissions reach the enemy intel. When the battle
/// ends it is recorded in the player's progress, and fighting the latest
/// boss evolves the next one from what the observer transmitted.
final battleSessionProvider = Provider.autoDispose
    .family<BattleSession, String>((ref, bossId) {
      final lineage = ref.read(bossLineageControllerProvider);
      final boss =
          lineage.definitionOf(bossId) ??
          lineage.definitionOf(lineage.latestId)!;
      final weapon = ref.read(inventoryControllerProvider).equippedWeapon;
      final session = BattleSession.boss(boss: boss, weapon: weapon);
      final subscription = session.events.listen((event) {
        switch (event) {
          case ItemCollected():
            ref
                .read(inventoryControllerProvider.notifier)
                .collect(event.itemId);
          case ObserverTransmitted():
            ref
                .read(bossIntelControllerProvider.notifier)
                .receiveTransmission(event.stats, bossId: boss.id);
          case BattleCompleted():
            ref
                .read(progressControllerProvider.notifier)
                .recordBattle(session.state.record);
            ref
                .read(bossLineageControllerProvider.notifier)
                .onBattleCompleted(
                  boss.id,
                  session.state.intelTransmitted
                      ? ref.read(bossIntelControllerProvider).latest
                      : null,
                );
          default:
            break;
        }
      });
      ref.onDispose(() {
        subscription.cancel();
        session.dispose();
      });
      return session;
    });

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
    required this.bossPattern,
    required this.coreVulnerable,
    required this.escapeTimeLeft,
    required this.availableDrop,
    required this.collectedItems,
    required this.lostItems,
    required this.intelTransmitted,
    required this.hasCoreShield,
    required this.coreShielded,
    required this.shieldBreakTimeLeft,
    required this.weaponDamageMultiplier,
    required this.coreWindowOpenDuration,
    required this.coreWindowShortened,
    required this.evolutions,
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
      intelTransmitted: battle.intelTransmitted,
      hasCoreShield: boss.definition.hasCoreShield,
      coreShielded: boss.isCoreShielded,
      shieldBreakTimeLeft: boss.shieldBreakTimeLeft,
      weaponDamageMultiplier: boss.modifiers.damageMultiplierFor(
        battle.ship.weapon.type,
      ),
      coreWindowOpenDuration: boss.coreWindow.openDuration,
      coreWindowShortened: boss.modifiers.coreWindowOpenDuration != null,
      evolutions: evolutionSummary(boss.definition),
    );
  }

  final BattleStatus status;
  final BattleOutcome? outcome;
  final String weaponName;
  final int hull;
  final int maxHull;
  final String bossName;

  final BossAttackPattern bossPattern;
  final bool coreVulnerable;

  /// Seconds until the boss escapes, or null when no escape is announced.
  final double? escapeTimeLeft;

  /// A drop waiting to be picked up, if any.
  final ({String name, double timeLeft})? availableDrop;
  final List<String> collectedItems;
  final List<String> lostItems;
  final bool intelTransmitted;
  final bool hasCoreShield;
  final bool coreShielded;
  final double shieldBreakTimeLeft;

  /// Damage multiplier the boss applies to the equipped weapon (1 = none).
  final double weaponDamageMultiplier;
  final double coreWindowOpenDuration;
  final bool coreWindowShortened;

  /// Evolutions this boss carries, e.g. `left armor Lv2`.
  final List<String> evolutions;

  double get hullRatio => hull / maxHull;

  static String _itemName(String itemId) =>
      WeaponCatalog.byId(itemId)?.name ?? itemId;
}

final battleHudProvider = NotifierProvider.autoDispose
    .family<BattleHudController, BattleHudState, String>(
      BattleHudController.new,
    );

class BattleHudController extends Notifier<BattleHudState> {
  BattleHudController(this.bossId);

  final String bossId;

  @override
  BattleHudState build() {
    final session = ref.watch(battleSessionProvider(bossId));
    final subscription = session.events.listen(
      (_) => state = BattleHudState.fromBattle(session.state),
    );
    ref.onDispose(subscription.cancel);
    return BattleHudState.fromBattle(session.state);
  }
}
