import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/save_game/application/save_game_providers.dart';
import '../features/save_game/domain/save_game.dart';

/// Restores the save from [repository] and returns a container whose state
/// starts from it and is saved back automatically.
Future<ProviderContainer> createAppContainer(SaveRepository repository) async {
  final result = await repository.load();
  if (result.status
      case SaveLoadStatus.corrupted || SaveLoadStatus.unsupportedVersion) {
    debugPrint('Recursion: save ignored (${result.status.name}); new game.');
  }
  final container = ProviderContainer(
    overrides: [
      saveRepositoryProvider.overrideWithValue(repository),
      ...restoreOverrides(result.game),
    ],
  );
  container.listen(autosaveProvider, (_, _) {});
  return container;
}
