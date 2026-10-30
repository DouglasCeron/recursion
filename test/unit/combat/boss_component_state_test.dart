import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/entities/boss_component_state.dart';

void main() {
  BossComponentState newComponent(int maxIntegrity) => BossComponentState(
    id: 'part',
    kind: BossComponentKind.armor,
    maxIntegrity: maxIntegrity,
  );

  test('starts at full integrity and not destroyed', () {
    final component = newComponent(50);

    expect(component.integrity, 50);
    expect(component.isDestroyed, isFalse);
  });

  test('damage reduces integrity and reports applied amount', () {
    final component = newComponent(50);

    final outcome = component.receiveDamage(20);

    expect(outcome.damageApplied, 20);
    expect(outcome.remainingIntegrity, 30);
    expect(outcome.destroyedNow, isFalse);
  });

  test('overkill only applies the remaining integrity', () {
    final component = newComponent(50);

    final outcome = component.receiveDamage(80);

    expect(outcome.damageApplied, 50);
    expect(component.integrity, 0);
    expect(outcome.destroyedNow, isTrue);
  });

  test('destruction is reported exactly once', () {
    final component = newComponent(10);

    final first = component.receiveDamage(10);
    final second = component.receiveDamage(10);

    expect(first.destroyedNow, isTrue);
    expect(second.destroyedNow, isFalse);
    expect(second.damageApplied, 0);
    expect(component.isDestroyed, isTrue);
  });
}
