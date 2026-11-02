import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/app/app.dart';
import 'package:recursion/features/boss_evolution/application/boss_lineage_controller.dart';
import 'package:recursion/features/boss_evolution/domain/boss_lineage.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_record.dart';
import 'package:recursion/features/combat/domain/entities/combat_log.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/progression/application/progress_controller.dart';
import 'package:recursion/features/progression/domain/player_progress.dart';
import 'package:recursion/features/progression/presentation/campaign_map_screen.dart';

BattleRecord recordFor(String bossId, BattleOutcome outcome) => BattleRecord(
  bossId: bossId,
  outcome: outcome,
  duration: 30,
  stats: CombatStats.empty,
  destroyedComponentIds: const [],
  collectedItemIds: const [],
  observerFled: false,
  intelTransmitted: false,
);

Finder nodeOf(String bossId) => find.byKey(Key('campaign.node.$bossId'));

void main() {
  final sentinel = BossCatalog.sentinel.id;
  const mk2 = 'boss.sentinel.gen2';

  testWidgets('home leads to the campaign, not to individual bosses', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RecursionApp()));

    expect(find.text('RECURSION'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Campaign'), findsOneWidget);
    expect(find.text('Reset progress'), findsOneWidget);
    expect(find.textContaining('Sentinel'), findsNothing);

    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();

    expect(find.text('1. Sentinel'), findsOneWidget);
    expect(find.text('2. ???'), findsOneWidget);
  });

  testWidgets('a new campaign has only the first boss available', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CampaignMapScreen(onBossSelected: (id) => selected = id),
        ),
      ),
    );

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);

    await tester.tap(nodeOf('next'));
    expect(selected, isNull);
    await tester.tap(nodeOf(sentinel));
    expect(selected, sentinel);
  });

  testWidgets('the map shows defeated bosses and the boss they evolved', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialProgressProvider.overrideWithValue(
            const PlayerProgress().recordBattle(
              recordFor(sentinel, BattleOutcome.victory),
            ),
          ),
          initialBossLineageProvider.overrideWithValue(
            const BossLineage().withNext(const BossGeneration()),
          ),
        ],
        child: MaterialApp(
          home: CampaignMapScreen(onBossSelected: (id) => selected = id),
        ),
      ),
    );

    expect(find.text('Defeated'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('2. Sentinel Mk II'), findsOneWidget);
    expect(find.text('3. ???'), findsOneWidget);
    await tester.tap(nodeOf(mk2));
    expect(selected, mk2);
  });

  testWidgets('reset progress asks first, then wipes the campaign', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        initialProgressProvider.overrideWithValue(
          const PlayerProgress().recordBattle(
            recordFor(sentinel, BattleOutcome.defeat),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RecursionApp(),
      ),
    );

    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(progressControllerProvider).battlesFought, 1);

    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(container.read(progressControllerProvider).battlesFought, 0);
  });
}
