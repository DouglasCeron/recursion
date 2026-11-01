import '../entities/boss_component_state.dart';
import '../entities/boss_definition.dart';
import '../rules/escape_rule.dart';
import '../rules/vulnerability_window.dart';

/// Static boss content available in the prototype.
abstract final class BossCatalog {
  /// First boss. The armor plate covers the core, and the cannon sits in
  /// front of the armor, so players break through the front parts before
  /// reaching the core. Two hull wings flank the armor and only soak shots.
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

  /// Second boss. Two side cannons fire in turns and power a shield around
  /// the core; breaking a cannon opens the shield briefly. Each cannon sits
  /// behind a hull housing and the core behind a front plate. This boss
  /// receives countermeasures from enemy intel.
  static const warden = BossDefinition(
    id: 'boss.warden',
    name: 'Warden',
    components: [
      BossComponentDefinition(
        id: 'warden.core',
        name: 'Core',
        kind: BossComponentKind.core,
        maxIntegrity: 360,
        offsetX: 0,
        offsetY: -4,
        width: 48,
        height: 48,
        coveredBy: ['warden.plate'],
      ),
      BossComponentDefinition(
        id: 'warden.plate',
        name: 'Front plate',
        kind: BossComponentKind.armor,
        maxIntegrity: 100,
        offsetX: 0,
        offsetY: 30,
        width: 64,
        height: 12,
      ),
      BossComponentDefinition(
        id: 'warden.cannon_left',
        name: 'Left cannon',
        kind: BossComponentKind.cannon,
        maxIntegrity: 120,
        offsetX: -62,
        offsetY: 18,
        width: 22,
        height: 34,
        coveredBy: ['warden.housing_left'],
      ),
      BossComponentDefinition(
        id: 'warden.housing_left',
        name: 'Left housing',
        kind: BossComponentKind.hull,
        maxIntegrity: 80,
        offsetX: -62,
        offsetY: 42,
        width: 34,
        height: 12,
      ),
      BossComponentDefinition(
        id: 'warden.cannon_right',
        name: 'Right cannon',
        kind: BossComponentKind.cannon,
        maxIntegrity: 120,
        offsetX: 62,
        offsetY: 18,
        width: 22,
        height: 34,
        coveredBy: ['warden.housing_right'],
      ),
      BossComponentDefinition(
        id: 'warden.housing_right',
        name: 'Right housing',
        kind: BossComponentKind.hull,
        maxIntegrity: 80,
        offsetX: 62,
        offsetY: 42,
        width: 34,
        height: 12,
      ),
    ],
    coreWindow: VulnerabilityWindow(period: 8, openDuration: 3),
    coreVulnerableMultiplier: 2,
    escapeRule: EscapeRule(coreIntegrityThreshold: 0.3, warningDuration: 5),
    aimedShot: AimedShotPattern(interval: 0.9, speed: 280, damage: 12),
    burst: BurstPattern(
      interval: 1.6,
      speed: 190,
      damage: 8,
      count: 7,
      spreadDegrees: 100,
    ),
    initialAttackDelay: 1.5,
    verticalPosition: 0.2,
    driftRange: 0.15,
    driftSpeed: 0.5,
    enragedDriftSpeed: 0.9,
    shieldBreakDuration: 3,
  );

  static const all = [sentinel, warden];

  static BossDefinition? byId(String id) {
    for (final boss in all) {
      if (boss.id == id) return boss;
    }
    return null;
  }
}
