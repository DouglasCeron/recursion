import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../domain/entities/observer_drone.dart';

/// Visual representation of the enemy observer drone; mirrors
/// [ObserverDrone]. It hovers along the left edge, away from the boss, so
/// shooting it means leaving the boss's line of fire.
///
/// The vertical hover is purely cosmetic and does not affect any rule.
class ObserverComponent extends PositionComponent {
  ObserverComponent({
    required this.observer,
    required Vector2 position,
    required this.hoverRange,
  }) : _anchorY = position.y,
       super(position: position, size: Vector2(28, 28), anchor: Anchor.center);

  final ObserverDrone observer;
  final double hoverRange;
  final double _anchorY;
  double _time = 0;
  bool _exploding = false;

  static final _bodyPaint = Paint()..color = const Color(0xFF9575CD);
  static final _eyePaint = Paint()..color = const Color(0xFF1A1033);
  static final _recPaint = Paint()..color = const Color(0xFFFF1744);
  static final _barBackPaint = Paint()..color = const Color(0x55FFFFFF);
  static final _barPaint = Paint()..color = const Color(0xFFB39DDB);

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_exploding) return;
    _time += dt;
    position.y = _anchorY + math.sin(_time * 0.7) * hoverRange;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final body = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(body, _bodyPaint);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.18, _eyePaint);
    if ((_time * 2).floor().isEven) {
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.08, _recPaint);
    }

    final ratio = observer.integrity / observer.maxIntegrity;
    final bar = Rect.fromLTWH(0, -8, w, 3);
    canvas.drawRect(bar, _barBackPaint);
    canvas.drawRect(
      Rect.fromLTWH(bar.left, bar.top, bar.width * ratio, bar.height),
      _barPaint,
    );
  }

  void explode() {
    if (_exploding) return;
    _exploding = true;
    children.whereType<ShapeHitbox>().forEach(
      (hitbox) => hitbox.collisionType = CollisionType.inactive,
    );
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.35),
        onComplete: removeFromParent,
      ),
    );
  }
}
