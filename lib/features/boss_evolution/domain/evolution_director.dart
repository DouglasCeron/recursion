import '../../combat/domain/entities/boss_definition.dart';
import '../../combat/domain/entities/boss_mutation.dart';
import 'boss_intel.dart';
import 'boss_lineage.dart';

/// Decides how the next boss evolves from the one just fought.
///
/// Deterministic: the same boss and report always give the same evolution.
/// Every zone that took at least [zoneFocusThreshold] of the observed damage
/// is a candidate; mutations are ranked by that share (armor upgrades before
/// extra plates) and applied while they are valid, up to [budget] per
/// generation. Upgrades accumulate, so a player who keeps hitting one side
/// keeps making that side stronger until it is maxed out.
abstract final class EvolutionDirector {
  static const budget = 3;
  static const zoneFocusThreshold = 0.3;

  /// Weight of each mutation relative to the zone share; higher goes first.
  static const _armorWeight = 1.0;
  static const _plateWeight = 0.9;

  static BossGeneration next(BossDefinition current, IntelReport? report) {
    if (report == null) return const BossGeneration();
    final candidates = <({double score, EvolutionStep step})>[];
    for (final zone in BossZone.values) {
      final share = report.profile.zoneShares[zone];
      if (share == null || share < zoneFocusThreshold) continue;
      for (final (mutation, weight) in [
        (ArmorUpgrade(zone), _armorWeight),
        (ExtraPlate(zone), _plateWeight),
      ]) {
        candidates.add((
          score: share * weight,
          step: EvolutionStep(mutation: mutation, zoneShare: share),
        ));
      }
    }
    final ranked =
        [
          for (final (index, candidate) in candidates.indexed)
            (index, candidate),
        ]..sort((a, b) {
          final byScore = b.$2.score.compareTo(a.$2.score);
          return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
        });

    var boss = current;
    final steps = <EvolutionStep>[];
    for (final (_, candidate) in ranked) {
      if (steps.length == budget) break;
      final mutation = candidate.step.mutation;
      if (!mutation.canApply(boss)) continue;
      boss = mutation.applyTo(boss);
      steps.add(candidate.step);
    }
    return BossGeneration(
      steps: List.unmodifiable(steps),
      basedOnReport: report.sequence,
    );
  }
}
