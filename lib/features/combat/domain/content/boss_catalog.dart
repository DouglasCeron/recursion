import '../entities/boss_component_state.dart';
import '../entities/boss_definition.dart';
import '../rules/escape_rule.dart';
import '../rules/vulnerability_window.dart';

/// Static boss content available in the prototype.
abstract final class BossCatalog {
  /// First boss. The armor plate shields the core from below, and the cannon
  /// sits under the armor, so players naturally break through the front parts
  /// before reaching the core.
  static const sentinel = BossDefinition(
    id: 'boss.sentinel',
    name: 'Sentinel',
    components: [
      BossComponentDefinition(
        id: 'sentinel.core',
        name: 'Core',
        kind: BossComponentKind.core,
        maxIntegrity: 400,
        offsetX: 0,
        offsetY: -6,
        width: 44,
        height: 44,
      ),
      BossComponentDefinition(
        id: 'sentinel.armor',
        name: 'Armor',
        kind: BossComponentKind.armor,
        maxIntegrity: 100,
        offsetX: 0,
        offsetY: 26,
        width: 120,
        height: 16,
      ),
      BossComponentDefinition(
        id: 'sentinel.cannon',
        name: 'Cannon',
        kind: BossComponentKind.cannon,
        maxIntegrity: 100,
        offsetX: 0,
        offsetY: 48,
        width: 20,
        height: 28,
        dropItemId: 'weapon.heavy_cannon',
      ),
    ],
    coreWindow: VulnerabilityWindow(period: 8, openDuration: 3),
    coreVulnerableMultiplier: 2,
    escapeRule: EscapeRule(integrityThreshold: 0.25, warningDuration: 5),
    aimedShot: AimedShotPattern(interval: 1.2, speed: 260, damage: 15),
    burst: BurstPattern(
      interval: 2,
      speed: 180,
      damage: 8,
      count: 5,
      spreadDegrees: 80,
    ),
    initialAttackDelay: 1.5,
    verticalPosition: 0.18,
    driftRange: 0.25,
    driftSpeed: 0.6,
    enragedDriftSpeed: 1.1,
  );
}
