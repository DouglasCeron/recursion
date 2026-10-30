import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/combat/domain/entities/dropped_item.dart';

void main() {
  DroppedItem newDrop() =>
      DroppedItem(id: 1, itemId: 'item', x: 0, y: 0, lifetime: 8);

  test('can be collected exactly once', () {
    final drop = newDrop();

    expect(drop.collect(), isTrue);
    expect(drop.collect(), isFalse);
    expect(drop.status, DropStatus.collected);
  });

  test('expires once its lifetime runs out', () {
    final drop = newDrop();

    expect(drop.tick(7.9), isFalse);
    expect(drop.isAvailable, isTrue);
    expect(drop.tick(0.2), isTrue);
    expect(drop.status, DropStatus.expired);
    expect(drop.tick(1), isFalse);
  });

  test('an expired drop cannot be collected', () {
    final drop = newDrop()..expire();

    expect(drop.collect(), isFalse);
  });

  test('a collected drop no longer expires', () {
    final drop = newDrop()..collect();

    expect(drop.tick(100), isFalse);
    expect(drop.expire(), isFalse);
    expect(drop.status, DropStatus.collected);
  });
}
