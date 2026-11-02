import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/boss_intel.dart';
import '../domain/boss_lineage.dart';
import '../domain/evolution_director.dart';

/// Lineage the campaign starts with; overridden with the restored save.
final initialBossLineageProvider = Provider<BossLineage>(
  (ref) => const BossLineage(),
);

final bossLineageControllerProvider =
    NotifierProvider<BossLineageController, BossLineage>(
      BossLineageController.new,
    );

/// Grows the chain of bosses as the player fights them.
class BossLineageController extends Notifier<BossLineage> {
  @override
  BossLineage build() => ref.read(initialBossLineageProvider);

  /// Called when a battle against [bossId] ends, whatever its outcome.
  /// [report] is the intel transmitted from that battle, if any.
  ///
  /// Only the latest boss produces a successor; replaying an earlier one
  /// changes nothing.
  void onBattleCompleted(String bossId, IntelReport? report) {
    if (bossId != state.latestId) return;
    final current = state.definitionOf(bossId)!;
    state = state.withNext(EvolutionDirector.next(current, report));
  }

  void reset() => state = const BossLineage();
}
