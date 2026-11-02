import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combat/domain/entities/boss_mutation.dart';
import '../application/boss_lineage_controller.dart';
import '../domain/boss_lineage.dart';

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
    final lineage = ref.watch(bossLineageControllerProvider);
    final id = lineage.contains(bossId) ? bossId : lineage.latestId;
    final number = lineage.numberOf(id)!;
    final boss = lineage.definitionOf(id)!;
    final generation = lineage.generationOf(id)!;
    final previous = number > 1 ? lineage.nameOf(number - 1) : null;
    final carried = evolutionSummary(boss);
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
                previous == null
                    ? 'The ${boss.name} is the first of its line.'
                    : generation.basedOnReport == null
                    ? 'The enemy had no intel from your $previous battle. '
                          'The ${boss.name} is a copy of it.'
                    : 'The ${boss.name} evolved from the $previous using '
                          'intel report #${generation.basedOnReport}.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (generation.basedOnReport != null && generation.steps.isEmpty)
                const Text(
                  'Your damage was spread out, or the focused zones are '
                  'already maxed out: nothing new.',
                ),
              for (final step in generation.steps)
                Card(
                  child: ListTile(
                    title: Text(_title(step.mutation)),
                    subtitle: Text(
                      'You dealt ${_percent(step.zoneShare)} of your damage '
                      'to the ${step.mutation.zone.name} zone.',
                    ),
                  ),
                ),
              if (carried.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Carries: ${carried.join(', ')}.'),
              ],
              const Spacer(),
              FilledButton(onPressed: onLaunch, child: const Text('Launch')),
            ],
          ),
        ),
      ),
    );
  }

  static String _title(BossMutation mutation) => switch (mutation) {
    ArmorUpgrade(:final zone) =>
      'Armor upgraded in the ${zone.name} zone '
          '(+${_percent(ArmorUpgrade.integrityPerLevel)} of base integrity)',
    ExtraPlate(:final zone) => 'Extra plate in front of the ${zone.name} zone',
  };

  static String _percent(double fraction) => '${(fraction * 100).round()}%';
}
