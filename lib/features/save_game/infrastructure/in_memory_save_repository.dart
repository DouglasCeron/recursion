import '../domain/save_game.dart';
import 'save_game_codec.dart';

/// Keeps the encoded save in memory. Used by tests and as the default when
/// no real storage is configured; it still goes through the JSON codec.
class InMemorySaveRepository implements SaveRepository {
  InMemorySaveRepository({this.raw, this.codec = const SaveGameCodec()});

  /// The stored JSON, exposed so tests can inspect or corrupt it.
  String? raw;
  final SaveGameCodec codec;

  @override
  Future<SaveLoadResult> load() async => codec.decode(raw);

  @override
  Future<void> save(SaveGame game) async => raw = codec.encode(game);
}
