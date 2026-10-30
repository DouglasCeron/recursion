import '../../../ship/domain/weapon_definition.dart';
import '../entities/boss_component_state.dart';
import '../entities/boss_state.dart';
import '../entities/combat_log.dart';

enum BattleOutcome { victory, defeat, bossEscaped }

/// Meaningful things that happened in a battle. Position updates are not
/// events; only state changes that feed rules, rewards, stats or tests are.
sealed class BattleEvent {
  const BattleEvent();
}

class BattleStarted extends BattleEvent {
  const BattleStarted();
}

class WeaponFired extends BattleEvent {
  const WeaponFired({
    required this.projectileId,
    required this.weaponId,
    required this.weaponType,
    required this.originX,
    required this.originY,
    required this.projectileSpeed,
  });

  final int projectileId;
  final String weaponId;
  final WeaponType weaponType;
  final double originX;
  final double originY;
  final double projectileSpeed;
}

class EnemyFired extends BattleEvent {
  const EnemyFired({
    required this.projectileId,
    required this.originX,
    required this.originY,
    required this.velocityX,
    required this.velocityY,
  });

  final int projectileId;
  final double originX;
  final double originY;
  final double velocityX;
  final double velocityY;
}

class BossComponentHit extends BattleEvent {
  const BossComponentHit({
    required this.componentId,
    required this.projectileId,
    required this.damage,
    required this.remainingIntegrity,
    required this.weakPointBonus,
  });

  final String componentId;
  final int projectileId;
  final int damage;
  final int remainingIntegrity;

  /// Whether the exposed-core multiplier was applied to this hit.
  final bool weakPointBonus;
}

class BossComponentDestroyed extends BattleEvent {
  const BossComponentDestroyed({required this.componentId, required this.kind});

  final String componentId;
  final BossComponentKind kind;
}

class BossBehaviorChanged extends BattleEvent {
  const BossBehaviorChanged({required this.pattern});

  final BossAttackPattern pattern;
}

class WeakPointExposed extends BattleEvent {
  const WeakPointExposed();
}

class WeakPointClosed extends BattleEvent {
  const WeakPointClosed();
}

class BossEscapeWarning extends BattleEvent {
  const BossEscapeWarning({required this.secondsUntilEscape});

  final double secondsUntilEscape;
}

class BossEscaped extends BattleEvent {
  const BossEscaped();
}

class BossDefeated extends BattleEvent {
  const BossDefeated();
}

class ItemDropped extends BattleEvent {
  const ItemDropped({
    required this.dropId,
    required this.itemId,
    required this.x,
    required this.y,
    required this.lifetime,
  });

  final int dropId;
  final String itemId;
  final double x;
  final double y;
  final double lifetime;
}

/// The player picked up a drop; only now does the item become theirs.
class ItemCollected extends BattleEvent {
  const ItemCollected({required this.dropId, required this.itemId});

  final int dropId;
  final String itemId;
}

class ItemExpired extends BattleEvent {
  const ItemExpired({required this.dropId, required this.itemId});

  final int dropId;
  final String itemId;
}

class ObserverHit extends BattleEvent {
  const ObserverHit({
    required this.projectileId,
    required this.damage,
    required this.remainingIntegrity,
  });

  final int projectileId;
  final int damage;
  final int remainingIntegrity;
}

class ObserverDestroyed extends BattleEvent {
  const ObserverDestroyed();
}

/// The observer survived and sent what it recorded to the enemy faction.
class ObserverTransmitted extends BattleEvent {
  const ObserverTransmitted({required this.stats});

  final CombatStats stats;
}

class ShipHit extends BattleEvent {
  const ShipHit({required this.damage, required this.remainingHull});

  final int damage;
  final int remainingHull;
}

class ShipDestroyed extends BattleEvent {
  const ShipDestroyed();
}

class BattleCompleted extends BattleEvent {
  const BattleCompleted({required this.outcome});

  final BattleOutcome outcome;
}
