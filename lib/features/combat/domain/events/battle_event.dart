import '../../../ship/domain/weapon_definition.dart';

enum BattleOutcome { victory }

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

class TargetHit extends BattleEvent {
  const TargetHit({
    required this.targetId,
    required this.projectileId,
    required this.damage,
    required this.remainingIntegrity,
  });

  final String targetId;
  final int projectileId;
  final int damage;
  final int remainingIntegrity;
}

class TargetDestroyed extends BattleEvent {
  const TargetDestroyed({required this.targetId});

  final String targetId;
}

class BattleCompleted extends BattleEvent {
  const BattleCompleted({required this.outcome});

  final BattleOutcome outcome;
}
