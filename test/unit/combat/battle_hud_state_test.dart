import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_mutation.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/ship/domain/ship_state.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';

void main() {
  const arena = ArenaBounds.standard;

  BattleHudState hudFor(BossDefinition boss) => BattleHudState.fromBattle(
    BattleState(
      ship: ShipState(arena: arena, weapon: WeaponCatalog.blaster),
      boss: BossState(definition: boss, arena: arena),
    )..start(),
  );

  test('the top HUD names the boss and the evolutions it carries', () {
    final evolved = const ExtraPlate(
      BossZone.left,
    ).applyTo(const ArmorUpgrade(BossZone.left).applyTo(BossCatalog.sentinel));

    expect(hudFor(BossCatalog.sentinel).bossName, 'Sentinel');
    expect(hudFor(BossCatalog.sentinel).evolutions, isEmpty);
    expect(hudFor(evolved).evolutions, ['left Steel', 'left extra plate']);
  });
}
