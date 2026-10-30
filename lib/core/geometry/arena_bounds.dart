/// Logical size of the static battle arena, in world units.
///
/// Rendering scales this fixed resolution to the device screen, so gameplay
/// rules can reason about positions without knowing the real screen size.
class ArenaBounds {
  const ArenaBounds({required this.width, required this.height})
    : assert(width > 0),
      assert(height > 0);

  static const standard = ArenaBounds(width: 360, height: 640);

  final double width;
  final double height;

  /// Clamps [x] so an object with [halfExtent] stays fully inside the arena.
  double clampX(double x, {double halfExtent = 0}) =>
      _clamp(x, halfExtent, width - halfExtent);

  /// Clamps [y] so an object with [halfExtent] stays fully inside the arena.
  double clampY(double y, {double halfExtent = 0}) =>
      _clamp(y, halfExtent, height - halfExtent);

  static double _clamp(double value, double min, double max) {
    if (min > max) return (min + max) / 2;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
