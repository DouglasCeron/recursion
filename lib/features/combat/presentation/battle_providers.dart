import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/battle_session.dart';
import '../domain/entities/battle_state.dart';
import '../domain/entities/boss_state.dart';
import '../domain/events/battle_event.dart';

final battleSessionProvider = Provider.autoDispose<BattleSession>((ref) {
  final session = BattleSession.boss();
  ref.onDispose(session.dispose);
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
  });

  factory BattleHudState.fromBattle(BattleState battle) {
    final boss = battle.boss;
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

  double get hullRatio => hull / maxHull;
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
