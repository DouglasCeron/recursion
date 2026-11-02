import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../boss_evolution/application/boss_intel_controller.dart';
import '../../boss_evolution/application/boss_lineage_controller.dart';
import '../../inventory/application/inventory_controller.dart';
import '../../progression/application/progress_controller.dart';
import '../domain/save_game.dart';
import '../infrastructure/in_memory_save_repository.dart';

final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => InMemorySaveRepository(),
);

/// The save game matching the current state of every persisted feature.
final currentSaveGameProvider = Provider<SaveGame>((ref) {
  final inventory = ref.watch(inventoryControllerProvider);
  return SaveGame(
    inventory: inventory.inventory,
    loadout: inventory.loadout,
    intel: ref.watch(bossIntelControllerProvider),
    progress: ref.watch(progressControllerProvider),
    lineage: ref.watch(bossLineageControllerProvider),
  );
});

/// Writes the save whenever persisted state changes: collecting an item,
/// equipping a weapon, receiving intel, or finishing a battle (which also
/// grows the boss lineage).
///
/// It must be *listened* for as long as the app runs: Riverpod pauses the
/// `ref.listen` of a provider that is only read.
final autosaveProvider = Provider<Autosave>((ref) {
  final autosave = Autosave(ref.read(saveRepositoryProvider));
  ref.listen(currentSaveGameProvider, (_, game) => autosave.schedule(game));
  return autosave;
});

/// Wipes inventory, intel, progress and the boss lineage back to a new game. Autosave then
/// replaces the stored save.
final resetGameProvider = Provider<void Function()>(
  (ref) => () {
    ref.read(inventoryControllerProvider.notifier).reset();
    ref.read(bossIntelControllerProvider.notifier).reset();
    ref.read(progressControllerProvider.notifier).reset();
    ref.read(bossLineageControllerProvider.notifier).reset();
  },
);

/// Overrides that make every persisted feature start from [game].
List<Override> restoreOverrides(SaveGame game) => [
  initialInventoryStateProvider.overrideWithValue(
    PlayerInventoryState(inventory: game.inventory, loadout: game.loadout),
  ),
  initialBossIntelProvider.overrideWithValue(game.intel),
  initialProgressProvider.overrideWithValue(game.progress),
  initialBossLineageProvider.overrideWithValue(game.lineage),
];

/// Serializes writes so an older save can never land after a newer one.
class Autosave {
  Autosave(this._repository);

  final SaveRepository _repository;
  Future<void> _pending = Future.value();

  void schedule(SaveGame game) {
    _pending = _pending.then((_) => _write(game));
  }

  Future<void> _write(SaveGame game) async {
    try {
      await _repository.save(game);
    } on Object catch (error) {
      debugPrint('Recursion: could not save the game: $error');
    }
  }
}
