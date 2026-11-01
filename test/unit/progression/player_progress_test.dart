import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_record.dart';
import 'package:recursion/features/combat/domain/entities/combat_log.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/progression/domain/player_progress.dart';

BattleRecord recordFor(String bossId, BattleOutcome outcome) => BattleRecord(
  bossId: bossId,
  outcome: outcome,
  duration: 30,
  stats: CombatStats.empty,
  destroyedComponentIds: const [],
  collectedItemIds: const [],
  observerDestroyed: false,
  intelTransmitted: true,
);

void main() {
  final sentinel = BossCatalog.sentinel.id;
  final mk2 = BossCatalog.sentinelMk2.id;

  test('the first boss is always unlocked; the Sentinel Mk II is not', () {
    const progress = PlayerProgress();

    expect(progress.isBossUnlocked(sentinel), isTrue);
    expect(progress.isBossUnlocked(mk2), isFalse);
  });

  test('any finished Sentinel battle unlocks the Sentinel Mk II', () {
    for (final outcome in BattleOutcome.values) {
      final progress = const PlayerProgress().recordBattle(
        recordFor(sentinel, outcome),
      );

      expect(progress.isBossUnlocked(mk2), isTrue, reason: '$outcome');
    }
  });

  test('the campaign follows the boss catalog order', () {
    expect(CampaignRules.order, [sentinel, mk2]);
    expect(CampaignRules.requirementFor(sentinel), isNull);
    expect(CampaignRules.requirementFor(mk2), sentinel);
  });

  test('only a victory marks a boss as defeated', () {
    final lost = const PlayerProgress()
        .recordBattle(recordFor(sentinel, BattleOutcome.defeat))
        .recordBattle(recordFor(sentinel, BattleOutcome.bossEscaped));
    expect(lost.isBossDefeated(sentinel), isFalse);

    final won = lost.recordBattle(recordFor(sentinel, BattleOutcome.victory));
    expect(won.isBossDefeated(sentinel), isTrue);

    final lostAgain = won.recordBattle(
      recordFor(sentinel, BattleOutcome.defeat),
    );
    expect(lostAgain.isBossDefeated(sentinel), isTrue);
  });

  test('records count and the last battle', () {
    final record = recordFor(mk2, BattleOutcome.victory);

    final progress = const PlayerProgress()
        .recordBattle(recordFor(sentinel, BattleOutcome.defeat))
        .recordBattle(record);

    expect(progress.battlesFought, 2);
    expect(progress.foughtBossIds, {sentinel, mk2});
    expect(progress.lastBattle, same(record));
  });
}
