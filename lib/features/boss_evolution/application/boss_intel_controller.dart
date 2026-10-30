import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combat/domain/entities/combat_log.dart';
import '../domain/boss_intel.dart';
import '../domain/weapon_exposure_profile.dart';

final bossIntelControllerProvider =
    NotifierProvider<BossIntelController, BossIntel>(BossIntelController.new);

/// Receives observer transmissions and keeps the enemy faction's knowledge.
class BossIntelController extends Notifier<BossIntel> {
  @override
  BossIntel build() => const BossIntel();

  void receiveTransmission(CombatStats observed) {
    state = state.withReport(WeaponExposureProfile.fromStats(observed));
  }
}
