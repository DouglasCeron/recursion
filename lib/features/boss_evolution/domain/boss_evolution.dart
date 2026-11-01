import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/boss_definition.dart';
import '../../combat/domain/entities/boss_modifiers.dart';
import 'boss_intel.dart';
import 'weapon_exposure_profile.dart';

enum CountermeasureKind { zoneReinforcement }

/// One concrete adaptation of the next boss, with the intel that caused it.
class Countermeasure {
  const Countermeasure._({
    required this.kind,
    required this.reinforcement,
    required this.zoneShare,
  });

  final CountermeasureKind kind;

  /// Reinforced zone, and the share of observed damage that landed there.
  final ZoneReinforcement reinforcement;
  final double zoneShare;
}

/// Concrete configuration of the next boss, derived only from [BossIntel].
class BossEvolutionState {
  const BossEvolutionState({
    required this.basedOnReport,
    required this.countermeasures,
    this.previousBossId,
  });

  static const none = BossEvolutionState(
    basedOnReport: null,
    countermeasures: [],
  );

  /// Sequence of the intel report used, or null if the enemy had no intel.
  final int? basedOnReport;
  final List<Countermeasure> countermeasures;

  /// Boss whose battle the intel came from, if the boss adapts at all.
  final String? previousBossId;

  bool get isEmpty => countermeasures.isEmpty;

  BossModifiers toModifiers() => BossModifiers(
    reinforcement: countermeasures.map((c) => c.reinforcement).firstOrNull,
  );
}

/// Deterministic rules turning enemy intel into countermeasures.
///
/// Each boss evolves from the previous one in the campaign, using only the
/// latest report from a battle against that previous boss. Only its armor
/// adapts: the zone the player focused gets stronger structures and an extra
/// plate.
abstract final class AdaptationRules {
  /// Bosses that receive countermeasures: every boss after the first.
  static final adaptiveBossIds = {
    for (final boss in BossCatalog.all.skip(1)) boss.id,
  };

  /// The most hit zone is reinforced only if it took at least this share of
  /// the damage dealt to boss parts.
  static const zoneFocusThreshold = 0.45;

  /// Max integrity multiplier for the reinforced zone's structures (the core
  /// is not a structure and keeps its integrity).
  static const reinforcedIntegrityMultiplier = 1.5;

  /// Integrity of the extra plate in front of the reinforced zone.
  static const reinforcementPlateIntegrity = 80;

  /// The boss before [bossId] in the campaign, or null for the first boss
  /// and unknown ids.
  static String? previousBossOf(String bossId) {
    final index = BossCatalog.all.indexWhere((b) => b.id == bossId);
    return index < 1 ? null : BossCatalog.all[index - 1].id;
  }

  static BossEvolutionState evolve(BossIntel intel, {required String bossId}) {
    final previous = previousBossOf(bossId);
    if (previous == null) return BossEvolutionState.none;
    final report = intel.latestFrom(previous);
    if (report == null) {
      return BossEvolutionState(
        basedOnReport: null,
        countermeasures: const [],
        previousBossId: previous,
      );
    }
    return BossEvolutionState(
      basedOnReport: report.sequence,
      previousBossId: previous,
      countermeasures: [?_reinforce(report.profile)],
    );
  }

  static Countermeasure? _reinforce(WeaponExposureProfile profile) {
    MapEntry<BossZone, double>? focus;
    for (final zone in BossZone.values) {
      final share = profile.zoneShares[zone];
      if (share != null && share > (focus?.value ?? 0)) {
        focus = MapEntry(zone, share);
      }
    }
    if (focus == null || focus.value < zoneFocusThreshold) return null;
    return Countermeasure._(
      kind: CountermeasureKind.zoneReinforcement,
      reinforcement: ZoneReinforcement(
        zone: focus.key,
        integrityMultiplier: reinforcedIntegrityMultiplier,
        plateIntegrity: reinforcementPlateIntegrity,
      ),
      zoneShare: focus.value,
    );
  }
}
