import 'dart:math' as math;

import '../../../core/geometry/arena_bounds.dart';
import 'weapon_definition.dart';

/// Authoritative state of the player's ship during a battle.
///
/// Movement is destination-based: input moves a steering point and the ship
/// travels toward it at [maxSpeed], which keeps motion frame-rate independent
/// and testable without rendering.
class ShipState {
  ShipState({
    required this.arena,
    required this._weapon,
    this.maxSpeed = 420,
    this.halfWidth = 18,
    this.halfHeight = 20,
    double? x,
    double? y,
  }) {
    _x = arena.clampX(x ?? arena.width / 2, halfExtent: halfWidth);
    _y = arena.clampY(y ?? arena.height * 0.85, halfExtent: halfHeight);
    _destinationX = _x;
    _destinationY = _y;
  }

  final ArenaBounds arena;
  final double maxSpeed;
  final double halfWidth;
  final double halfHeight;

  WeaponDefinition _weapon;
  late double _x;
  late double _y;
  late double _destinationX;
  late double _destinationY;
  double _cooldown = 0;

  double get x => _x;
  double get y => _y;
  double get destinationX => _destinationX;
  double get destinationY => _destinationY;
  WeaponDefinition get weapon => _weapon;

  /// Remaining seconds until the equipped weapon can fire again.
  double get cooldown => _cooldown;

  /// Moves the steering point by a relative offset, kept inside the arena.
  void steerBy(double dx, double dy) {
    _destinationX = arena.clampX(_destinationX + dx, halfExtent: halfWidth);
    _destinationY = arena.clampY(_destinationY + dy, halfExtent: halfHeight);
  }

  void equip(WeaponDefinition weapon) {
    _weapon = weapon;
    _cooldown = 0;
  }

  /// Advances movement and weapon cooldown by [dt] seconds.
  void update(double dt) {
    if (dt <= 0) return;
    _cooldown = math.max(0, _cooldown - dt);

    final dx = _destinationX - _x;
    final dy = _destinationY - _y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final step = maxSpeed * dt;
    if (distance <= step) {
      _x = _destinationX;
      _y = _destinationY;
    } else {
      _x += dx / distance * step;
      _y += dy / distance * step;
    }
  }

  /// Fires if the weapon is ready, starting a new cooldown.
  bool tryFire() {
    if (_cooldown > 0) return false;
    _cooldown = _weapon.fireInterval;
    return true;
  }
}
