import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/boss_component_state.dart';
import '../../combat/domain/entities/boss_definition.dart';
import '../../combat/domain/entities/boss_mutation.dart';

/// Short descriptions of every evolution [boss] carries, zone by zone, e.g.
/// `left armor Lv3` or `left extra plate`.
List<String> evolutionSummary(BossDefinition boss) => [
  for (final zone in BossZone.values) ...[
    if (boss.components
            .where((c) => c.zone == zone)
            .map((c) => c.armorLevel)
            .fold(1, (a, b) => a > b ? a : b)
        case final level when level > 1)
      '${zone.name} armor Lv$level',
    if (boss.components.any((c) => c.id == ExtraPlate(zone).plateId))
      '${zone.name} extra plate',
  ],
  ...switch (boss.components.where((c) => c.kind == BossComponentKind.cannon)) {
    final cannons when cannons.length >= CannonSplit.maxCannons => [
      cannons.map((c) => c.zone).toSet().length == 1
          ? '${cannons.first.zone.name} twin cannons'
          : 'cannons on both wings',
    ],
    _ => const <String>[],
  },
];

/// One mutation chosen for a generation, with the observed share of damage
/// in its zone that justified it.
class EvolutionStep {
  const EvolutionStep({required this.mutation, required this.zoneShare});

  final BossMutation mutation;
  final double zoneShare;
}

/// What changed from the previous boss to this one. The first generation is
/// the base boss and changes nothing.
class BossGeneration {
  const BossGeneration({this.steps = const [], this.basedOnReport});

  final List<EvolutionStep> steps;

  /// Sequence of the intel report the evolution came from, or null when the
  /// enemy had no intel about the previous battle.
  final int? basedOnReport;
}

/// The campaign as a chain of bosses, each one evolved from the previous.
///
/// Only the mutations are stored; a boss is rebuilt by applying every
/// generation up to it on top of the base boss, so it is identical every
/// time it is fought. The chain has no end: fighting the latest boss always
/// produces the next one.
class BossLineage {
  const BossLineage({
    this.base = BossCatalog.sentinel,
    this.generations = const [BossGeneration()],
  });

  final BossDefinition base;

  /// `generations[0]` is the base boss.
  final List<BossGeneration> generations;

  int get length => generations.length;
  String get latestId => idOf(length);
  List<String> get bossIds => [for (var n = 1; n <= length; n++) idOf(n)];

  String idOf(int number) => number == 1 ? base.id : '${base.id}.gen$number';

  String nameOf(int number) =>
      number == 1 ? base.name : '${base.name} Mk ${_roman(number)}';

  /// Position of [bossId] in the chain, starting at 1, or null if unknown.
  int? numberOf(String bossId) {
    final index = bossIds.indexOf(bossId);
    return index < 0 ? null : index + 1;
  }

  bool contains(String bossId) => numberOf(bossId) != null;

  BossGeneration? generationOf(String bossId) => switch (numberOf(bossId)) {
    final number? => generations[number - 1],
    null => null,
  };

  /// The boss fought as [bossId], or null if it is not in the chain.
  BossDefinition? definitionOf(String bossId) {
    final number = numberOf(bossId);
    if (number == null) return null;
    var boss = base;
    for (final generation in generations.take(number)) {
      for (final step in generation.steps) {
        boss = step.mutation.applyTo(boss);
      }
    }
    return boss.copyWith(id: idOf(number), name: nameOf(number));
  }

  BossLineage withNext(BossGeneration generation) => BossLineage(
    base: base,
    generations: List.unmodifiable([...generations, generation]),
  );

  static String _roman(int number) {
    const numerals = [
      (1000, 'M'),
      (900, 'CM'),
      (500, 'D'),
      (400, 'CD'),
      (100, 'C'),
      (90, 'XC'),
      (50, 'L'),
      (40, 'XL'),
      (10, 'X'),
      (9, 'IX'),
      (5, 'V'),
      (4, 'IV'),
      (1, 'I'),
    ];
    final buffer = StringBuffer();
    var rest = number;
    for (final (value, symbol) in numerals) {
      while (rest >= value) {
        buffer.write(symbol);
        rest -= value;
      }
    }
    return buffer.toString();
  }
}
