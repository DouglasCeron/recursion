import 'dart:math' as math;
import 'dart:ui';

/// How boss parts show damage without integrity bars: the fill shifts from
/// the part's own color through yellow, orange and red to dark red, and
/// cracks appear from [crackThreshold] on, so the cue does not rely on color
/// alone.
abstract final class DamagePalette {
  static const yellow = Color(0xFFFFD54F);
  static const orange = Color(0xFFFF9800);
  static const red = Color(0xFFE53935);
  static const darkRed = Color(0xFF6D0F0F);

  /// Damage taken (0 = intact, 1 = destroyed) at which the first crack shows.
  static const crackThreshold = 0.5;

  /// Damage at which every crack shows.
  static const fullCracks = 0.75;
  static const maxCracks = 3;

  /// Share of integrity lost, clamped to 0..1.
  static double damageOf(int integrity, int maxIntegrity) =>
      maxIntegrity <= 0 ? 0 : (1 - integrity / maxIntegrity).clamp(0.0, 1.0);

  /// Fill color of a part with [base] color after [damage].
  static Color fillFor(Color base, double damage) {
    final stops = [base, yellow, orange, red, darkRed];
    final position = damage.clamp(0.0, 1.0) * (stops.length - 1);
    final index = position.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[index], stops[index + 1], position - index)!;
  }

  /// Number of cracks drawn on a part after [damage].
  static int cracksFor(double damage) {
    if (damage < crackThreshold) return 0;
    if (damage >= fullCracks) return maxCracks;
    return 1;
  }

  /// Zigzag crack lines inside [rect]. The pattern depends only on [seed],
  /// so a part keeps the same cracks from frame to frame.
  static List<List<Offset>> cracksIn(Rect rect, int count, int seed) {
    final random = math.Random(seed);
    return [for (var i = 0; i < count; i++) _crack(rect, random)];
  }

  /// One crack running from near the top of [rect] to near its bottom.
  static List<Offset> _crack(Rect rect, math.Random random) {
    const segments = 3;
    final sway = math.min(rect.width, 16.0);
    final points = [
      Offset(
        rect.left + rect.width * (0.15 + 0.7 * random.nextDouble()),
        rect.top + rect.height * 0.1,
      ),
    ];
    for (var s = 1; s <= segments; s++) {
      points.add(
        Offset(
          (points.last.dx + (random.nextDouble() - 0.5) * sway).clamp(
            rect.left,
            rect.right,
          ),
          rect.top + rect.height * (0.1 + 0.8 * s / segments),
        ),
      );
    }
    return points;
  }
}
