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
  final warden = BossCatalog.warden.id;

  test('the first boss is always unlocked; the Warden is not', () {
    const progress = PlayerProgress();

    expect(progress.isBossUnlocked(sentinel), isTrue);
    expect(progress.isBossUnlocked(warden), isFalse);
  });

  test('any finished Sentinel battle unlocks the Warden', () {
    for (final outcome in BattleOutcome.values) {
      final progress = const PlayerProgress().recordBattle(
        recordFor(sentinel, outcome),
      );

      expect(progress.isBossUnlocked(warden), isTrue, reason: '$outcome');
    }
  });

  test('the campaign follows the boss catalog order', () {
    expect(CampaignRules.order, [sentinel, warden]);
    expect(CampaignRules.requirementFor(sentinel), isNull);
    expect(CampaignRules.requirementFor(warden), sentinel);
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
    final record = recordFor(warden, BattleOutcome.victory);

    final progress = const PlayerProgress()
        .recordBattle(recordFor(sentinel, BattleOutcome.defeat))
        .recordBattle(record);

    expect(progress.battlesFought, 2);
    expect(progress.foughtBossIds, {sentinel, warden});
    expect(progress.lastBattle, same(record));
  });
}
