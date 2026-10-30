import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/battle_session.dart';
import '../domain/entities/battle_state.dart';

final battleSessionProvider = Provider.autoDispose<BattleSession>((ref) {
  final session = BattleSession.training();
  ref.onDispose(session.dispose);
  return session;
});

/// Snapshot of the battle shown by the Flutter HUD. Refreshed on battle
/// events rather than every frame.
class BattleHudState {
  const BattleHudState({
    required this.status,
    required this.weaponName,
    required this.shotsFired,
    required this.hitsLanded,
    required this.targetIntegrity,
    required this.targetMaxIntegrity,
  });

  factory BattleHudState.fromBattle(BattleState battle) {
    final targets = battle.targets;
    return BattleHudState(
      status: battle.status,
      weaponName: battle.ship.weapon.name,
      shotsFired: battle.shotsFired,
      hitsLanded: battle.hitsLanded,
      targetIntegrity: targets.fold(0, (sum, t) => sum + t.integrity),
      targetMaxIntegrity: targets.fold(0, (sum, t) => sum + t.maxIntegrity),
    );
  }

  final BattleStatus status;
  final String weaponName;
  final int shotsFired;
  final int hitsLanded;
  final int targetIntegrity;
  final int targetMaxIntegrity;

  double get targetIntegrityRatio =>
      targetMaxIntegrity == 0 ? 0 : targetIntegrity / targetMaxIntegrity;
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
