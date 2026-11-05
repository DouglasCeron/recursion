import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../domain/entities/boss_state.dart';
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
    this.style = EnemyShotStyle.cannon,
  }) : super(
         position: origin,
         size: switch (style) {
           EnemyShotStyle.cannon => Vector2.all(10),
           EnemyShotStyle.laser => Vector2(4, 18),
           EnemyShotStyle.missile => Vector2.all(14),
         },
         anchor: Anchor.center,
       );

  final int projectileId;
  final Vector2 velocity;
  final EnemyShotStyle style;
  bool _resolved = false;

  static final _cannonPaint = Paint()..color = const Color(0xFFFF7043);
  static final _laserPaint = Paint()..color = const Color(0xFF4DF0FF);
  static final _missilePaint = Paint()..color = const Color(0xFFFFC857);

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
    final center = Offset(size.x / 2, size.y / 2);
    switch (style) {
      case EnemyShotStyle.cannon:
        canvas.drawCircle(center, size.x / 2, _cannonPaint);
      case EnemyShotStyle.laser:
        canvas.drawRRect(
          RRect.fromRectAndRadius(size.toRect(), const Radius.circular(2)),
          _laserPaint,
        );
      case EnemyShotStyle.missile:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, 0)
            ..lineTo(size.x, center.dy)
            ..lineTo(center.dx, size.y)
            ..lineTo(0, center.dy)
            ..close(),
          _missilePaint,
        );
    }
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
