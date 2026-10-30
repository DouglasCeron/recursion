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
    this.maxHull = 100,
    this.invulnerabilityDuration = 0.75,
    double? x,
    double? y,
  }) : assert(maxHull > 0),
       _hull = maxHull {
    _x = arena.clampX(x ?? arena.width / 2, halfExtent: halfWidth);
    _y = arena.clampY(y ?? arena.height * 0.85, halfExtent: halfHeight);
    _destinationX = _x;
    _destinationY = _y;
  }

  final ArenaBounds arena;
  final double maxSpeed;
  final double halfWidth;
  final double halfHeight;
  final int maxHull;

  /// Seconds after taking damage during which further hits are ignored.
  final double invulnerabilityDuration;

  WeaponDefinition _weapon;
  late double _x;
  late double _y;
  late double _destinationX;
  late double _destinationY;
  double _cooldown = 0;
  int _hull;
  double _invulnerableTimeLeft = 0;

  double get x => _x;
  double get y => _y;
  double get destinationX => _destinationX;
  double get destinationY => _destinationY;
  WeaponDefinition get weapon => _weapon;
  int get hull => _hull;
  bool get isDestroyed => _hull == 0;
  bool get isInvulnerable => _invulnerableTimeLeft > 0;

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

  /// Advances movement, weapon cooldown and invulnerability by [dt] seconds.
  void update(double dt) {
    if (dt <= 0 || isDestroyed) return;
    _cooldown = math.max(0, _cooldown - dt);
    _invulnerableTimeLeft = math.max(0, _invulnerableTimeLeft - dt);

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
    if (isDestroyed || _cooldown > 0) return false;
    _cooldown = _weapon.fireInterval;
    return true;
  }

  /// Applies [damage] to the hull and returns the amount actually taken.
  /// Damage is ignored while invulnerable or after destruction.
  int receiveDamage(int damage) {
    if (damage <= 0 || isDestroyed || isInvulnerable) return 0;
    final before = _hull;
    _hull = math.max(0, _hull - damage);
    _invulnerableTimeLeft = invulnerabilityDuration;
    return before - _hull;
  }
}
