import 'package:recursion/features/combat/domain/entities/boss_component_state.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/rules/escape_rule.dart';
import 'package:recursion/features/combat/domain/rules/vulnerability_window.dart';

/// A boss that is not in the campaign, used to test combat mechanics no
/// catalog boss uses yet: a core shield powered by two cannons that each
/// fire, each cannon behind a housing and the core behind a front plate.
const shieldedBoss = BossDefinition(
  id: 'test.warden',
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
