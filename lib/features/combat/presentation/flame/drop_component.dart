import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../domain/entities/dropped_item.dart';
import 'player_ship_component.dart';
import 'space_game.dart';

/// A dropped item drifting down the arena. Touching it with the ship asks
/// the battle state to collect it; the game removes it on the outcome event.
class DropComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<SpaceGame> {
  DropComponent({required this.drop})
    : super(
        position: Vector2(drop.x, drop.y),
        size: Vector2.all(22),
        anchor: Anchor.center,
      );

  /// Drift speed in arena units per second; slow enough to stay on screen for
  /// the whole drop lifetime.
  static const _fallSpeed = 50.0;

  final DroppedItem drop;
  double _time = 0;

  static final _fillPaint = Paint()..color = const Color(0xFFFFC857);
  static final _ringPaint = Paint()
    ..color = const Color(0xFFFFF3C4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final arena = game.session.arena;
    position.y = (position.y + _fallSpeed * dt).clamp(0, arena.height - size.y);
    angle = _time * 1.5;
  }

  @override
  void render(Canvas canvas) {
    final blinking = drop.timeLeft < 2 && (_time * 8).floor().isEven;
    if (blinking) return;
    final rect = size.toRect();
    canvas.drawRect(rect.deflate(5), _fillPaint);
    canvas.drawRect(rect.deflate(1), _ringPaint);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerShipComponent) game.session.reportDropTouched(drop.id);
  }
}
