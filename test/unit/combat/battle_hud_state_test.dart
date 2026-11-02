import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/core/geometry/arena_bounds.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/ship/domain/ship_state.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';

void main() {
  const arena = ArenaBounds.standard;

  test('the top HUD shows the boss as one total integrity bar', () {
    final battle = BattleState(
      ship: ShipState(arena: arena, weapon: WeaponCatalog.blaster),
      boss: BossState(definition: BossCatalog.sentinel, arena: arena),
    )..start();

    final fresh = BattleHudState.fromBattle(battle);
    expect(fresh.bossMaxIntegrity, 740);
    expect(fresh.bossIntegrityRatio, 1);

    final shot = battle
        .update(WeaponCatalog.blaster.fireInterval)
        .whereType<WeaponFired>()
        .single;
    battle.resolveHit(
      projectileId: shot.projectileId,
      componentId: 'sentinel.hull_left',
    );

    final hit = BattleHudState.fromBattle(battle);
    expect(hit.bossIntegrity, 730);
  });
}
