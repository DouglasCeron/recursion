import '../../combat/domain/entities/battle_record.dart';
import '../../combat/domain/events/battle_event.dart';

/// The player's progress across battles. Which bosses exist (and so are
/// unlocked) is decided by the boss lineage, not here.
class PlayerProgress {
  const PlayerProgress({
    this.battlesFought = 0,
    this.foughtBossIds = const {},
    this.defeatedBossIds = const {},
    this.lastBattle,
  });

  final int battlesFought;

  /// Bosses the player has completed at least one battle against.
  final Set<String> foughtBossIds;

  /// Bosses the player has destroyed at least once.
  final Set<String> defeatedBossIds;
  final BattleRecord? lastBattle;

  bool isBossDefeated(String bossId) => defeatedBossIds.contains(bossId);

  PlayerProgress recordBattle(BattleRecord record) => PlayerProgress(
    battlesFought: battlesFought + 1,
    foughtBossIds: Set.unmodifiable({...foughtBossIds, record.bossId}),
    defeatedBossIds: record.outcome == BattleOutcome.victory
        ? Set.unmodifiable({...defeatedBossIds, record.bossId})
        : defeatedBossIds,
    lastBattle: record,
  );
}
