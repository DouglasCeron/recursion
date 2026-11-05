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
/// generation. Zones under the threshold get the budget that a maxed zone
/// could not spend. The cannon ladder is separate: a cannon that survived
/// fires faster, then hits harder, and a cannon the observer saw destroyed
/// comes back with a brace and a second cannon on that side. Once every
/// cannon is at full power, the next generation adds a laser and the one
/// after that a missile.
abstract final class EvolutionDirector {
  static const budget = 3;
  static const zoneFocusThreshold = 0.3;

  /// Weight of each mutation relative to the zone share; higher goes first.
  static const _armorWeight = 1.0;
  static const _plateWeight = 0.9;

  static BossGeneration next(BossDefinition current, IntelReport? report) {
    if (report == null) return const BossGeneration();
    final steps = <EvolutionStep>[];
    var boss = current;
    for (final spill in [false, true]) {
      if (steps.length == budget) break;
      for (final candidate in _ranked(report, spill: spill)) {
        if (steps.length == budget) break;
        final mutation = candidate.mutation;
        if (!mutation.canApply(boss)) continue;
        boss = mutation.applyTo(boss);
        steps.add(candidate);
      }
    }
    final weapon = _weaponStep(boss, report);
    if (weapon != null) {
      steps.add(weapon);
    }
    return BossGeneration(
      steps: List.unmodifiable(steps),
      basedOnReport: report.sequence,
    );
  }

  static List<EvolutionStep> _ranked(
    IntelReport report, {
    required bool spill,
  }) {
    final candidates = <({double score, EvolutionStep step})>[];
    for (final zone in BossZone.values) {
      final share = report.profile.zoneShares[zone];
      if (share == null || share <= 0) continue;
      final focused = share >= zoneFocusThreshold;
      if (focused == spill) continue;
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
    return [for (final (_, candidate) in ranked) candidate.step];
  }

  /// One weapon change, on top of the armor budget. A destroyed cannon of
  /// [current] grows a brace and a second cannon on its side. Otherwise every
  /// cannon below the cap gains a level, and a cannon already at full power
  /// is followed by a laser and then a missile.
  static EvolutionStep? _weaponStep(
    BossDefinition current,
    IntelReport report,
  ) {
    final cannons = [
      for (final part in current.components)
        if (part.kind == BossComponentKind.cannon) part,
    ];
    BossComponentDefinition? fallen;
    for (final id in report.profile.destroyedWeaponIds) {
      for (final cannon in cannons) {
        if (cannon.id == id) fallen = cannon;
      }
    }
    if (fallen != null) {
      final reinforcement = WeaponReinforcement(fallen.zone);
      if (reinforcement.canApply(current)) {
        return EvolutionStep(
          mutation: reinforcement,
          zoneShare: report.profile.zoneShares[fallen.zone] ?? 0,
        );
      }
    }
    // No zone damage and no fallen cannon means the observer never saw the
    // boss, so its weapons do not evolve.
    if (report.profile.zoneShares.isEmpty) return null;
    final zone = _mostHit(report);
    final share = report.profile.zoneShares[zone] ?? 0;
    if (cannons.isNotEmpty) {
      final lowest = cannons
          .map((c) => c.weaponLevel)
          .reduce((a, b) => a < b ? a : b);
      if (lowest < WeaponUpgrade.maxLevel) {
        return EvolutionStep(
          mutation: WeaponUpgrade(zone, faster: lowest.isOdd),
          zoneShare: share,
        );
      }
    }
    for (final weapon in BossWeapon.values) {
      final added = AddedWeapon(zone, weapon);
      if (added.canApply(current)) {
        return EvolutionStep(mutation: added, zoneShare: share);
      }
    }
    return null;
  }

  /// Zone with the largest share. A tie goes to the center.
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
