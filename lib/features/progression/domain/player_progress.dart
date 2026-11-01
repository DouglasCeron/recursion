import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/battle_record.dart';
import '../../combat/domain/events/battle_event.dart';

/// The campaign is a single path of bosses, in [BossCatalog.all] order.
///
/// A boss unlocks once the previous one has been fought, whatever the
/// outcome; the first one is always available.
abstract final class CampaignRules {
  static List<String> get order => [
    for (final boss in BossCatalog.all) boss.id,
  ];

  /// The boss that must be fought before [bossId], or null for the first.
  static String? requirementFor(String bossId) {
    final index = order.indexOf(bossId);
    return index > 0 ? order[index - 1] : null;
  }
}

/// The player's progress across battles.
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

  bool isBossUnlocked(String bossId) {
    final required = CampaignRules.requirementFor(bossId);
    return required == null || foughtBossIds.contains(required);
  }

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
