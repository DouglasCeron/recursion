import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/inventory/domain/inventory.dart';
import 'package:recursion/features/save_game/domain/save_game.dart';
import 'package:recursion/features/save_game/infrastructure/save_game_codec.dart';
import 'package:recursion/features/save_game/infrastructure/shared_preferences_save_repository.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves under one key and loads it back', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSaveRepository(preferences);
    final initial = SaveGame.initial();

    expect((await repository.load()).status, SaveLoadStatus.empty);

    await repository.save(
      SaveGame(
        inventory: Inventory.starter().add(WeaponCatalog.heavyCannon.id),
        loadout: initial.loadout,
        intel: initial.intel,
        progress: initial.progress,
      ),
    );

    expect(
      preferences.getString(SharedPreferencesSaveRepository.storageKey),
      contains('"schemaVersion":${SaveGameCodec.currentVersion}'),
    );
    final loaded = await repository.load();
    expect(loaded.status, SaveLoadStatus.loaded);
    expect(
      loaded.game.inventory.contains(WeaponCatalog.heavyCannon.id),
      isTrue,
    );
  });

  test('corrupted stored data loads as a fresh game', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSaveRepository.storageKey: 'not json',
    });
    final repository = SharedPreferencesSaveRepository(
      await SharedPreferences.getInstance(),
    );

    final result = await repository.load();

    expect(result.status, SaveLoadStatus.corrupted);
    expect(result.game.inventory.itemIds, {WeaponCatalog.blaster.id});
  });
}
