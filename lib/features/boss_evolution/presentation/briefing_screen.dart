import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../combat/domain/content/boss_catalog.dart';
import '../../ship/domain/weapon_catalog.dart';
import '../../ship/domain/weapon_definition.dart';
import '../application/boss_intel_controller.dart';
import '../domain/boss_evolution.dart';
import '../domain/weapon_exposure_profile.dart';

/// Shows which countermeasures the adaptive boss will use, and why, before
/// the battle starts.
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
    final evolution = ref.watch(bossEvolutionProvider);
    final boss = BossCatalog.byId(bossId) ?? BossCatalog.warden;
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
                    ? 'The enemy has no intel on you. '
                          'The ${boss.name} fights with its default setup.'
                    : 'The ${boss.name} adapted using intel report '
                          '#${evolution.basedOnReport}.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (evolution.basedOnReport != null && evolution.isEmpty)
                const Text('The report showed nothing worth countering.'),
              for (final countermeasure in evolution.countermeasures)
                Card(
                  child: ListTile(
                    title: Text(_title(countermeasure)),
                    subtitle: Text(_reason(countermeasure)),
                  ),
                ),
              if (!evolution.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'A fully exposed core always takes full damage.',
                  style: textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
              const Spacer(),
              FilledButton(onPressed: onLaunch, child: const Text('Launch')),
            ],
          ),
        ),
      ),
    );
  }

  static String _title(Countermeasure c) => switch (c.kind) {
    CountermeasureKind.impactPlating =>
      'Impact plating: ${_weaponName(c.weaponType)} '
          'damage −${_percent(c.damageReduction)}',
    CountermeasureKind.deflectorScreen =>
      'Deflector screen: ${_weaponName(c.weaponType)} '
          'damage −${_percent(c.damageReduction)}',
    CountermeasureKind.shortenedCoreWindow =>
      'Core exposure shortened to '
          '${c.coreWindowOpenDuration?.toStringAsFixed(0)}s',
    CountermeasureKind.zoneReinforcement =>
      'Reinforced ${c.reinforcement?.zone.name} zone: structures '
          '+${_percent((c.reinforcement?.integrityMultiplier ?? 1) - 1)} '
          'and an extra plate',
  };

  static String _reason(Countermeasure c) => switch (c.kind) {
    CountermeasureKind.impactPlating || CountermeasureKind.deflectorScreen =>
      'The observer saw ${_exposure(c.exposure)} use of your '
          '${_weaponName(c.weaponType)}.',
    CountermeasureKind.shortenedCoreWindow =>
      'The observer saw you hitting the core while it was exposed.',
    CountermeasureKind.zoneReinforcement =>
      'You dealt ${_percent(c.zoneShare)} of your damage to the '
          '${c.reinforcement?.zone.name} zone.',
  };

  static String _weaponName(WeaponType? type) => switch (type) {
    null => 'weapon',
    final type =>
      WeaponCatalog.all.where((w) => w.type == type).firstOrNull?.name ??
          type.name,
  };

  static String _exposure(ExposureLevel? level) => switch (level) {
    ExposureLevel.high => 'heavy',
    ExposureLevel.medium => 'frequent',
    ExposureLevel.low || null => 'some',
  };

  static String _percent(double? fraction) =>
      '${((fraction ?? 0) * 100).round()}%';
}
