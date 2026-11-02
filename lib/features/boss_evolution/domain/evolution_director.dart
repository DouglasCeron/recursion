import '../../combat/domain/entities/boss_component_state.dart';
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
/// generation. Destroying a cannon reserves one of those slots for a second
/// cannon, placed on the most hit side (or spread over the wings when the
/// center was hit most). Upgrades accumulate, so a player who keeps hitting
/// one side keeps making that side stronger until it is maxed out.
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

    final cannon = _cannonStep(current, report);
    var boss = current;
    final steps = <EvolutionStep>[];
    final room = budget - (cannon == null ? 0 : 1);
    for (final (_, candidate) in ranked) {
      if (steps.length == room) break;
      final mutation = candidate.step.mutation;
      if (!mutation.canApply(boss)) continue;
      boss = mutation.applyTo(boss);
      steps.add(candidate.step);
    }
    // Last, so an extra plate added above does not end up covering it.
    if (cannon != null && cannon.mutation.canApply(boss)) {
      steps.add(cannon);
    }
    return BossGeneration(
      steps: List.unmodifiable(steps),
      basedOnReport: report.sequence,
    );
  }

  /// A second cannon where the player hit most, when the observer saw a
  /// cannon of [current] destroyed. No zone data spreads them over the wings.
  static EvolutionStep? _cannonStep(
    BossDefinition current,
    IntelReport report,
  ) {
    final cannons = {
      for (final part in current.components)
        if (part.kind == BossComponentKind.cannon) part.id,
    };
    final sawOneFall = report.profile.destroyedWeaponIds.any(cannons.contains);
    if (!sawOneFall) return null;
    final split = CannonSplit(_mostHit(report));
    if (!split.canApply(current)) return null;
    return EvolutionStep(
      mutation: split,
      zoneShare: report.profile.zoneShares[split.zone] ?? 0,
    );
  }

  /// Zone with the largest share; a tie goes to the center, which spreads
  /// the cannons instead of stacking them.
  static BossZone _mostHit(IntelReport report) {
    final shares = report.profile.zoneShares;
    if (shares.isEmpty) return BossZone.center;
    var best = shares.entries.first;
    for (final entry in shares.entries.skip(1)) {
      final higher = entry.value > best.value;
      final tieToCenter =
          entry.value == best.value && entry.key == BossZone.center;
      if (higher || tieToCenter) best = entry;
    }
    return best.key;
  }
}
