import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/battle_record.dart';

/// Which boss must have been fought (any outcome) before another unlocks.
abstract final class BossUnlockRules {
  static final requirements = <String, String>{
    BossCatalog.warden.id: BossCatalog.sentinel.id,
  };
}

/// The player's progress across battles.
class PlayerProgress {
  const PlayerProgress({
    this.battlesFought = 0,
    this.foughtBossIds = const {},
    this.lastBattle,
  });

  final int battlesFought;

  /// Bosses the player has completed at least one battle against.
  final Set<String> foughtBossIds;
  final BattleRecord? lastBattle;

  bool isBossUnlocked(String bossId) {
    final required = BossUnlockRules.requirements[bossId];
    return required == null || foughtBossIds.contains(required);
  }

  PlayerProgress recordBattle(BattleRecord record) => PlayerProgress(
    battlesFought: battlesFought + 1,
    foughtBossIds: Set.unmodifiable({...foughtBossIds, record.bossId}),
    lastBattle: record,
  );
}
