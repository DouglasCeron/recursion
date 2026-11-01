import 'dart:math' as math;

import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/boss_definition.dart';
import '../../combat/domain/entities/boss_modifiers.dart';
import '../../ship/domain/weapon_definition.dart';
import 'boss_intel.dart';
import 'weapon_exposure_profile.dart';

enum CountermeasureKind {
  impactPlating,
  deflectorScreen,
  shortenedCoreWindow,
  zoneReinforcement,
}

/// One concrete adaptation of the next boss, with the intel that caused it.
class Countermeasure {
  const Countermeasure._({
    required this.kind,
    this.weaponType,
    this.exposure,
    this.damageMultiplier,
    this.coreWindowOpenDuration,
    this.reinforcement,
    this.zoneShare,
  });

  final CountermeasureKind kind;

  /// Weapon type this countermeasure resists, and the exposure that
  /// triggered it.
  final WeaponType? weaponType;
  final ExposureLevel? exposure;
  final double? damageMultiplier;
  final double? coreWindowOpenDuration;

  /// Reinforced zone, and the share of observed damage that landed there.
  final ZoneReinforcement? reinforcement;
  final double? zoneShare;

  double? get damageReduction =>
      damageMultiplier == null ? null : 1 - damageMultiplier!;
}

/// Concrete configuration of the next boss, derived only from [BossIntel].
class BossEvolutionState {
  const BossEvolutionState({
    required this.basedOnReport,
    required this.countermeasures,
  });

  static const none = BossEvolutionState(
    basedOnReport: null,
    countermeasures: [],
  );

  /// Sequence of the intel report used, or null if the enemy had no intel.
  final int? basedOnReport;
  final List<Countermeasure> countermeasures;

  bool get isEmpty => countermeasures.isEmpty;

  BossModifiers toModifiers() => BossModifiers(
    damageMultipliers: {
      for (final c in countermeasures)
        if (c.weaponType != null && c.damageMultiplier != null)
          c.weaponType!: c.damageMultiplier!,
    },
    coreWindowOpenDuration: countermeasures
        .map((c) => c.coreWindowOpenDuration)
        .whereType<double>()
        .firstOrNull,
    reinforcement: countermeasures
        .map((c) => c.reinforcement)
        .nonNulls
        .firstOrNull,
  );
}

/// Deterministic rules turning enemy intel into countermeasures.
///
/// Only the latest report is used, so the boss reacts to the player's most
/// recent observed strategy. Weapons absent from the report are never
/// countered. Reductions are capped so no weapon becomes useless, and an
/// exposed core always takes full damage (enforced by the boss itself).
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

  /// Highest damage reduction any countermeasure may apply.
  static const maxDamageReduction = 0.4;

  /// Heavy projectiles → impact plating.
  static const impactPlating = {
    ExposureLevel.medium: 0.8,
    ExposureLevel.high: 0.6,
  };

  /// Rapid energy bolts → deflector screen.
  static const deflectorScreen = {
    ExposureLevel.medium: 0.85,
    ExposureLevel.high: 0.7,
  };

  /// Core exposure (seconds per window) when the player exploits it.
  static const shortenedCoreWindow = 2.0;

  static BossEvolutionState evolve(BossIntel intel) {
    final report = intel.latest;
    if (report == null) return BossEvolutionState.none;
    final profile = report.profile;
    return BossEvolutionState(
      basedOnReport: report.sequence,
      countermeasures: [
        ?_resist(
          CountermeasureKind.impactPlating,
          WeaponType.heavyCannon,
          profile,
          impactPlating,
        ),
        ?_resist(
          CountermeasureKind.deflectorScreen,
          WeaponType.blaster,
          profile,
          deflectorScreen,
        ),
        if (profile.exploitsWeakPoint)
          const Countermeasure._(
            kind: CountermeasureKind.shortenedCoreWindow,
            coreWindowOpenDuration: shortenedCoreWindow,
          ),
        ?_reinforce(profile),
      ],
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

  static Countermeasure? _resist(
    CountermeasureKind kind,
    WeaponType type,
    WeaponExposureProfile profile,
    Map<ExposureLevel, double> multipliers,
  ) {
    final level = profile.levelOf(type);
    final multiplier = level == null ? null : multipliers[level];
    if (level == null || multiplier == null) return null;
    return Countermeasure._(
      kind: kind,
      weaponType: type,
      exposure: level,
      damageMultiplier: math.max(multiplier, 1 - maxDamageReduction),
    );
  }
}
