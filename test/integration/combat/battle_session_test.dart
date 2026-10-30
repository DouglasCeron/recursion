import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/application/battle_session.dart';
import 'package:recursion/features/combat/domain/entities/battle_state.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';

void main() {
  test('a training session can be played to victory through its API', () {
    final session = BattleSession.training();
    final events = <BattleEvent>[];
    session.events.listen(events.add);

    session.start();
    const step = 1 / 60;
    for (var frame = 0; frame < 60 * 60; frame++) {
      session.update(step);
      final shots = events.whereType<WeaponFired>().toList();
      if (shots.isNotEmpty) {
        final shot = shots.last;
        session.reportHit(
          projectileId: shot.projectileId,
          targetId: BattleSession.trainingTargetId,
        );
        // Simulates the duplicate collision callbacks Flame can produce.
        session.reportHit(
          projectileId: shot.projectileId,
          targetId: BattleSession.trainingTargetId,
        );
        events.removeWhere((e) => e is WeaponFired);
      }
      if (session.state.status == BattleStatus.completed) break;
    }

    expect(session.state.status, BattleStatus.completed);
    expect(events.whereType<BattleStarted>(), hasLength(1));
    expect(events.whereType<TargetDestroyed>(), hasLength(1));
    expect(events.whereType<BattleCompleted>(), hasLength(1));
    expect(
      events.whereType<TargetHit>().fold<int>(0, (sum, e) => sum + e.damage),
      300,
    );
  });

  test('steering is ignored before the battle starts', () {
    final session = BattleSession.training();
    final ship = session.state.ship;
    final startX = ship.destinationX;

    session.steerShip(50, 0);

    expect(ship.destinationX, startX);
  });
}
