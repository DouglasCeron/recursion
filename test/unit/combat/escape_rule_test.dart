import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/rules/escape_rule.dart';

void main() {
  const rule = EscapeRule(integrityThreshold: 0.25, warningDuration: 5);

  test('announces at or below the threshold', () {
    expect(rule.shouldAnnounce(integrity: 151, maxIntegrity: 600), isFalse);
    expect(rule.shouldAnnounce(integrity: 150, maxIntegrity: 600), isTrue);
    expect(rule.shouldAnnounce(integrity: 10, maxIntegrity: 600), isTrue);
  });

  test('never announces without integrity to measure', () {
    expect(rule.shouldAnnounce(integrity: 0, maxIntegrity: 0), isFalse);
  });
}
