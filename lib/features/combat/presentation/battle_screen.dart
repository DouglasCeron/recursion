import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/battle_state.dart';
import '../domain/entities/boss_state.dart';
import '../domain/events/battle_event.dart';
import 'battle_providers.dart';
import 'flame/space_game.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({required this.bossId, super.key});

  final String bossId;

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  SpaceGame? _game;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(battleSessionProvider(widget.bossId));
    final game = _game?.session == session
        ? _game!
        : _game = SpaceGame(session: session);
    final hud = ref.watch(battleHudProvider(widget.bossId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GameWidget(key: ObjectKey(game), game: game),
          ),
          SafeArea(child: _BattleHud(hud: hud)),
          if (hud.status == BattleStatus.completed && hud.outcome != null)
            _BattleResult(
              outcome: hud.outcome!,
              collectedItems: hud.collectedItems,
              lostItems: hud.lostItems,
              intelTransmitted: hud.intelTransmitted,
              onRestart: () =>
                  ref.invalidate(battleSessionProvider(widget.bossId)),
              onExit: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

class _BattleHud extends StatelessWidget {
  const _BattleHud({required this.hud});

  final BattleHudState hud;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final escapeTimeLeft = hud.escapeTimeLeft;
    final drop = hud.availableDrop;
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(hud.bossName, style: textTheme.titleSmall),
                const Spacer(),
                Text(
                  hud.bossPattern == BossAttackPattern.aimedCannon
                      ? 'Aimed cannon'
                      : 'Radial burst',
                  style: textTheme.labelSmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: hud.bossIntegrityRatio,
              minHeight: 4,
              color: const Color(0xFF7CFFB2),
              backgroundColor: Colors.white24,
            ),
            if (_adaptations(hud) case final adaptations?) ...[
              const SizedBox(height: 4),
              Text(
                'Evolved: $adaptations',
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF4DD0E1),
                ),
              ),
            ],
            const Spacer(),
            if (hud.hasCoreShield && hud.shieldBreakTimeLeft > 0) ...[
              _Banner(
                text:
                    'SHIELD DOWN '
                    '${hud.shieldBreakTimeLeft.toStringAsFixed(1)}s',
                color: const Color(0xFF4DD0E1),
              ),
              const SizedBox(height: 6),
            ],
            if (escapeTimeLeft != null)
              _Banner(
                text: 'ESCAPE IN ${escapeTimeLeft.toStringAsFixed(1)}s',
                color: const Color(0xFFFFD54F),
              )
            else if (hud.coreVulnerable)
              const _Banner(text: 'CORE EXPOSED  ×2', color: Color(0xFFFF4D6D)),
            if (drop != null) ...[
              const SizedBox(height: 6),
              _Banner(
                text:
                    'GRAB ${drop.name.toUpperCase()}  '
                    '${drop.timeLeft.toStringAsFixed(1)}s',
                color: const Color(0xFFFFC857),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 8),
            Text('Hull', style: textTheme.labelSmall),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: hud.hullRatio,
              minHeight: 6,
              color: const Color(0xFF7FD4FF),
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 6),
            Text(
              '${hud.weaponName}  •  Drag anywhere to move',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  /// Short description of the countermeasures affecting the player now.
  static String? _adaptations(BattleHudState hud) {
    final parts = [
      if (hud.weaponDamageMultiplier < 1)
        '${hud.weaponName} '
            '−${((1 - hud.weaponDamageMultiplier) * 100).round()}%',
      if (hud.coreWindowShortened)
        'core window ${hud.coreWindowOpenDuration.toStringAsFixed(0)}s',
      ...hud.evolutions,
    ];
    return parts.isEmpty ? null : parts.join('  •  ');
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}

class _BattleResult extends StatelessWidget {
  const _BattleResult({
    required this.outcome,
    required this.collectedItems,
    required this.lostItems,
    required this.intelTransmitted,
    required this.onRestart,
    required this.onExit,
  });

  final BattleOutcome outcome;
  final List<String> collectedItems;
  final List<String> lostItems;
  final bool intelTransmitted;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final title = switch (outcome) {
      BattleOutcome.victory => 'Boss destroyed',
      BattleOutcome.defeat => 'Ship destroyed',
      BattleOutcome.bossEscaped => 'The boss escaped',
    };
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (collectedItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Collected: ${collectedItems.join(', ')}'),
                ],
                if (lostItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Lost: ${lostItems.join(', ')}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  intelTransmitted
                      ? 'The observer sent intel on your weapons to the enemy.'
                      : 'The observer was destroyed. No intel was sent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: intelTransmitted
                        ? const Color(0xFFB39DDB)
                        : Colors.white54,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRestart, child: const Text('Retry')),
                TextButton(onPressed: onExit, child: const Text('Leave')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
