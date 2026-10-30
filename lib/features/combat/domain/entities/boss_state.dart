import 'dart:math' as math;

import '../../../../core/geometry/arena_bounds.dart';
import '../events/battle_event.dart';
import '../rules/damage_rules.dart';
import 'boss_component_state.dart';
import 'boss_definition.dart';

enum BossPhase { engaged, escaping, escaped, defeated }

enum BossAttackPattern { aimedCannon, radialBurst }

/// A projectile the boss wants to fire this tick, before it gets an id.
class EnemyShot {
  const EnemyShot({
    required this.originX,
    required this.originY,
    required this.velocityX,
    required this.velocityY,
    required this.damage,
  });

  final double originX;
  final double originY;
  final double velocityX;
  final double velocityY;
  final int damage;
}

typedef BossUpdate = ({List<BattleEvent> events, List<EnemyShot> shots});

/// Authoritative runtime state of a boss and its destructible parts.
class BossState {
  BossState({required this.definition, required this.arena})
    : y = arena.height * definition.verticalPosition,
      _x = arena.width / 2,
      _attackCooldown = definition.initialAttackDelay,
      _components = {
        for (final c in definition.components)
          c.id: BossComponentState(
            id: c.id,
            kind: c.kind,
            maxIntegrity: c.maxIntegrity,
          ),
      };

  final BossDefinition definition;
  final ArenaBounds arena;
  final double y;
  final Map<String, BossComponentState> _components;

  double _x;
  double _time = 0;
  double _driftPhase = 0;
  double _attackCooldown;
  double _escapeTimeLeft = 0;
  bool _coreWasVulnerable = false;
  BossPhase _phase = BossPhase.engaged;

  double get x => _x;
  BossPhase get phase => _phase;
  double get escapeTimeLeft => _escapeTimeLeft;
  bool get isActive =>
      _phase == BossPhase.engaged || _phase == BossPhase.escaping;
  Iterable<BossComponentState> get components => _components.values;
  BossComponentState? component(String id) => _components[id];

  bool get isCannonOperational => _components.values.any(
    (c) => c.kind == BossComponentKind.cannon && !c.isDestroyed,
  );

  BossAttackPattern get attackPattern => isCannonOperational
      ? BossAttackPattern.aimedCannon
      : BossAttackPattern.radialBurst;

  bool get isCoreVulnerable =>
      isActive && definition.coreWindow.isOpenAt(_time);

  /// Current arena position of a part's center.
  (double, double) componentPosition(String id) {
    final part = definition.component(id);
    return (_x + part.offsetX, y + part.offsetY);
  }

  int get totalIntegrity =>
      _components.values.fold(0, (sum, c) => sum + c.integrity);
  int get totalMaxIntegrity =>
      _components.values.fold(0, (sum, c) => sum + c.maxIntegrity);

  /// Advances movement, weak point schedule, escape countdown and attacks.
  /// [targetX]/[targetY] is the ship position used for aimed shots.
  BossUpdate update(
    double dt, {
    required double targetX,
    required double targetY,
  }) {
    if (!isActive || dt <= 0) return (events: const [], shots: const []);
    final events = <BattleEvent>[];
    _time += dt;
    _driftPhase +=
        dt *
        (isCannonOperational
            ? definition.driftSpeed
            : definition.enragedDriftSpeed);
    _x =
        arena.width / 2 +
        math.sin(_driftPhase) * arena.width * definition.driftRange;

    final vulnerable = isCoreVulnerable;
    if (vulnerable != _coreWasVulnerable) {
      _coreWasVulnerable = vulnerable;
      events.add(
        vulnerable ? const WeakPointExposed() : const WeakPointClosed(),
      );
    }

    if (_phase == BossPhase.escaping) {
      _escapeTimeLeft = math.max(0, _escapeTimeLeft - dt);
      if (_escapeTimeLeft == 0) {
        _phase = BossPhase.escaped;
        events.add(const BossEscaped());
        return (events: events, shots: const []);
      }
    }

    _attackCooldown -= dt;
    if (_attackCooldown > 0) return (events: events, shots: const []);
    final pattern = attackPattern;
    final shots = switch (pattern) {
      BossAttackPattern.aimedCannon => [_aimedShot(targetX, targetY)],
      BossAttackPattern.radialBurst => _burst(),
    };
    final interval = switch (pattern) {
      BossAttackPattern.aimedCannon => definition.aimedShot.interval,
      BossAttackPattern.radialBurst => definition.burst.interval,
    };
    _attackCooldown = math.max(_attackCooldown + interval, 0);
    return (events: events, shots: shots);
  }

