/// When a boss announces its escape and how long the warning lasts.
///
/// The escape is announced once the boss's core integrity drops to
/// [coreIntegrityThreshold] of its maximum or below. Only the core counts, so
/// adding outer structures never makes a boss flee earlier. The boss leaves
/// after [warningDuration] seconds unless it is defeated first.
class EscapeRule {
  const EscapeRule({
    required this.coreIntegrityThreshold,
    required this.warningDuration,
  }) : assert(coreIntegrityThreshold >= 0 && coreIntegrityThreshold <= 1),
       assert(warningDuration > 0);

  final double coreIntegrityThreshold;
  final double warningDuration;

  bool shouldAnnounce({required int integrity, required int maxIntegrity}) {
    if (maxIntegrity <= 0) return false;
    return integrity <= maxIntegrity * coreIntegrityThreshold;
  }
}
