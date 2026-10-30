import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/application/boss_intel_controller.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

const _step = 1 / 60;

/// Plays a full battle through the providers. Shots go to the observer while
/// [shootObserver] is true and it is alive; otherwise they go to the boss
/// core, until the boss is defeated.
void playBattle(ProviderContainer container, {required bool shootObserver}) {
  container.invalidate(battleSessionProvider);
  container.listen(battleSessionProvider, (_, _) {});
  final session = container.read(battleSessionProvider);
  final events = <BattleEvent>[];
  session.events.listen(events.add);
  session.start();
  for (var frame = 0; frame < 60 * 120; frame++) {
    final before = events.length;
    session.update(_step);
    for (final shot in events.skip(before).whereType<WeaponFired>().toList()) {
      if (shootObserver && !session.state.observer.isDestroyed) {
        session.reportObserverHit(shot.projectileId);
      } else {
        session.reportHit(
          projectileId: shot.projectileId,
          componentId: 'sentinel.core',
        );
      }
    }
    for (final enemy in events.skip(before).whereType<EnemyFired>()) {
      session.reportProjectileLeftArena(enemy.projectileId);
    }
    if (session.state.status == BattleStatus.completed) return;
  }
  fail('the battle never ended');
}

void main() {
  test('a surviving observer makes the intel available afterwards', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    playBattle(container, shootObserver: false);

    final intel = container.read(bossIntelControllerProvider);
    expect(intel.reports, hasLength(1));
    final profile = intel.latest!.profile;
    expect(profile.levelOf(WeaponType.blaster), ExposureLevel.high);
    expect(profile.levelOf(WeaponType.heavyCannon), isNull);
  });

  test('destroying the observer keeps the new battle out of the intel, '
      'without erasing earlier reports', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    playBattle(container, shootObserver: false);
    playBattle(container, shootObserver: true);

    expect(container.read(bossIntelControllerProvider).reports, hasLength(1));
  });

  test('without any transmission the enemy knows nothing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    playBattle(container, shootObserver: true);

    expect(container.read(bossIntelControllerProvider).isEmpty, isTrue);
  });
}
