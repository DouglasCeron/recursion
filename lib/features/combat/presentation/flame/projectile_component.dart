import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../../ship/domain/weapon_definition.dart';
import 'boss_component.dart';
import 'observer_component.dart';
import 'space_game.dart';

/// A player projectile. It only moves and reports collisions; damage is
/// decided by the battle state using [projectileId].
class ProjectileComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<SpaceGame> {
  ProjectileComponent({
    required this.projectileId,
    required Vector2 origin,
    required this.speed,
    required WeaponType weaponType,
  }) : _paint = Paint()..color = _colorFor(weaponType),
       super(
         position: origin,
         size: _sizeFor(weaponType),
         anchor: Anchor.center,
       );

  final int projectileId;
  final double speed;
  final Paint _paint;
  bool _resolved = false;

  static Vector2 _sizeFor(WeaponType type) => switch (type) {
    WeaponType.heavyCannon => Vector2(9, 16),
    WeaponType.blaster ||
    WeaponType.missile ||
    WeaponType.laser => Vector2(4, 12),
  };

  static Color _colorFor(WeaponType type) => switch (type) {
    WeaponType.heavyCannon => const Color(0xFFFFB74D),
    WeaponType.blaster ||
    WeaponType.missile ||
    WeaponType.laser => const Color(0xFFFFF59D),
  };

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
    if (_resolved) return;
    final consumed = switch (other) {
      BossPartComponent() => game.session.reportHit(
        projectileId: projectileId,
        componentId: other.componentId,
      ),
      ObserverComponent() => game.session.reportObserverHit(projectileId),
      _ => false,
    };
    if (!consumed) return;
    _resolved = true;
    removeFromParent();
  }
}
