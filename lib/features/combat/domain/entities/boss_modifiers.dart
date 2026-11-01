import 'dart:math' as math;

import '../../../ship/domain/weapon_definition.dart';
import 'boss_component_state.dart';
import 'boss_definition.dart';

/// Extra protection on one zone of the boss.
class ZoneReinforcement {
  const ZoneReinforcement({
    required this.zone,
    required this.integrityMultiplier,
    required this.plateIntegrity,
  });

  final BossZone zone;

  /// Applied to the max integrity of every non-core part in [zone].
  final double integrityMultiplier;

  /// Integrity of the extra plate placed in front of [zone].
  final int plateIntegrity;

  static const plateHeight = 8.0;
  static const plateGap = 2.0;
  static const plateMargin = 2.0;

  String plateIdFor(BossDefinition boss) =>
      '${boss.id}.reinforcement_${zone.name}';

  /// [boss] with stronger parts in [zone] and an extra plate just below
  /// them, covering every part of the zone that had no cover yet.
  BossDefinition applyTo(BossDefinition boss) {
    final zoneParts = [
      for (final c in boss.components)
        if (c.zone == zone) c,
    ];
    if (zoneParts.isEmpty) return boss;

    final plateId = plateIdFor(boss);
    final left = zoneParts.map((c) => c.left).reduce(math.min) - plateMargin;
    final right = zoneParts.map((c) => c.right).reduce(math.max) + plateMargin;
    final bottom = zoneParts.map((c) => c.bottom).reduce(math.max);
    final plate = BossComponentDefinition(
      id: plateId,
      name: 'Reinforcement plate',
      kind: BossComponentKind.armor,
      maxIntegrity: plateIntegrity,
      offsetX: (left + right) / 2,
      offsetY: bottom + plateGap + plateHeight / 2,
      width: right - left,
      height: plateHeight,
      reinforced: true,
    );
    return boss.copyWith(
      components: [
        for (final c in boss.components)
          if (c.zone != zone)
            c
          else
            c.copyWith(
              maxIntegrity: c.kind == BossComponentKind.core
                  ? null
                  : (c.maxIntegrity * integrityMultiplier).round(),
              coveredBy: c.coveredBy.isEmpty ? [plateId] : null,
              reinforced: c.kind != BossComponentKind.core,
            ),
        plate,
      ],
    );
  }
}

/// Adjustments applied to a boss for one battle.
///
/// Combat only knows these neutral numbers; why they were chosen (enemy
/// intel and adaptation rules) lives in the boss evolution feature.
class BossModifiers {
  const BossModifiers({
    this.damageMultipliers = const {},
    this.coreWindowOpenDuration,
    this.reinforcement,
  });

  static const none = BossModifiers();

  /// Damage multiplier per weapon type for hits that do not land on an
  /// exposed core. Missing types take normal damage.
  final Map<WeaponType, double> damageMultipliers;

  /// Replaces how long the core stays exposed in each window, if set.
  final double? coreWindowOpenDuration;

  /// Zone that comes with stronger structures and an extra plate, if any.
  final ZoneReinforcement? reinforcement;

  bool get isAdapted =>
      damageMultipliers.values.any((m) => m < 1) ||
      coreWindowOpenDuration != null ||
      reinforcement != null;

  double damageMultiplierFor(WeaponType type) => damageMultipliers[type] ?? 1;
}
