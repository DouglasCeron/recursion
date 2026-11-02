import '../entities/boss_component_state.dart';
import '../entities/boss_definition.dart';
import '../rules/escape_rule.dart';
import '../rules/vulnerability_window.dart';

/// Static base boss content.
abstract final class BossCatalog {
  /// First and simplest boss. The armor plate covers the core, and the cannon
  /// sits in front of the armor, so players break through the front parts
  /// before reaching the core. Two hull wings flank the armor and only soak
  /// shots.
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
        coveredBy: ['sentinel.armor'],
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
        id: 'sentinel.hull_left',
        name: 'Left wing',
        kind: BossComponentKind.hull,
        maxIntegrity: 70,
        offsetX: -76,
        offsetY: 22,
        width: 28,
        height: 24,
      ),
      BossComponentDefinition(
        id: 'sentinel.hull_right',
        name: 'Right wing',
        kind: BossComponentKind.hull,
        maxIntegrity: 70,
        offsetX: 76,
        offsetY: 22,
        width: 28,
        height: 24,
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
    escapeRule: EscapeRule(coreIntegrityThreshold: 0.3, warningDuration: 5),
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

  /// Bosses every campaign lineage can start from. Later bosses are not
  /// listed here: they are evolutions generated from the battles fought.
  static const all = [sentinel];

  static BossDefinition? byId(String id) {
    for (final boss in all) {
      if (boss.id == id) return boss;
    }
    return null;
  }
}
