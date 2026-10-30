import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/rules/damage_rules.dart';

void main() {
  group('DamageRules.damageFor', () {
    test('returns base damage without multiplier', () {
      expect(DamageRules.damageFor(baseDamage: 10), 10);
    });

    test('applies and rounds the multiplier', () {
      expect(DamageRules.damageFor(baseDamage: 10, multiplier: 1.5), 15);
      expect(DamageRules.damageFor(baseDamage: 7, multiplier: 0.5), 4);
    });

    test('never returns negative damage', () {
      expect(DamageRules.damageFor(baseDamage: -5), 0);
      expect(DamageRules.damageFor(baseDamage: 10, multiplier: -1), 0);
    });
  });

  group('DamageRules.integrityAfter', () {
    test('subtracts damage', () {
      expect(DamageRules.integrityAfter(integrity: 100, damage: 30), 70);
    });

    test('clamps at zero', () {
      expect(DamageRules.integrityAfter(integrity: 20, damage: 50), 0);
    });

    test('ignores non-positive damage', () {
      expect(DamageRules.integrityAfter(integrity: 20, damage: 0), 20);
      expect(DamageRules.integrityAfter(integrity: 20, damage: -10), 20);
    });
  });
}
