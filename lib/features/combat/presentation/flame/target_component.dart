import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../domain/entities/target_state.dart';

/// Visual representation of a destructible target; mirrors [TargetState].
///
/// The side-to-side drift is purely cosmetic and does not affect any rule.
class TargetComponent extends PositionComponent {
  TargetComponent({
    required this.target,
    required Vector2 position,
    required this.driftRange,
  }) : _anchorX = position.x,
       super(position: position, size: Vector2(72, 48), anchor: Anchor.center);

  final TargetState target;
  final double driftRange;
  final double _anchorX;
  double _time = 0;
  bool _exploding = false;

  String get targetId => target.id;

  final _bodyPaint = Paint()..color = const Color(0xFFE0576B);
  final _corePaint = Paint()..color = const Color(0xFF3A0D16);
  final _barBackPaint = Paint()..color = const Color(0x55FFFFFF);
  final _barPaint = Paint()..color = const Color(0xFF7CFFB2);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_exploding) return;
    _time += dt;
    position.x = _anchorX + math.sin(_time * 0.9) * driftRange;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final body = Path()
      ..moveTo(w * 0.2, 0)
      ..lineTo(w * 0.8, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.8, h)
      ..lineTo(w * 0.2, h)
      ..lineTo(0, h * 0.5)
      ..close();
    canvas.drawPath(body, _bodyPaint);
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.2, _corePaint);

    final ratio = target.integrity / target.maxIntegrity;
    final bar = Rect.fromLTWH(0, -10, w, 4);
    canvas.drawRect(bar, _barBackPaint);
    canvas.drawRect(
      Rect.fromLTWH(bar.left, bar.top, bar.width * ratio, bar.height),
      _barPaint,
    );
  }

  void explode() {
    if (_exploding) return;
    _exploding = true;
    children.whereType<ShapeHitbox>().forEach((hitbox) {
      hitbox.collisionType = CollisionType.inactive;
    });
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.35),
        onComplete: removeFromParent,
      ),
    );
  }
}
