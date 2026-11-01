import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../../domain/entities/boss_component_state.dart';
import '../../domain/entities/boss_definition.dart';
import '../../domain/entities/boss_state.dart';

/// Visual container for a boss; mirrors [BossState] position and phase.
///
/// Its local origin is the boss center, so parts are placed directly at the
/// offsets from their definitions.
class BossComponent extends PositionComponent {
  BossComponent({required this.boss})
    : super(position: Vector2(boss.x, boss.y));

  final BossState boss;
  final Map<String, BossPartComponent> _parts = {};
  bool _leaving = false;

  @override
  Future<void> onLoad() async {
    for (final definition in boss.definition.components) {
      final part = BossPartComponent(
        boss: boss,
        definition: definition,
        state: boss.component(definition.id)!,
      );
      _parts[definition.id] = part;
      add(part);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_leaving) position.setValues(boss.x, boss.y);
  }

  void onPartDestroyed(String componentId) =>
      _parts[componentId]?.markDestroyed();

  void flyAway() {
    if (_leaving) return;
    _leaving = true;
    _disableHitboxes();
    add(
      MoveEffect.by(
        Vector2(0, -boss.arena.height * 0.6),
        EffectController(duration: 1.2, curve: Curves.easeIn),
        onComplete: removeFromParent,
      ),
    );
  }

  void explode() {
    if (_leaving) return;
    _leaving = true;
    _disableHitboxes();
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.5),
        onComplete: removeFromParent,
      ),
    );
  }

  void _disableHitboxes() {
    for (final part in _parts.values) {
      part.markDestroyed();
    }
  }
}

/// One destructible part of the boss. It owns the hitbox that player
/// projectiles collide with.
class BossPartComponent extends PositionComponent {
  BossPartComponent({
    required this.boss,
    required this.definition,
    required this.state,
  }) : super(
         position: Vector2(definition.offsetX, definition.offsetY),
         size: Vector2(definition.width, definition.height),
         anchor: Anchor.center,
         // Outer layers are drawn over the parts they cover.
         priority: switch (definition.kind) {
           BossComponentKind.core => 0,
           BossComponentKind.cannon => 1,
           BossComponentKind.armor => 2,
           BossComponentKind.hull => 3,
         },
       );

  final BossState boss;
  final BossComponentDefinition definition;
  final BossComponentState state;
  late final ShapeHitbox _hitbox;

  String get componentId => definition.id;

  static final _destroyedPaint = Paint()..color = const Color(0xFF3A3F4B);
  static final _cannonPaint = Paint()..color = const Color(0xFFB0B7C6);
  static final _armorPaint = Paint()..color = const Color(0xFF8C5A3C);
  static final _hullPaint = Paint()..color = const Color(0xFF56627A);
  static final _hullSeamPaint = Paint()
    ..color = const Color(0xFF3A4458)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _coveredShadePaint = Paint()..color = const Color(0x99000000);
  static final _coreClosedPaint = Paint()..color = const Color(0xFF7A1E2C);
  static final _coreOpenPaint = Paint()..color = const Color(0xFFFF4D6D);
  static final _coreGlowPaint = Paint()
    ..color = const Color(0x66FF4D6D)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  static final _escapeTintPaint = Paint()..color = const Color(0x55FFD54F);
  static final _shieldPaint = Paint()
    ..color = const Color(0xAA4DD0E1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _adaptedPaint = Paint()
    ..color = const Color(0xFF4DD0E1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  Future<void> onLoad() async {
    _hitbox = definition.kind == BossComponentKind.core
        ? CircleHitbox(collisionType: CollisionType.passive)
        : RectangleHitbox(collisionType: CollisionType.passive);
    add(_hitbox);
  }

  void markDestroyed() {
    _hitbox.collisionType = CollisionType.inactive;
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    if (state.isDestroyed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(rect.shortestSide * 0.2),
          const Radius.circular(3),
        ),
        _destroyedPaint,
      );
      return;
    }
    switch (definition.kind) {
      case BossComponentKind.core:
        final center = rect.center;
        final radius = rect.shortestSide / 2;
        if (boss.isCoreVulnerable) {
          canvas.drawCircle(center, radius * 1.4, _coreGlowPaint);
          canvas.drawCircle(center, radius, _coreOpenPaint);
        } else {
          canvas.drawCircle(center, radius, _coreClosedPaint);
        }
        if (boss.isCoreShielded) {
          canvas.drawCircle(center, radius + 6, _shieldPaint);
        }
      case BossComponentKind.armor:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          _armorPaint,
        );
      case BossComponentKind.hull:
        final hull = RRect.fromRectAndRadius(rect, const Radius.circular(2));
        canvas.drawRRect(hull, _hullPaint);
        canvas.drawRRect(hull.deflate(3), _hullSeamPaint);
      case BossComponentKind.cannon:
        canvas.drawRect(rect, _cannonPaint);
    }
    if (boss.isCovered(definition.id)) {
      final shade = rect.inflate(1);
      definition.kind == BossComponentKind.core
          ? canvas.drawCircle(
              shade.center,
              shade.shortestSide / 2,
              _coveredShadePaint,
            )
          : canvas.drawRect(shade, _coveredShadePaint);
    }
    if (boss.modifiers.damageMultipliers.isNotEmpty &&
        definition.kind != BossComponentKind.core) {
      canvas.drawRect(rect.inflate(2), _adaptedPaint);
    }
    if (boss.phase == BossPhase.escaping && (boss.escapeTimeLeft * 4) % 2 < 1) {
      canvas.drawRect(rect, _escapeTintPaint);
    }
  }
}
