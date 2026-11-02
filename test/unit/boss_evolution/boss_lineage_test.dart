import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/domain/boss_lineage.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_mutation.dart';

BossGeneration generationOf(List<BossMutation> mutations) => BossGeneration(
  steps: [
    for (final m in mutations) EvolutionStep(mutation: m, zoneShare: 0.5),
  ],
);

void main() {
  test('a new lineage holds only the base boss', () {
    const lineage = BossLineage();

    expect(lineage.length, 1);
    expect(lineage.latestId, BossCatalog.sentinel.id);
    expect(
      lineage.definitionOf(BossCatalog.sentinel.id)!.components,
      BossCatalog.sentinel.components,
    );
  });

  test('later bosses get generated ids and roman numeral names', () {
    var lineage = const BossLineage();
    for (var i = 0; i < 13; i++) {
      lineage = lineage.withNext(const BossGeneration());
    }

    expect(lineage.bossIds.take(3), [
      'boss.sentinel',
      'boss.sentinel.gen2',
      'boss.sentinel.gen3',
    ]);
    expect(lineage.nameOf(1), 'Sentinel');
    expect(lineage.nameOf(4), 'Sentinel Mk IV');
    expect(lineage.nameOf(9), 'Sentinel Mk IX');
    expect(lineage.nameOf(14), 'Sentinel Mk XIV');
    expect(lineage.definitionOf(lineage.latestId)!.name, 'Sentinel Mk XIV');
    expect(lineage.numberOf('boss.sentinel.gen14'), 14);
    expect(lineage.contains('boss.sentinel.gen15'), isFalse);
    expect(lineage.definitionOf('boss.other'), isNull);
  });

  test('each boss carries every mutation of the generations before it', () {
    final lineage = const BossLineage()
        .withNext(generationOf([const ArmorUpgrade(BossZone.left)]))
        .withNext(
          generationOf([
            const ArmorUpgrade(BossZone.left),
            const ExtraPlate(BossZone.left),
          ]),
        );

    final second = lineage.definitionOf('boss.sentinel.gen2')!;
    final third = lineage.definitionOf('boss.sentinel.gen3')!;

    expect(second.component('sentinel.hull_left').armorLevel, 2);
    expect(evolutionSummary(second), ['left armor Lv2']);
    expect(third.component('sentinel.hull_left').armorLevel, 3);
    expect(evolutionSummary(third), ['left armor Lv3', 'left extra plate']);
    expect(evolutionSummary(lineage.definitionOf('boss.sentinel')!), isEmpty);
  });
}
