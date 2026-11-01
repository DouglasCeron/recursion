import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combat/domain/content/boss_catalog.dart';
import '../application/boss_intel_controller.dart';
import '../domain/boss_evolution.dart';

/// Shows how the boss evolved from the previous one, and why, before the
/// battle starts.
class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({
    required this.bossId,
    required this.onLaunch,
    super.key,
  });

  final String bossId;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evolution = ref.watch(bossEvolutionProvider(bossId));
    final boss = BossCatalog.byId(bossId) ?? BossCatalog.all.last;
    final previous = switch (evolution.previousBossId) {
      final id? => BossCatalog.byId(id)?.name,
      null => null,
    };
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Briefing: ${boss.name}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                evolution.basedOnReport == null
                    ? 'The enemy has no intel from your last '
                          '${previous ?? 'battle'} fight. '
                          'The ${boss.name} uses its default armor.'
                    : 'The ${boss.name} evolved from the $previous using '
                          'intel report #${evolution.basedOnReport}.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (evolution.basedOnReport != null && evolution.isEmpty)
                const Text(
                  'Your damage was spread out; no zone was reinforced.',
                ),
              for (final countermeasure in evolution.countermeasures)
                Card(
                  child: ListTile(
                    title: Text(_title(countermeasure)),
                    subtitle: Text(_reason(countermeasure)),
                  ),
                ),
              const Spacer(),
              FilledButton(onPressed: onLaunch, child: const Text('Launch')),
            ],
          ),
        ),
      ),
    );
  }

  static String _title(Countermeasure c) => switch (c.kind) {
    CountermeasureKind.zoneReinforcement =>
      'Reinforced ${c.reinforcement.zone.name} zone: structures '
          '+${_percent(c.reinforcement.integrityMultiplier - 1)} '
          'and an extra plate',
  };

  static String _reason(Countermeasure c) => switch (c.kind) {
    CountermeasureKind.zoneReinforcement =>
      'You dealt ${_percent(c.zoneShare)} of your damage to the '
          '${c.reinforcement.zone.name} zone.',
  };

  static String _percent(double fraction) => '${(fraction * 100).round()}%';
}
