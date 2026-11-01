import '../rules/escape_rule.dart';
import '../rules/vulnerability_window.dart';
import 'boss_component_state.dart';

/// Horizontal area of a boss, used to describe where the player focuses.
enum BossZone { left, center, right }

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
    this.dropItemId,
    this.coveredBy = const [],
    this.reinforced = false,
  });

  /// Parts at most this far from the boss center belong to the center zone.
  static const centerZoneHalfWidth = 20.0;

  final String id;
  final String name;
  final BossComponentKind kind;
  final int maxIntegrity;
  final double offsetX;
  final double offsetY;
  final double width;
  final double height;

  /// Item left on the battlefield when this part is destroyed, if any.
  final String? dropItemId;

  /// Outer parts protecting this one. While any of them stands, hits on this
  /// part are absorbed by the first one still standing.
  final List<String> coveredBy;

  /// Whether this part was strengthened by a zone reinforcement.
  final bool reinforced;

  BossZone get zone => switch (offsetX) {
    < -centerZoneHalfWidth => BossZone.left,
    > centerZoneHalfWidth => BossZone.right,
    _ => BossZone.center,
  };

  double get left => offsetX - width / 2;
  double get right => offsetX + width / 2;
  double get top => offsetY - height / 2;
  double get bottom => offsetY + height / 2;

  BossComponentDefinition copyWith({
    int? maxIntegrity,
    List<String>? coveredBy,
    bool? reinforced,
  }) => BossComponentDefinition(
    id: id,
    name: name,
    kind: kind,
    maxIntegrity: maxIntegrity ?? this.maxIntegrity,
    offsetX: offsetX,
    offsetY: offsetY,
    width: width,
    height: height,
    dropItemId: dropItemId,
    coveredBy: coveredBy ?? this.coveredBy,
    reinforced: reinforced ?? this.reinforced,
  );
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
    this.shieldBreakDuration,
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

  /// If set, the core is shielded (immune) while any cannon is operational.
  /// Destroying a cannon drops the shield for this many seconds; once no
  /// cannon is left the shield stays down.
  final double? shieldBreakDuration;

  bool get hasCoreShield => shieldBreakDuration != null;

  BossDefinition withComponents(List<BossComponentDefinition> components) =>
      BossDefinition(
        id: id,
        name: name,
        components: components,
        coreWindow: coreWindow,
        coreVulnerableMultiplier: coreVulnerableMultiplier,
        escapeRule: escapeRule,
        aimedShot: aimedShot,
        burst: burst,
        initialAttackDelay: initialAttackDelay,
        verticalPosition: verticalPosition,
        driftRange: driftRange,
        driftSpeed: driftSpeed,
        enragedDriftSpeed: enragedDriftSpeed,
        shieldBreakDuration: shieldBreakDuration,
      );

  BossComponentDefinition component(String id) =>
      components.firstWhere((c) => c.id == id);
}
