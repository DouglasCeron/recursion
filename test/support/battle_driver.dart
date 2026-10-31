import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/application/battle_session.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/combat/presentation/battle_providers.dart';

const frameStep = 1 / 60;

/// Plays a full battle through the providers, without rendering.
///
/// Each player shot hits the observer while [shootObserver] is true and it is
/// alive; otherwise the first part in [targetOrder] that is still standing.
/// Enemy shots always miss. Returns the session and every event published.
({BattleSession session, List<BattleEvent> events}) playBattle(
  ProviderContainer container, {
  String? bossId,
  List<String> targetOrder = const ['sentinel.core'],
  bool shootObserver = false,
}) {
  final id = bossId ?? BossCatalog.sentinel.id;
  container.invalidate(battleSessionProvider(id));
  container.listen(battleSessionProvider(id), (_, _) {});
  final session = container.read(battleSessionProvider(id));
  final events = <BattleEvent>[];
  session.events.listen(events.add);
  session.start();
  for (var frame = 0; frame < 60 * 300; frame++) {
    final before = events.length;
    session.update(frameStep);
    for (final shot in events.skip(before).whereType<WeaponFired>().toList()) {
      if (shootObserver && !session.state.observer.isDestroyed) {
        session.reportObserverHit(shot.projectileId);
        continue;
      }
      final target = targetOrder.firstWhere(
        (part) => !session.state.boss.component(part)!.isDestroyed,
      );
      session.reportHit(projectileId: shot.projectileId, componentId: target);
    }
    for (final enemy in events.skip(before).whereType<EnemyFired>()) {
      session.reportProjectileLeftArena(enemy.projectileId);
    }
    if (session.state.status == BattleStatus.completed) {
      return (session: session, events: events);
    }
  }
  fail('the battle never ended');
}
