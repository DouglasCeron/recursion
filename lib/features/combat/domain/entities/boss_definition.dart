import '../rules/escape_rule.dart';
import '../rules/vulnerability_window.dart';
import 'boss_component_state.dart';

/// Static description of one boss part. Offsets and sizes are in arena units
/// relative to the boss center; they define where the part can be hit.
class BossComponentDefinition {
  const BossComponentDefinition({
    required this.id,
    required this.name,
    required this.kind,
    required this.maxIntegrity,
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });

  final String id;
  final String name;
  final BossComponentKind kind;
  final int maxIntegrity;
  final double offsetX;
  final double offsetY;
  final double width;
  final double height;
}

/// Single shots aimed at the ship, fired while the cannon is operational.
class AimedShotPattern {
  const AimedShotPattern({
    required this.interval,
    required this.speed,
    required this.damage,
  });

  final double interval;
  final double speed;
  final int damage;
}

/// A downward fan of shots from the core, used once the cannon is lost.
class BurstPattern {
  const BurstPattern({
    required this.interval,
    required this.speed,
    required this.damage,
    required this.count,
    required this.spreadDegrees,
  }) : assert(count > 0);

  final double interval;
  final double speed;
  final int damage;
  final int count;
  final double spreadDegrees;
}

/// Immutable configuration of a boss encounter.
class BossDefinition {
  const BossDefinition({
    required this.id,
    required this.name,
    required this.components,
    required this.coreWindow,
    required this.coreVulnerableMultiplier,
    required this.escapeRule,
    required this.aimedShot,
    required this.burst,
    required this.initialAttackDelay,
    required this.verticalPosition,
    required this.driftRange,
    required this.driftSpeed,
    required this.enragedDriftSpeed,
  });

  final String id;
  final String name;
  final List<BossComponentDefinition> components;

  /// When the core is exposed to the [coreVulnerableMultiplier] bonus.
  final VulnerabilityWindow coreWindow;
  final double coreVulnerableMultiplier;
  final EscapeRule escapeRule;
  final AimedShotPattern aimedShot;
  final BurstPattern burst;

  /// Seconds before the first attack, giving the player time to react.
  final double initialAttackDelay;

  /// Vertical position of the boss center as a fraction of arena height.
  final double verticalPosition;

  /// Horizontal drift amplitude as a fraction of arena width.
  final double driftRange;

  /// Drift angular speed (radians per second) with and without the cannon.
  final double driftSpeed;
  final double enragedDriftSpeed;

  BossComponentDefinition component(String id) =>
      components.firstWhere((c) => c.id == id);
}
