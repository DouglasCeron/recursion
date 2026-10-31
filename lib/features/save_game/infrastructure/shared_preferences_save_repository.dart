import 'package:shared_preferences/shared_preferences.dart';

import '../domain/save_game.dart';
import 'save_game_codec.dart';

/// Stores the save game as one versioned JSON string in shared preferences.
class SharedPreferencesSaveRepository implements SaveRepository {
  SharedPreferencesSaveRepository(
    this._preferences, {
    this.codec = const SaveGameCodec(),
  });

  static const storageKey = 'recursion.save_game';

  final SharedPreferences _preferences;
  final SaveGameCodec codec;

  @override
  Future<SaveLoadResult> load() async =>
      codec.decode(_preferences.getString(storageKey));

  @override
  Future<void> save(SaveGame game) async {
    final written = await _preferences.setString(
      storageKey,
      codec.encode(game),
    );
    if (!written) throw StateError('could not write the save game');
  }
}
