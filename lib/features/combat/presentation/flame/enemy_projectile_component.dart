import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'player_ship_component.dart';
import 'space_game.dart';

/// A boss projectile. It only moves and reports touching the ship; damage is
/// decided by the battle state using [projectileId].
class EnemyProjectileComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<SpaceGame> {
  EnemyProjectileComponent({
    required this.projectileId,
    required Vector2 origin,
    required this.velocity,
  }) : super(position: origin, size: Vector2.all(10), anchor: Anchor.center);

  final int projectileId;
  final Vector2 velocity;
  bool _resolved = false;

  static final _paint = Paint()..color = const Color(0xFFFF7043);

  @override
  Future<void> onLoad() async {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.addScaled(velocity, dt);
    final arena = game.session.arena;
    final margin = size.x;
    final outside =
        position.x < -margin ||
        position.x > arena.width + margin ||
        position.y < -margin ||
        position.y > arena.height + margin;
    if (!_resolved && outside) {
      _resolved = true;
      game.session.reportProjectileLeftArena(projectileId);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, _paint);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_resolved || other is! PlayerShipComponent) return;
    _resolved = true;
    game.session.reportShipHit(projectileId);
    removeFromParent();
  }
}
