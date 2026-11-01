import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/rules/escape_rule.dart';

void main() {
  const rule = EscapeRule(coreIntegrityThreshold: 0.3, warningDuration: 5);

  test('announces at or below the core threshold', () {
    expect(rule.shouldAnnounce(integrity: 121, maxIntegrity: 400), isFalse);
    expect(rule.shouldAnnounce(integrity: 120, maxIntegrity: 400), isTrue);
    expect(rule.shouldAnnounce(integrity: 10, maxIntegrity: 400), isTrue);
  });

  test('never announces without integrity to measure', () {
    expect(rule.shouldAnnounce(integrity: 0, maxIntegrity: 0), isFalse);
  });
}
