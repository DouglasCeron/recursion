import '../../boss_evolution/domain/boss_intel.dart';
import '../../inventory/domain/inventory.dart';
import '../../progression/domain/player_progress.dart';

/// Everything that survives an app restart.
class SaveGame {
  const SaveGame({
    required this.inventory,
    required this.loadout,
    required this.intel,
    required this.progress,
  });

  factory SaveGame.initial() => SaveGame(
    inventory: Inventory.starter(),
    loadout: Loadout.starter(),
    intel: const BossIntel(),
    progress: const PlayerProgress(),
  );

  final Inventory inventory;
  final Loadout loadout;
  final BossIntel intel;
  final PlayerProgress progress;
}

enum SaveLoadStatus {
  /// Nothing was saved yet.
  empty,
  loaded,

  /// The stored data could not be read; the game starts fresh.
  corrupted,

  /// The data was written by a newer version of the game; it starts fresh.
  unsupportedVersion,
}

class SaveLoadResult {
  const SaveLoadResult(this.status, this.game);

  final SaveLoadStatus status;

  /// The restored game, or a fresh one when nothing usable was stored.
  final SaveGame game;
}

/// Where the save game lives. Implementations never throw on bad data; they
/// report it through [SaveLoadResult.status].
abstract interface class SaveRepository {
  Future<SaveLoadResult> load();
  Future<void> save(SaveGame game);
}
