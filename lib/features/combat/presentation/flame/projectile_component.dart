import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'boss_component.dart';
import 'space_game.dart';

/// A player projectile. It only moves and reports collisions; damage is
/// decided by the battle state using [projectileId].
class ProjectileComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<SpaceGame> {
  ProjectileComponent({
    required this.projectileId,
    required Vector2 origin,
    required this.speed,
  }) : super(position: origin, size: Vector2(4, 12), anchor: Anchor.center);

  final int projectileId;
  final double speed;
  bool _resolved = false;

  final _paint = Paint()..color = const Color(0xFFFFF59D);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= speed * dt;
    if (!_resolved && position.y < -size.y) {
      _resolved = true;
      game.session.reportProjectileLeftArena(projectileId);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(2)),
      _paint,
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_resolved || other is! BossPartComponent) return;
    final consumed = game.session.reportHit(
      projectileId: projectileId,
      componentId: other.componentId,
    );
    if (!consumed) return;
    _resolved = true;
    removeFromParent();
  }
}
