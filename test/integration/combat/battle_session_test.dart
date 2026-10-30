import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/application/battle_session.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';

/// Plays a battle through the session API, routing every player shot to the
/// first part in [targetOrder] that is still standing, as rendering would.
List<BattleEvent> play(
  BattleSession session, {
  required List<String> targetOrder,
  bool Function(BattleSession session)? stopShootingWhen,
}) {
  final events = <BattleEvent>[];
  session.events.listen(events.add);
  session.start();
  const step = 1 / 60;
  for (var frame = 0; frame < 60 * 120; frame++) {
    final before = events.length;
    session.update(step);
    final shots = events.skip(before).whereType<WeaponFired>().toList();
    final shooting = !(stopShootingWhen?.call(session) ?? false);
    for (final shot in shots) {
      if (!shooting) {
        session.reportProjectileLeftArena(shot.projectileId);
        continue;
      }
      final target = targetOrder.firstWhere(
        (id) => !session.state.boss.component(id)!.isDestroyed,
      );
      session.reportHit(projectileId: shot.projectileId, componentId: target);
      // Duplicate collision callbacks must be harmless.
      session.reportHit(projectileId: shot.projectileId, componentId: target);
    }
    for (final enemy in events.skip(before).whereType<EnemyFired>()) {
      session.reportProjectileLeftArena(enemy.projectileId);
    }
    if (session.state.status == BattleStatus.completed) break;
  }
  return events;
}

void main() {
  const order = ['sentinel.cannon', 'sentinel.armor', 'sentinel.core'];

  test('breaking cannon, armor and core defeats the boss', () {
    final session = BattleSession.boss();

    final events = play(session, targetOrder: order);

    expect(session.state.outcome, BattleOutcome.victory);
    expect(events.whereType<BossBehaviorChanged>(), hasLength(1));
    expect(events.whereType<BossComponentDestroyed>(), hasLength(3));
    expect(events.whereType<BossDefeated>(), hasLength(1));
    expect(events.whereType<BattleCompleted>(), hasLength(1));
    final bonusHits = events.whereType<BossComponentHit>().where(
      (e) => e.weakPointBonus,
    );
    expect(bonusHits, isNotEmpty);
    expect(bonusHits.every((e) => e.componentId == 'sentinel.core'), isTrue);
  });

  test('the boss escapes if the player stops shooting after the warning', () {
    final session = BattleSession.boss();

    final events = play(
      session,
      targetOrder: order,
      stopShootingWhen: (s) => s.state.boss.phase == BossPhase.escaping,
    );

    expect(session.state.outcome, BattleOutcome.bossEscaped);
    expect(events.whereType<BossEscapeWarning>(), hasLength(1));
    expect(events.whereType<BossEscaped>(), hasLength(1));
    expect(events.whereType<BossDefeated>(), isEmpty);
  });

  test('steering is ignored before the battle starts', () {
    final session = BattleSession.boss();
    final ship = session.state.ship;
    final startX = ship.destinationX;

    session.steerShip(50, 0);

    expect(ship.destinationX, startX);
  });
}
