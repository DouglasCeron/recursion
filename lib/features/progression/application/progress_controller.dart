import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combat/domain/entities/battle_record.dart';
import '../domain/player_progress.dart';

/// Progress the player starts with; overridden with the restored save.
final initialProgressProvider = Provider<PlayerProgress>(
  (ref) => const PlayerProgress(),
);

final progressControllerProvider =
    NotifierProvider<ProgressController, PlayerProgress>(
      ProgressController.new,
    );

class ProgressController extends Notifier<PlayerProgress> {
  @override
  PlayerProgress build() => ref.read(initialProgressProvider);

  void recordBattle(BattleRecord record) {
    state = state.recordBattle(record);
  }

  void reset() => state = const PlayerProgress();
}
