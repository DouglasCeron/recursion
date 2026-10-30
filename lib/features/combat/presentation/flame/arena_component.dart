import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

/// Static arena backdrop that also captures drag input anywhere on screen.
class ArenaComponent extends PositionComponent with DragCallbacks {
  ArenaComponent({required Vector2 arenaSize, required this.onDrag})
    : super(size: arenaSize, priority: -1);

  final void Function(double dx, double dy) onDrag;

  final _backgroundPaint = Paint()..color = const Color(0xFF070A1C);
  final _starPaint = Paint()..color = const Color(0x99CFE3FF);
  final _borderPaint = Paint()
    ..color = const Color(0x332E7DFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final List<(Offset, double)> _stars;

  @override
  Future<void> onLoad() async {
    final random = math.Random(7);
    _stars = List.generate(
      70,
      (_) => (
        Offset(random.nextDouble() * size.x, random.nextDouble() * size.y),
        0.6 + random.nextDouble() * 1.2,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRect(rect, _backgroundPaint);
    for (final (offset, radius) in _stars) {
      canvas.drawCircle(offset, radius, _starPaint);
    }
    canvas.drawRect(rect.deflate(1), _borderPaint);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    onDrag(event.localDelta.x, event.localDelta.y);
  }
}
