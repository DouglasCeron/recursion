import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../boss_evolution/application/boss_intel_controller.dart';
import '../../boss_evolution/domain/boss_evolution.dart';
import '../../inventory/application/inventory_controller.dart';
import '../../progression/application/progress_controller.dart';
import '../../ship/domain/weapon_catalog.dart';
import '../application/battle_session.dart';
import '../domain/content/boss_catalog.dart';
import '../domain/entities/battle_state.dart';
import '../domain/entities/boss_modifiers.dart';
import '../domain/entities/boss_state.dart';
import '../domain/entities/dropped_item.dart';
import '../domain/events/battle_event.dart';

/// A battle against the boss with the given id, using the currently equipped
/// weapon. Adaptive bosses receive the countermeasures derived from enemy
/// intel at the moment the battle is created.
///
/// Collected drops are added to the inventory as soon as the battle confirms
/// the pickup; observer transmissions reach the enemy intel and the battle is
/// recorded in the player's progress when it ends.
final battleSessionProvider = Provider.autoDispose
    .family<BattleSession, String>((ref, bossId) {
      final boss = BossCatalog.byId(bossId) ?? BossCatalog.sentinel;
      final weapon = ref.read(inventoryControllerProvider).equippedWeapon;
      final modifiers = AdaptationRules.adaptiveBossIds.contains(boss.id)
          ? ref.read(bossEvolutionProvider).toModifiers()
          : BossModifiers.none;
      final session = BattleSession.boss(
        boss: boss,
        modifiers: modifiers,
        weapon: weapon,
      );
      final subscription = session.events.listen((event) {
        switch (event) {
          case ItemCollected():
            ref
                .read(inventoryControllerProvider.notifier)
                .collect(event.itemId);
          case ObserverTransmitted():
            ref
                .read(bossIntelControllerProvider.notifier)
                .receiveTransmission(event.stats);
          case BattleCompleted():
            ref
                .read(progressControllerProvider.notifier)
                .recordBattle(session.state.record);
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
    required this.observerIntegrity,
    required this.observerMaxIntegrity,
    required this.intelTransmitted,
    required this.hasCoreShield,
    required this.coreShielded,
    required this.shieldBreakTimeLeft,
    required this.weaponDamageMultiplier,
    required this.coreWindowOpenDuration,
    required this.coreWindowShortened,
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
      observerIntegrity: battle.observer.integrity,
      observerMaxIntegrity: battle.observer.maxIntegrity,
      intelTransmitted: battle.intelTransmitted,
      hasCoreShield: boss.definition.hasCoreShield,
      coreShielded: boss.isCoreShielded,
      shieldBreakTimeLeft: boss.shieldBreakTimeLeft,
      weaponDamageMultiplier: boss.modifiers.damageMultiplierFor(
        battle.ship.weapon.type,
      ),
      coreWindowOpenDuration: boss.coreWindow.openDuration,
      coreWindowShortened: boss.modifiers.coreWindowOpenDuration != null,
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
  final int observerIntegrity;
  final int observerMaxIntegrity;
  final bool intelTransmitted;
  final bool hasCoreShield;
  final bool coreShielded;
  final double shieldBreakTimeLeft;

  /// Damage multiplier the boss applies to the equipped weapon (1 = none).
  final double weaponDamageMultiplier;
  final double coreWindowOpenDuration;
  final bool coreWindowShortened;

  double get hullRatio => hull / maxHull;
  bool get observerDestroyed => observerIntegrity == 0;

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
