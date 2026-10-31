import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combat/domain/entities/battle_record.dart';
import '../domain/player_progress.dart';

final progressControllerProvider =
    NotifierProvider<ProgressController, PlayerProgress>(
      ProgressController.new,
    );

class ProgressController extends Notifier<PlayerProgress> {
  @override
  PlayerProgress build() => const PlayerProgress();

  void recordBattle(BattleRecord record) {
    state = state.recordBattle(record);
  }
}
