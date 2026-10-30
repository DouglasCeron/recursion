import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/entities/target_state.dart';

void main() {
  test('starts at full integrity and not destroyed', () {
    final target = TargetState(id: 't', maxIntegrity: 50);

    expect(target.integrity, 50);
    expect(target.isDestroyed, isFalse);
  });

  test('damage reduces integrity and reports applied amount', () {
    final target = TargetState(id: 't', maxIntegrity: 50);

    final outcome = target.receiveDamage(20);

    expect(outcome.damageApplied, 20);
    expect(outcome.remainingIntegrity, 30);
    expect(outcome.destroyedNow, isFalse);
  });

  test('overkill only applies the remaining integrity', () {
    final target = TargetState(id: 't', maxIntegrity: 50);

    final outcome = target.receiveDamage(80);

    expect(outcome.damageApplied, 50);
    expect(target.integrity, 0);
    expect(outcome.destroyedNow, isTrue);
  });

  test('destruction is reported exactly once', () {
    final target = TargetState(id: 't', maxIntegrity: 10);

    final first = target.receiveDamage(10);
    final second = target.receiveDamage(10);

    expect(first.destroyedNow, isTrue);
    expect(second.destroyedNow, isFalse);
    expect(second.damageApplied, 0);
    expect(target.isDestroyed, isTrue);
  });
}
