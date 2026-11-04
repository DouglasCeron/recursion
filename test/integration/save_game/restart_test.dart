import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/app/app_container.dart';
import 'package:recursion/features/boss_evolution/application/boss_intel_controller.dart';
import 'package:recursion/features/boss_evolution/application/boss_lineage_controller.dart';
import 'package:recursion/features/boss_evolution/domain/boss_lineage.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/inventory/application/inventory_controller.dart';
import 'package:recursion/features/progression/application/progress_controller.dart';
import 'package:recursion/features/save_game/domain/save_game.dart';
import 'package:recursion/features/save_game/infrastructure/in_memory_save_repository.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';

import '../../support/battle_driver.dart';

/// Counts writes so tests can check how often the game is saved.
class CountingRepository extends InMemorySaveRepository {
  int saves = 0;

  @override
  Future<void> save(SaveGame game) {
    saves++;
    return super.save(game);
  }
}

/// Simulates closing the app: pending writes finish, the container goes away.
///
/// Deliberately does not touch the autosave provider, so the test fails if
/// saving depends on something only a test would do.
Future<void> closeApp(ProviderContainer container) async {
  await pumpEventQueue();
  container.dispose();
}

void main() {
  test(
    'restarting restores inventory, loadout, intel, progress and lineage',
    () async {
      final repository = InMemorySaveRepository();
      final first = await createAppContainer(repository);
      final inventory = first.read(inventoryControllerProvider.notifier);
      inventory.collect(WeaponCatalog.heavyCannon.id);
      inventory.equipWeapon(WeaponCatalog.heavyCannon.id);
      playBattle(first);
      final lineageBefore = first.read(bossLineageControllerProvider);
      await closeApp(first);

      final second = await createAppContainer(repository);
      addTearDown(second.dispose);

      final restored = second.read(inventoryControllerProvider);
      expect(restored.inventory.contains(WeaponCatalog.heavyCannon.id), isTrue);
      expect(restored.equippedWeapon, WeaponCatalog.heavyCannon);
      expect(second.read(bossIntelControllerProvider).reports, hasLength(1));
      final progress = second.read(progressControllerProvider);
      expect(progress.battlesFought, 1);
      expect(progress.foughtBossIds, {BossCatalog.sentinel.id});

      final lineage = second.read(bossLineageControllerProvider);
      expect(lineage.length, 2);
      final latestId = lineage.latestId;
      final restoredBoss = second
          .read(battleSessionProvider(latestId))
          .state
          .boss
          .definition;
      expect(
        evolutionSummary(restoredBoss),
        evolutionSummary(lineageBefore.definitionOf(latestId)!),
      );
      expect(evolutionSummary(restoredBoss), [
        'center Steel',
        'center extra plate',
        'fast cannon',
      ]);
    },
  );

  test('a corrupted save starts a new game and is replaced', () async {
    final repository = InMemorySaveRepository(raw: '{broken');

    final container = await createAppContainer(repository);
    expect(container.read(progressControllerProvider).battlesFought, 0);
    playBattle(container);
    await closeApp(container);

    final reloaded = await repository.load();
    expect(reloaded.status, SaveLoadStatus.loaded);
    expect(reloaded.game.progress.battlesFought, 1);
  });

  test('a battle saves on state changes, never per frame', () async {
    final repository = CountingRepository();
    final container = await createAppContainer(repository);

    playBattle(container);
    await closeApp(container);

    // Intel transmission and the battle record, at the end of the battle.
    expect(repository.saves, inInclusiveRange(1, 2));
  });
}
