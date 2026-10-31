import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combat/domain/entities/combat_log.dart';
import '../domain/boss_evolution.dart';
import '../domain/boss_intel.dart';
import '../domain/weapon_exposure_profile.dart';

/// Intel the enemy starts with; overridden with the restored save.
final initialBossIntelProvider = Provider<BossIntel>(
  (ref) => const BossIntel(),
);

final bossIntelControllerProvider =
    NotifierProvider<BossIntelController, BossIntel>(BossIntelController.new);

/// Configuration the adaptive boss will use, derived only from enemy intel.
final bossEvolutionProvider = Provider<BossEvolutionState>(
  (ref) => AdaptationRules.evolve(ref.watch(bossIntelControllerProvider)),
);

/// Receives observer transmissions and keeps the enemy faction's knowledge.
class BossIntelController extends Notifier<BossIntel> {
  @override
  BossIntel build() => ref.read(initialBossIntelProvider);

  void receiveTransmission(CombatStats observed) {
    state = state.withReport(WeaponExposureProfile.fromStats(observed));
  }
}
