import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../../ship/domain/ship_state.dart';

/// Visual representation of the player's ship; mirrors [ShipState].
class PlayerShipComponent extends PositionComponent {
  PlayerShipComponent({required this.ship})
    : super(
        position: Vector2(ship.x, ship.y),
        size: Vector2(ship.halfWidth * 2, ship.halfHeight * 2),
        anchor: Anchor.center,
      );

  final ShipState ship;
  double _blinkTime = 0;
  bool _exploding = false;

  final _hullPaint = Paint()..color = const Color(0xFF7FD4FF);
  final _cockpitPaint = Paint()..color = const Color(0xFF0B3B5C);
  final _thrusterPaint = Paint()..color = const Color(0xFFFF9F43);

  @override
  Future<void> onLoad() async {
    // A hitbox smaller than the sprite keeps near misses feeling fair.
    add(
      RectangleHitbox.relative(
        Vector2(0.5, 0.6),
        parentSize: size,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _blinkTime += dt;
    if (!_exploding) position.setValues(ship.x, ship.y);
  }

  @override
  void render(Canvas canvas) {
    if (ship.isInvulnerable && (_blinkTime * 12).floor().isEven) return;
    final w = size.x;
    final h = size.y;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, h * 0.88, w * 0.24, h * 0.12),
      _thrusterPaint,
    );
    final hull = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.9)
      ..lineTo(w / 2, h * 0.72)
      ..lineTo(0, h * 0.9)
      ..close();
    canvas.drawPath(hull, _hullPaint);
    canvas.drawCircle(Offset(w / 2, h * 0.45), w * 0.12, _cockpitPaint);
  }

  void explode() {
    if (_exploding) return;
    _exploding = true;
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.4),
        onComplete: removeFromParent,
      ),
    );
  }
}
