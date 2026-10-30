import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/battle_state.dart';
import '../domain/entities/boss_state.dart';
import '../domain/events/battle_event.dart';
import 'battle_providers.dart';
import 'flame/space_game.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  SpaceGame? _game;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(battleSessionProvider);
    final game = _game?.session == session
        ? _game!
        : _game = SpaceGame(session: session);
    final hud = ref.watch(battleHudProvider);

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
              onRestart: () => ref.invalidate(battleSessionProvider),
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
            const SizedBox(height: 6),
            for (final part in hud.bossParts) _PartBar(part: part),
            const SizedBox(height: 8),
            if (escapeTimeLeft != null)
              _Banner(
                text: 'ESCAPE IN ${escapeTimeLeft.toStringAsFixed(1)}s',
                color: const Color(0xFFFFD54F),
              )
            else if (hud.coreVulnerable)
              const _Banner(text: 'CORE EXPOSED  ×2', color: Color(0xFFFF4D6D)),
            const Spacer(),
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
}

class _PartBar extends StatelessWidget {
  const _PartBar({required this.part});

  final BossPartHud part;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(part.name, style: style)),
          Expanded(
            child: part.isDestroyed
                ? Text(
                    'DESTROYED',
                    style: style?.copyWith(color: Colors.white38),
                  )
                : LinearProgressIndicator(
                    value: part.ratio,
                    minHeight: 4,
                    color: const Color(0xFF7CFFB2),
                    backgroundColor: Colors.white24,
                  ),
          ),
        ],
      ),
    );
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
    required this.onRestart,
    required this.onExit,
  });

  final BattleOutcome outcome;
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
                const SizedBox(height: 16),
                FilledButton(onPressed: onRestart, child: const Text('Retry')),
                TextButton(onPressed: onExit, child: const Text('Main menu')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
