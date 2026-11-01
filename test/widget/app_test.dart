import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/app/app.dart';
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
  observerDestroyed: false,
  intelTransmitted: false,
);

Finder nodeOf(String bossId) => find.byKey(Key('campaign.node.$bossId'));

void main() {
  final sentinel = BossCatalog.sentinel.id;
  final mk2 = BossCatalog.sentinelMk2.id;

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
    expect(find.text('2. Sentinel Mk II'), findsOneWidget);
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

    await tester.tap(nodeOf(mk2));
    expect(selected, isNull);
    await tester.tap(nodeOf(sentinel));
    expect(selected, sentinel);
  });

  testWidgets('the map shows defeated bosses and what they unlocked', (
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
        ],
        child: MaterialApp(
          home: CampaignMapScreen(onBossSelected: (id) => selected = id),
        ),
      ),
    );

    expect(find.text('Defeated'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
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
