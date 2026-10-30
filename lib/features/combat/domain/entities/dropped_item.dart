import 'dart:math' as math;

enum DropStatus { available, collected, expired }

/// An item lying on the battlefield. It is not owned by the player until it
/// is collected; an expired drop is gone for good.
class DroppedItem {
  DroppedItem({
    required this.id,
    required this.itemId,
    required this.x,
    required this.y,
    required double lifetime,
  }) : assert(lifetime > 0),
       _timeLeft = lifetime;

  final int id;
  final String itemId;

  /// Where the item spawned, in arena units.
  final double x;
  final double y;

  double _timeLeft;
  DropStatus _status = DropStatus.available;

  double get timeLeft => _timeLeft;
  DropStatus get status => _status;
  bool get isAvailable => _status == DropStatus.available;

  /// Marks the drop as collected. Returns false if it was no longer
  /// available, so a drop can be collected at most once.
  bool collect() {
    if (!isAvailable) return false;
    _status = DropStatus.collected;
    return true;
  }

  /// Removes the drop from play. Returns false if it was no longer available.
  bool expire() {
    if (!isAvailable) return false;
    _status = DropStatus.expired;
    _timeLeft = 0;
    return true;
  }

  /// Counts down the lifetime. Returns true only on the tick it expires.
  bool tick(double dt) {
    if (!isAvailable || dt <= 0) return false;
    _timeLeft = math.max(0, _timeLeft - dt);
    return _timeLeft == 0 && expire();
  }
}