  /// Applies a hit with [baseDamage] to [componentId].
  ///
  /// Returns `null` when the hit is not accepted (unknown or destroyed part,
  /// boss no longer active), so the caller can keep the projectile alive.
  List<BattleEvent>? applyHit({
    required String componentId,
    required int projectileId,
    required int baseDamage,
  }) {
    if (!isActive) return null;
    final component = _components[componentId];
    if (component == null || component.isDestroyed) return null;

    final weakPointBonus =
        component.kind == BossComponentKind.core && isCoreVulnerable;
    final outcome = component.receiveDamage(
      DamageRules.damageFor(
        baseDamage: baseDamage,
        multiplier: weakPointBonus ? definition.coreVulnerableMultiplier : 1,
      ),
    );
    final events = <BattleEvent>[
      BossComponentHit(
        componentId: componentId,
        projectileId: projectileId,
        damage: outcome.damageApplied,
        remainingIntegrity: outcome.remainingIntegrity,
        weakPointBonus: weakPointBonus,
      ),
    ];

    if (outcome.destroyedNow) {
      events.add(
        BossComponentDestroyed(componentId: componentId, kind: component.kind),
      );
      switch (component.kind) {
        case BossComponentKind.core:
          _phase = BossPhase.defeated;
          events.add(const BossDefeated());
          return events;
        case BossComponentKind.cannon when !isCannonOperational:
          events.add(BossBehaviorChanged(pattern: attackPattern));
        case BossComponentKind.cannon || BossComponentKind.armor:
          break;
      }
    }

    final rule = definition.escapeRule;
    if (_phase == BossPhase.engaged &&
        rule.shouldAnnounce(
          integrity: totalIntegrity,
          maxIntegrity: totalMaxIntegrity,
        )) {
      _phase = BossPhase.escaping;
      _escapeTimeLeft = rule.warningDuration;
      events.add(BossEscapeWarning(secondsUntilEscape: rule.warningDuration));
    }
    return events;
  }

  EnemyShot _aimedShot(double targetX, double targetY) {
    final cannon = definition.components.firstWhere(
      (c) => c.kind == BossComponentKind.cannon,
    );
    final originX = _x + cannon.offsetX;
    final originY = y + cannon.offsetY + cannon.height / 2;
    final dx = targetX - originX;
    final dy = targetY - originY;
    final distance = math.sqrt(dx * dx + dy * dy);
    final pattern = definition.aimedShot;
    final (dirX, dirY) = distance == 0
        ? (0.0, 1.0)
        : (dx / distance, dy / distance);
    return EnemyShot(
      originX: originX,
      originY: originY,
      velocityX: dirX * pattern.speed,
      velocityY: dirY * pattern.speed,
      damage: pattern.damage,
    );
  }

  List<EnemyShot> _burst() {
    final core = definition.components.firstWhere(
      (c) => c.kind == BossComponentKind.core,
    );
    final pattern = definition.burst;
    final originX = _x + core.offsetX;
    final originY = y + core.offsetY + core.height / 2;
    final step = pattern.count == 1
        ? 0.0
        : pattern.spreadDegrees / (pattern.count - 1);
    final firstAngle = 90 - pattern.spreadDegrees / 2;
    return [
      for (var i = 0; i < pattern.count; i++)
        _shotAtAngle(
          originX,
          originY,
          (firstAngle + step * i) * math.pi / 180,
          pattern.speed,
          pattern.damage,
        ),
    ];
  }

  static EnemyShot _shotAtAngle(
    double x,
    double y,
    double radians,
    double speed,
    int damage,
  ) => EnemyShot(
    originX: x,
    originY: y,
    velocityX: math.cos(radians) * speed,
    velocityY: math.sin(radians) * speed,
    damage: damage,
  );
}
