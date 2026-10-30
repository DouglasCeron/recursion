import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/battle_state.dart';
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
          if (hud.status == BattleStatus.completed)
            _BattleResult(
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
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Target integrity', style: textTheme.labelSmall),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: hud.targetIntegrityRatio,
              minHeight: 6,
              color: const Color(0xFF7CFFB2),
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 8),
            Text(
              '${hud.weaponName}  •  Shots ${hud.shotsFired}  •  '
              'Hits ${hud.hitsLanded}',
              style: textTheme.bodySmall,
            ),
            const Spacer(),
            if (hud.status == BattleStatus.inProgress)
              Text(
                'Drag anywhere to move. Weapons fire automatically.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }
}

class _BattleResult extends StatelessWidget {
  const _BattleResult({required this.onRestart, required this.onExit});

  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Target destroyed',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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
