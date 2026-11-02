import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/presentation/flame/damage_palette.dart';

void main() {
  const base = Color(0xFF56627A);

  test('damage is the share of integrity lost, clamped', () {
    expect(DamagePalette.damageOf(100, 100), 0);
    expect(DamagePalette.damageOf(25, 100), 0.75);
    expect(DamagePalette.damageOf(0, 100), 1);
    expect(DamagePalette.damageOf(-5, 100), 1);
  });

  test('the fill goes from the part color through yellow, orange and red '
      'to dark red', () {
    expect(DamagePalette.fillFor(base, 0), base);
    expect(DamagePalette.fillFor(base, 0.25), DamagePalette.yellow);
    expect(DamagePalette.fillFor(base, 0.5), DamagePalette.orange);
    expect(DamagePalette.fillFor(base, 0.75), DamagePalette.red);
    expect(DamagePalette.fillFor(base, 1), DamagePalette.darkRed);
    expect(
      DamagePalette.fillFor(base, 0.625),
      Color.lerp(DamagePalette.orange, DamagePalette.red, 0.5),
    );
  });

  test('cracks start at half damage and grow', () {
    expect(DamagePalette.cracksFor(0.49), 0);
    expect(DamagePalette.cracksFor(0.5), 1);
    expect(DamagePalette.cracksFor(0.74), 1);
    expect(DamagePalette.cracksFor(0.75), DamagePalette.maxCracks);
    expect(DamagePalette.cracksFor(1), DamagePalette.maxCracks);
  });

  test('cracks stay inside the part and never change between frames', () {
    const rect = Rect.fromLTWH(10, 20, 28, 24);

    final first = DamagePalette.cracksIn(rect, 3, 42);
    final again = DamagePalette.cracksIn(rect, 3, 42);

    expect(first, hasLength(3));
    expect(again, first);
    for (final point in first.expand((crack) => crack)) {
      expect(rect.inflate(0.001).contains(point), isTrue, reason: '$point');
    }
  });
}
