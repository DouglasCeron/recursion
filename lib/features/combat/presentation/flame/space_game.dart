import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../application/battle_session.dart';
import '../../domain/events/battle_event.dart';
import 'arena_component.dart';
import 'player_ship_component.dart';
import 'projectile_component.dart';
import 'target_component.dart';

/// Flame integration for a battle: renders the arena and forwards input and
/// collisions to [session], which owns the authoritative battle state.
class SpaceGame extends FlameGame with HasCollisionDetection {
  SpaceGame({required this.session})
    : super(
        camera: CameraComponent.withFixedResolution(
          width: session.arena.width,
          height: session.arena.height,
        ),
      );

  /// Longest simulated step, so a stalled frame cannot teleport entities.
  static const _maxStep = 1 / 20;

  final BattleSession session;
  final Map<String, TargetComponent> _targets = {};
  StreamSubscription<BattleEvent>? _subscription;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    final arena = session.arena;
    camera.viewfinder.anchor = Anchor.topLeft;

    world.add(
      ArenaComponent(
        arenaSize: Vector2(arena.width, arena.height),
        onDrag: session.steerShip,
      ),
    );
    world.add(PlayerShipComponent(ship: session.state.ship));
    for (final target in session.state.targets) {
      final component = TargetComponent(
        target: target,
        position: Vector2(arena.width / 2, arena.height * 0.2),
        driftRange: arena.width * 0.25,
      );
      _targets[target.id] = component;
      world.add(component);
    }

    _subscription = session.events.listen(_onBattleEvent);
  }

  @override
  void update(double dt) {
    // Started from the game loop rather than onLoad, which may run while the
    // widget tree is building and must not trigger HUD state changes.
    session.start();
    final step = math.min(dt, _maxStep);
    session.update(step);
    super.update(step);
  }

  @override
  void onRemove() {
    _subscription?.cancel();
    super.onRemove();
  }

  void _onBattleEvent(BattleEvent event) {
    switch (event) {
      case WeaponFired():
        world.add(
          ProjectileComponent(
            projectileId: event.projectileId,
            origin: Vector2(event.originX, event.originY),
            speed: event.projectileSpeed,
          ),
        );
      case TargetDestroyed():
        _targets.remove(event.targetId)?.explode();
      case BattleStarted() || TargetHit() || BattleCompleted():
        break;
    }
  }
}
