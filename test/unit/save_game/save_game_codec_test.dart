import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/domain/boss_intel.dart';
import 'package:recursion/features/boss_evolution/domain/boss_lineage.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_record.dart';
import 'package:recursion/features/combat/domain/entities/boss_definition.dart';
import 'package:recursion/features/combat/domain/entities/boss_mutation.dart';
import 'package:recursion/features/combat/domain/entities/combat_log.dart';
import 'package:recursion/features/combat/domain/events/battle_event.dart';
import 'package:recursion/features/inventory/domain/inventory.dart';
import 'package:recursion/features/progression/domain/player_progress.dart';
import 'package:recursion/features/save_game/domain/save_game.dart';
import 'package:recursion/features/save_game/infrastructure/save_game_codec.dart';
import 'package:recursion/features/ship/domain/weapon_catalog.dart';
import 'package:recursion/features/ship/domain/weapon_definition.dart';

const stats = CombatStats(
  weapons: {
    WeaponType.blaster: WeaponUsage(shots: 40, hits: 30, damage: 300),
    WeaponType.heavyCannon: WeaponUsage(shots: 10, hits: 9, damage: 315),
  },
  coreDamage: 400,
  coreDamageWhileExposed: 260,
  zoneDamage: {BossZone.center: 450, BossZone.left: 150},
  destroyedWeaponIds: ['sentinel.cannon'],
);

SaveGame sampleGame() {
  final inventory = Inventory.starter().add(WeaponCatalog.heavyCannon.id);
  return SaveGame(
    inventory: inventory,
    loadout: Loadout.starter().equipWeapon(
      WeaponCatalog.heavyCannon.id,
      inventory: inventory,
    )!,
    intel: const BossIntel().withReport(
      WeaponExposureProfile.fromStats(stats),
      bossId: BossCatalog.sentinel.id,
    ),
    progress: const PlayerProgress().recordBattle(
      BattleRecord(
        bossId: BossCatalog.sentinel.id,
        outcome: BattleOutcome.victory,
        duration: 42.5,
        stats: stats,
        destroyedComponentIds: const ['sentinel.cannon', 'sentinel.core'],
        collectedItemIds: [WeaponCatalog.heavyCannon.id],
        observerFled: false,
        intelTransmitted: true,
      ),
    ),
    lineage: const BossLineage().withNext(
      const BossGeneration(
        basedOnReport: 1,
        steps: [
          EvolutionStep(
            mutation: ArmorUpgrade(BossZone.center),
            zoneShare: 0.75,
          ),
          EvolutionStep(mutation: ExtraPlate(BossZone.center), zoneShare: 0.75),
          EvolutionStep(mutation: CannonSplit(BossZone.left), zoneShare: 0.25),
        ],
      ),
    ),
  );
}

Map<String, Object?> documentOf(SaveGame game) =>
    jsonDecode(const SaveGameCodec().encode(game)) as Map<String, Object?>;

