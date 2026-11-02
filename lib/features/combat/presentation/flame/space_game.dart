import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../application/battle_session.dart';
import '../../domain/events/battle_event.dart';
import 'arena_component.dart';
import 'boss_component.dart';
import 'drop_component.dart';
import 'enemy_projectile_component.dart';
import 'observer_component.dart';
import 'player_ship_component.dart';
import 'projectile_component.dart';

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
  late final PlayerShipComponent _ship;
  late final BossComponent _boss;
  late final ObserverComponent _observer;
  final Map<int, DropComponent> _drops = {};
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
    _ship = PlayerShipComponent(ship: session.state.ship);
    _boss = BossComponent(boss: session.state.boss);
    _observer = ObserverComponent(observer: session.state.observer);
    world.addAll([_ship, _boss, _observer]);

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
            weaponType: event.weaponType,
          ),
        );
      case ItemDropped():
        final drop = session.state.drop(event.dropId);
        if (drop == null) return;
        final component = DropComponent(drop: drop);
        _drops[event.dropId] = component;
        world.add(component);
      case ItemCollected(:final dropId) || ItemExpired(:final dropId):
        _drops.remove(dropId)?.removeFromParent();
      case EnemyFired():
        world.add(
          EnemyProjectileComponent(
            projectileId: event.projectileId,
            origin: Vector2(event.originX, event.originY),
            velocity: Vector2(event.velocityX, event.velocityY),
          ),
        );
      case BossComponentDestroyed():
        _boss.onPartDestroyed(event.componentId);
      case BossDefeated():
        _boss.explode();
      case BossEscaped():
        _boss.flyAway();
      case ShipDestroyed():
        _ship.explode();
      case ObserverFled():
        _observer.flee();
      case BattleCompleted():
        _clearProjectiles();
      case BattleStarted() ||
          BossComponentHit() ||
          BossBehaviorChanged() ||
          WeakPointExposed() ||
          WeakPointClosed() ||
          BossEscapeWarning() ||
          ObserverHit() ||
          ObserverTransmitted() ||
          CoreShieldDropped() ||
          CoreShieldRestored() ||
          ShipHit():
        break;
    }
  }

  void _clearProjectiles() {
    world.children
        .where((c) => c is ProjectileComponent || c is EnemyProjectileComponent)
        .toList()
        .forEach((c) => c.removeFromParent());
  }
}
