/// When a boss announces its escape and how long the warning lasts.
///
/// The escape is announced once the boss's total integrity (sum of all parts)
/// drops to [integrityThreshold] of its maximum or below. The boss leaves after
/// [warningDuration] seconds unless it is defeated first.
class EscapeRule {
  const EscapeRule({
    required this.integrityThreshold,
    required this.warningDuration,
  }) : assert(integrityThreshold >= 0 && integrityThreshold <= 1),
       assert(warningDuration > 0);

  final double integrityThreshold;
  final double warningDuration;

  bool shouldAnnounce({required int integrity, required int maxIntegrity}) {
    if (maxIntegrity <= 0) return false;
    return integrity <= maxIntegrity * integrityThreshold;
  }
}