void main() {
  const codec = SaveGameCodec();

  test('a full game survives a round trip', () {
    final result = codec.decode(codec.encode(sampleGame()));

    expect(result.status, SaveLoadStatus.loaded);
    final game = result.game;
    expect(game.inventory.itemIds, {
      WeaponCatalog.blaster.id,
      WeaponCatalog.heavyCannon.id,
    });
    expect(game.loadout.weaponId, WeaponCatalog.heavyCannon.id);

    final report = game.intel.latest!;
    final original = WeaponExposureProfile.fromStats(stats);
    expect(report.sequence, 1);
    expect(report.profile.weakPointFocus, original.weakPointFocus);
    expect(report.bossId, BossCatalog.sentinel.id);
    expect(report.profile.zoneShares, {
      BossZone.center: 0.75,
      BossZone.left: 0.25,
    });
    expect(report.profile.destroyedWeaponIds, ['sentinel.cannon']);
    for (final type in original.weapons.keys) {
      final restored = report.profile.weapons[type]!;
      expect(restored.level, original.weapons[type]!.level);
      expect(restored.damageShare, original.weapons[type]!.damageShare);
      expect(restored.shots, original.weapons[type]!.shots);
    }

    final progress = game.progress;
    expect(progress.battlesFought, 1);
    expect(progress.foughtBossIds, {BossCatalog.sentinel.id});
    final record = progress.lastBattle!;
    expect(record.outcome, BattleOutcome.victory);
    expect(record.duration, 42.5);
    expect(record.stats.weapons[WeaponType.heavyCannon]!.hits, 9);
    expect(record.stats.coreDamageWhileExposed, 260);
    expect(record.stats.destroyedWeaponIds, ['sentinel.cannon']);
    expect(record.stats.zoneDamage, {BossZone.center: 450, BossZone.left: 150});
    expect(record.destroyedComponentIds, hasLength(2));
    expect(record.intelTransmitted, isTrue);
  });

  test('the document carries the schema version', () {
    expect(
      documentOf(sampleGame())['schemaVersion'],
      SaveGameCodec.currentVersion,
    );
  });

  test('nothing stored means a fresh game', () {
    final result = codec.decode(null);

    expect(result.status, SaveLoadStatus.empty);
    expect(result.game.inventory.itemIds, {WeaponCatalog.blaster.id});
    expect(result.game.intel.isEmpty, isTrue);
  });

  group('bad data starts a fresh game instead of crashing', () {
    final cases = {
      'not JSON': '{oops',
      'not an object': '[1, 2]',
      'no version': '{"inventory": {}}',
      'version zero': jsonEncode({
        ...documentOf(sampleGame()),
        'schemaVersion': 0,
      }),
      'wrong field type': jsonEncode({
        ...documentOf(sampleGame()),
        'progress': {'battlesFought': 'many'},
      }),
      'missing section': jsonEncode(
        documentOf(sampleGame())..remove('loadout'),
      ),
    };
    for (final MapEntry(key: name, value: raw) in cases.entries) {
      test(name, () {
        final result = codec.decode(raw);

        expect(result.status, SaveLoadStatus.corrupted);
        expect(result.game.progress.battlesFought, 0);
      });
    }
  });

  test('a save from a newer version is not loaded', () {
    final raw = jsonEncode({...documentOf(sampleGame()), 'schemaVersion': 99});

    final result = codec.decode(raw);

    expect(result.status, SaveLoadStatus.unsupportedVersion);
    expect(result.game.progress.battlesFought, 0);
  });

  test('unknown content ids are dropped and the loadout falls back', () {
    final document = documentOf(sampleGame());
    document['inventory'] = {
      'itemIds': ['weapon.removed'],
    };
    (document['progress'] as Map)['foughtBossIds'] = ['boss.removed'];
    ((document['intel'] as Map)['reports'] as List)
            .cast<Map>()
            .single['bossId'] =
        'boss.warden';

    final game = codec.decode(jsonEncode(document)).game;
    expect(game.intel.latest!.bossId, isNull);

    expect(game.inventory.itemIds, {WeaponCatalog.blaster.id});
    expect(game.loadout.weaponId, WeaponCatalog.blaster.id);
    expect(game.progress.foughtBossIds, isEmpty);
  });

  test('the boss lineage survives a round trip', () {
    final lineage = codec.decode(codec.encode(sampleGame())).game.lineage;

    expect(lineage.base.id, BossCatalog.sentinel.id);
    expect(lineage.length, 2);
    final generation = lineage.generations.last;
    expect(generation.basedOnReport, 1);
    expect(generation.steps.map((s) => s.mutation), [
      isA<ArmorUpgrade>().having((m) => m.zone, 'zone', BossZone.center),
      isA<ExtraPlate>().having((m) => m.zone, 'zone', BossZone.center),
      isA<CannonSplit>().having((m) => m.zone, 'zone', BossZone.left),
    ]);
    expect(generation.steps.first.zoneShare, 0.75);
  });

  test('unknown mutations and zones are dropped from the lineage', () {
    final document = documentOf(sampleGame());
    final generations = (document['lineage'] as Map)['generations'] as List;
    (generations.last as Map)['steps'] = [
      {'mutation': 'laser', 'zone': 'center', 'zoneShare': 0.9},
      {'mutation': 'armorUpgrade', 'zone': 'top', 'zoneShare': 0.9},
      {'mutation': 'armorUpgrade', 'zone': 'left', 'zoneShare': 0.9},
    ];

    final lineage = codec.decode(jsonEncode(document)).game.lineage;

    expect(lineage.length, 2);
    expect(
      lineage.generations.last.steps.single.mutation,
      isA<ArmorUpgrade>().having((m) => m.zone, 'zone', BossZone.left),
    );
  });

  test('bosses outside the saved lineage are dropped', () {
    final document = documentOf(sampleGame());
    (document['progress'] as Map)['foughtBossIds'] = [
      BossCatalog.sentinel.id,
      'boss.sentinel.gen2',
      'boss.sentinel.gen7',
    ];

    final progress = codec.decode(jsonEncode(document)).game.progress;

    expect(progress.foughtBossIds, {
      BossCatalog.sentinel.id,
      'boss.sentinel.gen2',
    });
  });

  test('defeated bosses survive a round trip', () {
    final game = codec.decode(codec.encode(sampleGame())).game;

    expect(game.progress.defeatedBossIds, {BossCatalog.sentinel.id});
  });

  group('migrations', () {
    /// The v6 document an earlier release would have written for [game]:
    /// reports and battles do not know which boss weapons were destroyed.
    Map<String, Object?> v6DocumentOf(SaveGame game) {
      final document = documentOf(game);
      for (final report in ((document['intel'] as Map)['reports'] as List)) {
        (report as Map).remove('destroyedWeapons');
      }
      final stats =
          ((document['progress'] as Map)['lastBattle'] as Map?)?['stats']
              as Map?;
      stats?.remove('destroyedWeapons');
      return {...document, 'schemaVersion': 6};
    }

    /// The v5 document: v6 where the observer could be destroyed instead of
    /// fleeing.
    Map<String, Object?> v5DocumentOf(SaveGame game) {
      final document = v6DocumentOf(game);
      final lastBattle = (document['progress'] as Map)['lastBattle'] as Map?;
      if (lastBattle != null) {
        lastBattle['observerDestroyed'] = lastBattle.remove('observerFled');
      }
      return {...document, 'schemaVersion': 5};
    }

    /// The v4 document: v5 without a lineage, and a fixed second boss.
    Map<String, Object?> v4DocumentOf(SaveGame game) {
      final document = v5DocumentOf(game)..remove('lineage');
      return {...document, 'schemaVersion': 4};
    }

    test('v6 saves load with no destroyed weapons', () {
      final game = codec.decode(jsonEncode(v6DocumentOf(sampleGame()))).game;

      expect(game.intel.latest!.profile.destroyedWeaponIds, isEmpty);
      expect(game.progress.lastBattle!.stats.destroyedWeaponIds, isEmpty);
    });

    test('v5 records keep whether the observer was destroyed, as fled', () {
      final lost = codec
          .decode(jsonEncode(v5DocumentOf(sampleGame())))
          .game
          .progress
          .lastBattle!;

      expect(lost.observerFled, isFalse);
    });

    /// The v3 document: v4 where reports do not know their boss.
    Map<String, Object?> v3DocumentOf(SaveGame game) {
      final document = v4DocumentOf(game);
      for (final report in ((document['intel'] as Map)['reports'] as List)) {
        (report as Map).remove('bossId');
      }
      return {...document, 'schemaVersion': 3};
    }

    /// The v2 document: v3 without damage per zone.
    Map<String, Object?> v2DocumentOf(SaveGame game) {
      final document = v3DocumentOf(game);
      for (final report in ((document['intel'] as Map)['reports'] as List)) {
        (report as Map).remove('zoneShares');
      }
      final lastBattle = (document['progress'] as Map)['lastBattle'] as Map?;
      (lastBattle?['stats'] as Map?)?.remove('zoneDamage');
      return {...document, 'schemaVersion': 2};
    }

    test('v4 saves get a lineage, keeping their fixed second boss and '
        'evolving a third one from it', () {
      final document = v4DocumentOf(sampleGame());
      final progress = document['progress'] as Map;
      progress['foughtBossIds'] = [
        BossCatalog.sentinel.id,
        'boss.sentinel_mk2',
      ];
      progress['defeatedBossIds'] = ['boss.sentinel_mk2'];
      final reports = (document['intel'] as Map)['reports'] as List;
      (reports.single as Map)['bossId'] = 'boss.sentinel_mk2';

      final game = codec.decode(jsonEncode(document)).game;

      expect(game.lineage.length, 3);
      expect(
        game.lineage.generations[1].steps,
        isEmpty,
        reason: 'no report of the Sentinel itself',
      );
      expect(game.lineage.generations[2].basedOnReport, 1);
      expect(game.progress.foughtBossIds, contains('boss.sentinel.gen2'));
      expect(game.progress.defeatedBossIds, {'boss.sentinel.gen2'});
      expect(game.intel.latest!.bossId, 'boss.sentinel.gen2');
    });

    test('v4 saves evolve their second boss from the last Sentinel report', () {
      final game = codec.decode(jsonEncode(v4DocumentOf(sampleGame()))).game;

      expect(game.lineage.length, 2);
      final generation = game.lineage.generations.last;
      expect(generation.basedOnReport, 1);
      expect(generation.steps.map((s) => s.mutation), [
        isA<ArmorUpgrade>().having((m) => m.zone, 'zone', BossZone.center),
        isA<ExtraPlate>().having((m) => m.zone, 'zone', BossZone.center),
        isA<ArmorUpgrade>().having((m) => m.zone, 'zone', BossZone.left),
        isA<WeaponUpgrade>()
            .having((m) => m.zone, 'zone', BossZone.center)
            .having((m) => m.faster, 'faster', isTrue),
      ]);
    });

    test('v4 saves that never fought get only the base boss', () {
      final document = v4DocumentOf(SaveGame.initial());

      final game = codec.decode(jsonEncode(document)).game;

      expect(game.lineage.length, 1);
    });

    test('v3 reports load without a boss, so nothing evolves from them', () {
      final result = codec.decode(jsonEncode(v3DocumentOf(sampleGame())));

      expect(result.status, SaveLoadStatus.loaded);
      final report = result.game.intel.latest!;
      expect(report.bossId, isNull);
      expect(report.profile.zoneShares, isNotEmpty);
    });

    String v2Of(SaveGame game) => jsonEncode(v2DocumentOf(game));

    /// The v1 document: v2 without defeated bosses.
    String v1Of(SaveGame game) {
      final document = v2DocumentOf(game);
      (document['progress'] as Map).remove('defeatedBossIds');
      return jsonEncode({...document, 'schemaVersion': 1});
    }

    test('v2 saves load with no damage per zone', () {
      final result = codec.decode(v2Of(sampleGame()));

      expect(result.status, SaveLoadStatus.loaded);
      expect(result.game.intel.latest!.profile.zoneShares, isEmpty);
      expect(result.game.intel.latest!.profile.weakPointFocus, 0.65);
      expect(result.game.progress.lastBattle!.stats.zoneDamage, isEmpty);
      expect(result.game.progress.defeatedBossIds, {BossCatalog.sentinel.id});
    });

    test('unknown zones are dropped', () {
      final document = documentOf(sampleGame());
      final report =
          ((document['intel'] as Map)['reports'] as List).single as Map;
      report['zoneShares'] = {'center': 0.6, 'top': 0.4};

      final shares = codec
          .decode(jsonEncode(document))
          .game
          .intel
          .latest!
          .profile
          .zoneShares;

      expect(shares, {BossZone.center: 0.6});
    });

    test('v1 saves load, counting a last-battle victory as defeated', () {
      final result = codec.decode(v1Of(sampleGame()));

      expect(result.status, SaveLoadStatus.loaded);
      expect(result.game.progress.defeatedBossIds, {BossCatalog.sentinel.id});
      expect(result.game.progress.battlesFought, 1);
      expect(result.game.loadout.weaponId, WeaponCatalog.heavyCannon.id);
    });

    test('v1 saves without a victory have no defeated bosses', () {
      final lost = SaveGame(
        inventory: Inventory.starter(),
        loadout: Loadout.starter(),
        intel: const BossIntel(),
        progress: const PlayerProgress().recordBattle(
          BattleRecord(
            bossId: BossCatalog.sentinel.id,
            outcome: BattleOutcome.defeat,
            duration: 10,
            stats: CombatStats.empty,
            destroyedComponentIds: const [],
            collectedItemIds: const [],
            observerFled: true,
            intelTransmitted: false,
          ),
        ),
      );

      final progress = codec.decode(v1Of(lost)).game.progress;

      expect(progress.defeatedBossIds, isEmpty);
      expect(codec.decode(v1Of(lost)).game.lineage.length, 2);
    });

    test('migrations run in sequence up to the current version', () {
      final nextCodec = SaveGameCodec(
        version: SaveGameCodec.currentVersion + 1,
        migrations: {
          ...SaveGameCodec.defaultMigrations,
          SaveGameCodec.currentVersion: (document) => {
            ...document,
            'inventory': {
              'itemIds': [WeaponCatalog.heavyCannon.id],
            },
          },
        },
      );

      final result = nextCodec.decode(v1Of(SaveGame.initial()));

      expect(result.status, SaveLoadStatus.loaded);
      expect(
        result.game.inventory.contains(WeaponCatalog.heavyCannon.id),
        isTrue,
      );
    });

    test('a missing migration marks the save as unreadable', () {
      final current = codec.encode(SaveGame.initial());

      final result = const SaveGameCodec(
        version: SaveGameCodec.currentVersion + 1,
      ).decode(current);

      expect(result.status, SaveLoadStatus.corrupted);
    });
  });
}
