import 'dart:math' as math;

import 'boss_component_state.dart';
import 'boss_definition.dart';

/// A structural change to a boss, applied on top of its definition.
///
/// Mutations are neutral building blocks: why one is chosen lives in the
/// boss evolution feature. Each one is valid only when [canApply] holds;
/// applying an invalid one returns the boss unchanged.
sealed class BossMutation {
  const BossMutation(this.zone);

  /// Zone of the boss the mutation acts on.
  final BossZone zone;

  bool canApply(BossDefinition boss);

  BossDefinition applyTo(BossDefinition boss);
}

/// Raises the armor level of every armor and hull part in [zone] that is not
/// at [maxLevel] yet. Each level adds half of the part's level-1 integrity.
class ArmorUpgrade extends BossMutation {
  const ArmorUpgrade(super.zone);

  static const maxLevel = 3;
  static const integrityPerLevel = 0.5;

  static bool _isArmored(BossComponentDefinition part) =>
      part.kind == BossComponentKind.armor ||
      part.kind == BossComponentKind.hull;

  static double _levelMultiplier(int level) =>
      1 + integrityPerLevel * (level - 1);

  bool _upgrades(BossComponentDefinition part) =>
      part.zone == zone && _isArmored(part) && part.armorLevel < maxLevel;

  @override
  bool canApply(BossDefinition boss) => boss.components.any(_upgrades);

  @override
  BossDefinition applyTo(BossDefinition boss) => boss.copyWith(
    components: [
      for (final part in boss.components)
        if (_upgrades(part))
          part.copyWith(
            armorLevel: part.armorLevel + 1,
            maxIntegrity:
                (part.maxIntegrity *
                        _levelMultiplier(part.armorLevel + 1) /
                        _levelMultiplier(part.armorLevel))
                    .round(),
            evolved: true,
          )
        else
          part,
    ],
  );
}

/// Adds one armor plate just below [zone], spanning its parts. It covers
/// every part of the zone that had no cover, so it has to break first. A zone
/// gets at most one extra plate.
class ExtraPlate extends BossMutation {
  const ExtraPlate(super.zone);

  static const integrity = 80;
  static const height = 8.0;
  static const gap = 2.0;
  static const margin = 2.0;

  String get plateId => 'evolved.plate_${zone.name}';

  List<BossComponentDefinition> _zoneParts(BossDefinition boss) => [
    for (final c in boss.components)
      if (c.zone == zone) c,
  ];

  @override
  bool canApply(BossDefinition boss) =>
      _zoneParts(boss).isNotEmpty &&
      !boss.components.any((c) => c.id == plateId);

  @override
  BossDefinition applyTo(BossDefinition boss) {
    if (!canApply(boss)) return boss;
    final zoneParts = _zoneParts(boss);
    final left = zoneParts.map((c) => c.left).reduce(math.min) - margin;
    final right = zoneParts.map((c) => c.right).reduce(math.max) + margin;
    final bottom = zoneParts.map((c) => c.bottom).reduce(math.max);
    final plate = BossComponentDefinition(
      id: plateId,
      name: 'Extra plate',
      kind: BossComponentKind.armor,
      maxIntegrity: integrity,
      offsetX: (left + right) / 2,
      offsetY: bottom + gap + height / 2,
      width: right - left,
      height: height,
      evolved: true,
    );
    return boss.copyWith(
      components: [
        for (final c in boss.components)
          c.zone == zone && c.coveredBy.isEmpty
              ? c.copyWith(coveredBy: [plateId])
              : c,
        plate,
      ],
    );
  }
}
