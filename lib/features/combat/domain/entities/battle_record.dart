import '../events/battle_event.dart';
import 'combat_log.dart';

/// Internal summary of what really happened in a battle, independent of what
/// the enemy observer managed to see or transmit.
class BattleRecord {
  const BattleRecord({
    required this.bossId,
    required this.outcome,
    required this.duration,
    required this.stats,
    required this.destroyedComponentIds,
    required this.collectedItemIds,
    required this.observerFled,
    required this.intelTransmitted,
  });

  final String bossId;
  final BattleOutcome? outcome;
  final double duration;
  final CombatStats stats;
  final List<String> destroyedComponentIds;
  final List<String> collectedItemIds;
  final bool observerFled;
  final bool intelTransmitted;
}
