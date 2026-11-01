import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/features/boss_evolution/domain/boss_intel.dart';
import 'package:recursion/features/boss_evolution/domain/weapon_exposure_profile.dart';
import 'package:recursion/features/combat/domain/content/boss_catalog.dart';
import 'package:recursion/features/combat/domain/entities/battle_record.dart';
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
);

SaveGame sampleGame() {
  final inventory = Inventory.starter().add(WeaponCatalog.heavyCannon.id);
  return SaveGame(
    inventory: inventory,
    loadout: Loadout.starter().equipWeapon(
      WeaponCatalog.heavyCannon.id,
      inventory: inventory,
    )!,
    intel: const BossIntel().withReport(WeaponExposureProfile.fromStats(stats)),
    progress: const PlayerProgress().recordBattle(
      BattleRecord(
        bossId: BossCatalog.sentinel.id,
        outcome: BattleOutcome.victory,
        duration: 42.5,
        stats: stats,
        destroyedComponentIds: const ['sentinel.cannon', 'sentinel.core'],
        collectedItemIds: [WeaponCatalog.heavyCannon.id],
        observerDestroyed: false,
        intelTransmitted: true,
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
    for (final type in original.weapons.keys) {
      final restored = report.profile.weapons[type]!;
      expect(restored.level, original.weapons[type]!.level);
      expect(restored.damageShare, original.weapons[type]!.damageShare);
      expect(restored.shots, original.weapons[type]!.shots);
    }

    final progress = game.progress;
    expect(progress.battlesFought, 1);
    expect(progress.isBossUnlocked(BossCatalog.warden.id), isTrue);
    final record = progress.lastBattle!;
    expect(record.outcome, BattleOutcome.victory);
    expect(record.duration, 42.5);
    expect(record.stats.weapons[WeaponType.heavyCannon]!.hits, 9);
    expect(record.stats.coreDamageWhileExposed, 260);
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

    final game = codec.decode(jsonEncode(document)).game;

    expect(game.inventory.itemIds, {WeaponCatalog.blaster.id});
    expect(game.loadout.weaponId, WeaponCatalog.blaster.id);
    expect(game.progress.foughtBossIds, isEmpty);
  });

  test('defeated bosses survive a round trip', () {
    final game = codec.decode(codec.encode(sampleGame())).game;

    expect(game.progress.defeatedBossIds, {BossCatalog.sentinel.id});
  });

  group('migrations', () {
    /// The v1 document the previous release would have written for [game].
    String v1Of(SaveGame game) {
      final document = documentOf(game);
      (document['progress'] as Map).remove('defeatedBossIds');
      return jsonEncode({...document, 'schemaVersion': 1});
    }

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
            observerDestroyed: true,
            intelTransmitted: false,
          ),
        ),
      );

      final progress = codec.decode(v1Of(lost)).game.progress;

      expect(progress.defeatedBossIds, isEmpty);
      expect(progress.isBossUnlocked(BossCatalog.warden.id), isTrue);
    });

    test('migrations run in sequence up to the current version', () {
      final v3Codec = SaveGameCodec(
        version: 3,
        migrations: {
          ...SaveGameCodec.defaultMigrations,
          2: (document) => {
            ...document,
            'inventory': {
              'itemIds': [WeaponCatalog.heavyCannon.id],
            },
          },
        },
      );

      final result = v3Codec.decode(v1Of(SaveGame.initial()));

      expect(result.status, SaveLoadStatus.loaded);
      expect(
        result.game.inventory.contains(WeaponCatalog.heavyCannon.id),
        isTrue,
      );
    });

    test('a missing migration marks the save as unreadable', () {
      final current = codec.encode(SaveGame.initial());

      final result = const SaveGameCodec(version: 3).decode(current);

      expect(result.status, SaveLoadStatus.corrupted);
    });
  });
}
