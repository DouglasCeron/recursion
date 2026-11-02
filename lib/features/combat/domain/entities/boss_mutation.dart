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

/// Replaces the boss's single cannon with two. [zone] `center` spreads them
/// under the two wings; `left` or `right` puts both on that side. One of them
/// keeps the original cannon's drop, so a boss still yields one item. A boss
/// never ends up with more than [maxCannons] cannons.
class CannonSplit extends BossMutation {
  const CannonSplit(super.zone);

  static const maxCannons = 2;

  /// Gap between the two cannons of a same-side pair, on top of their width.
  static const gap = 6.0;

  List<BossComponentDefinition> _cannons(BossDefinition boss) => [
    for (final c in boss.components)
      if (c.kind == BossComponentKind.cannon) c,
  ];

  @override
  bool canApply(BossDefinition boss) => _cannons(boss).length == 1;

  @override
  BossDefinition applyTo(BossDefinition boss) {
    if (!canApply(boss)) return boss;
    final source = _cannons(boss).single;
    final spots = _spots(boss, source);
    final keepsDrop = spots.reduce((a, b) => a.x.abs() <= b.x.abs() ? a : b);
    return boss.copyWith(
      components: [
        for (final c in boss.components)
          if (c.kind != BossComponentKind.cannon) c,
        for (final spot in spots)
          BossComponentDefinition(
            id: spot.id,
            name: 'Cannon',
            kind: BossComponentKind.cannon,
            maxIntegrity: source.maxIntegrity,
            offsetX: spot.x,
            offsetY: source.offsetY,
            width: source.width,
            height: source.height,
            dropItemId: spot == keepsDrop ? source.dropItemId : null,
            evolved: true,
          ),
      ],
    );
  }

  /// Where the wing of [zone] sits, or a fixed offset when it has none.
  double _anchor(BossDefinition boss, BossZone zone) {
    for (final part in boss.components) {
      if (part.kind == BossComponentKind.hull && part.zone == zone) {
        return part.offsetX;
      }
    }
    return zone == BossZone.left ? -76 : 76;
  }

  List<({String id, double x})> _spots(
    BossDefinition boss,
    BossComponentDefinition source,
  ) {
    if (zone == BossZone.center) {
      return [
        (id: 'evolved.cannon_left', x: _anchor(boss, BossZone.left)),
        (id: 'evolved.cannon_right', x: _anchor(boss, BossZone.right)),
      ];
    }
    final half = (source.width + gap) / 2;
    final anchor = _anchor(boss, zone);
    final inward = zone == BossZone.left ? half : -half;
    return [
      (id: 'evolved.cannon_${zone.name}_inner', x: anchor + inward),
      (id: 'evolved.cannon_${zone.name}_outer', x: anchor - inward),
    ];
  }
}
