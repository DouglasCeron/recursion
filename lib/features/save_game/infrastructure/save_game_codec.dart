import 'dart:convert';

import '../../boss_evolution/domain/boss_intel.dart';
import '../../boss_evolution/domain/boss_lineage.dart';
import '../../boss_evolution/domain/evolution_director.dart';
import '../../boss_evolution/domain/weapon_exposure_profile.dart';
import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/battle_record.dart';
import '../../combat/domain/entities/boss_component_state.dart';
import '../../combat/domain/entities/boss_definition.dart';
import '../../combat/domain/entities/boss_mutation.dart';
import '../../combat/domain/entities/combat_log.dart';
import '../../combat/domain/events/battle_event.dart';
import '../../inventory/domain/inventory.dart';
import '../../progression/domain/player_progress.dart';
import '../../ship/domain/weapon_catalog.dart';
import '../../ship/domain/weapon_definition.dart';
import '../domain/save_game.dart';

typedef JsonMap = Map<String, Object?>;

/// Upgrades a save document from one schema version to the next.
typedef SaveMigration = JsonMap Function(JsonMap document);

/// Converts [SaveGame]s to and from versioned JSON.
///
/// Unknown content ids (items, weapon types, zones, and bosses outside the
/// saved lineage) are dropped on load, so removing content from the game
/// never breaks an existing save.
class SaveGameCodec {
  const SaveGameCodec({
    this.version = currentVersion,
    this.migrations = defaultMigrations,
  });

  static const currentVersion = 7;

  /// Keyed by the version they upgrade from: `migrations[1]` turns a v1
  /// document into a v2 one.
  static const defaultMigrations = <int, SaveMigration>{
    1: _addDefeatedBosses,
    2: _addZoneDamage,
    3: _addReportBoss,
    4: _addLineage,
    5: _renameObserverDestroyed,
    6: _addDestroyedWeapons,
  };

  /// v7 records the boss weapons the observer saw destroyed. Older reports
  /// and battles saw none, so no cannon evolves from them.
  static JsonMap _addDestroyedWeapons(JsonMap document) {
    final intel = document['intel'] as JsonMap;
    final progress = document['progress'] as JsonMap;
    final lastBattle = progress['lastBattle'] as JsonMap?;
    JsonMap? withWeapons(JsonMap? record) {
      if (record == null) return null;
      return {
        ...record,
        'stats': {
          ...record['stats'] as JsonMap,
          'destroyedWeapons': <Object?>[],
        },
      };
    }

    return {
      ...document,
      'intel': {
        ...intel,
        'reports': [
          for (final report in (intel['reports'] as List).cast<JsonMap>())
            {...report, 'destroyedWeapons': <Object?>[]},
        ],
      },
      'progress': {...progress, 'lastBattle': withWeapons(lastBattle)},
    };
  }

  /// v6: the observer flees instead of being destroyed, and still transmits
  /// what it saw. Older records keep their value under the new name.
  static JsonMap _renameObserverDestroyed(JsonMap document) {
    final progress = document['progress'] as JsonMap;
    final lastBattle = progress['lastBattle'] as JsonMap?;
    if (lastBattle == null) return document;
    final record = {...lastBattle};
    record['observerFled'] = record.remove('observerDestroyed');
    return {
      ...document,
      'progress': {...progress, 'lastBattle': record},
    };
  }

  static const _mk2Id = 'boss.sentinel_mk2';
  static const _secondGenerationId = 'boss.sentinel.gen2';

  /// v5 stores the chain of evolved bosses. A v4 save had two fixed bosses,
  /// the Sentinel and the Sentinel Mk II. Each one that was fought gets the
  /// next generation, evolved from its latest report as a v5 save would have
  /// done, and the Mk II becomes the second generation.
  static JsonMap _addLineage(JsonMap document) {
    final progress = document['progress'] as JsonMap;
    final intel = document['intel'] as JsonMap;
    final reports = (intel['reports'] as List).cast<JsonMap>();
    final lastBattle = progress['lastBattle'] as JsonMap?;
    Object? rename(Object? id) => id == _mk2Id ? _secondGenerationId : id;
    List<Object?> renameAll(Object? ids) => [
      for (final id in ids as List) rename(id),
    ];
    final fought = progress['foughtBossIds'] as List;
    var lineage = const BossLineage();
    for (final bossId in [BossCatalog.sentinel.id, _mk2Id]) {
      if (!fought.contains(bossId)) break;
      final observed = [
        for (final report in reports)
          if (report['bossId'] == bossId) report,
      ];
      lineage = lineage.withNext(
        EvolutionDirector.next(
          lineage.definitionOf(lineage.latestId)!,
          observed.isEmpty ? null : _decodeReport(observed.last, lineage),
        ),
      );
    }
    return {
      ...document,
      'lineage': _encodeLineage(lineage),
      'intel': {
        ...intel,
        'reports': [
          for (final report in (intel['reports'] as List).cast<JsonMap>())
            {...report, 'bossId': rename(report['bossId'])},
        ],
      },
      'progress': {
        ...progress,
        'foughtBossIds': renameAll(progress['foughtBossIds']),
        'defeatedBossIds': renameAll(progress['defeatedBossIds']),
        'lastBattle': lastBattle == null
            ? null
            : {...lastBattle, 'bossId': rename(lastBattle['bossId'])},
      },
    };
  }

  /// v4 records which boss each report came from. Older reports cannot be
  /// attributed, so no boss evolves from them.
  static JsonMap _addReportBoss(JsonMap document) {
    final intel = document['intel'] as JsonMap;
    return {
      ...document,
      'intel': {
        ...intel,
        'reports': [
          for (final report in (intel['reports'] as List).cast<JsonMap>())
            {...report, 'bossId': null},
        ],
      },
    };
  }

  /// v3 tracks damage per boss zone. Older reports and battles did not
  /// record it, so they start with none (and never drive an evolution).
  static JsonMap _addZoneDamage(JsonMap document) {
    final intel = document['intel'] as JsonMap;
    final progress = document['progress'] as JsonMap;
    final lastBattle = progress['lastBattle'] as JsonMap?;
    return {
      ...document,
      'intel': {
        ...intel,
        'reports': [
          for (final report in (intel['reports'] as List).cast<JsonMap>())
            {...report, 'zoneShares': <String, Object?>{}},
        ],
      },
      'progress': {
        ...progress,
        'lastBattle': lastBattle == null
            ? null
            : {
                ...lastBattle,
                'stats': {
                  ...lastBattle['stats'] as JsonMap,
                  'zoneDamage': <String, Object?>{},
                },
              },
      },
    };
  }

  /// v2 tracks defeated bosses. A v1 save only knows its last battle, so
  /// that boss counts as defeated if that battle was a victory.
  static JsonMap _addDefeatedBosses(JsonMap document) {
    final progress = document['progress'] as JsonMap;
    final lastBattle = progress['lastBattle'] as JsonMap?;
    return {
      ...document,
      'progress': {
        ...progress,
        'defeatedBossIds': [
          if (lastBattle != null &&
              lastBattle['outcome'] == BattleOutcome.victory.name)
            lastBattle['bossId'],
        ],
      },
    };
  }

  final int version;
  final Map<int, SaveMigration> migrations;

  String encode(SaveGame game) => jsonEncode({
    'schemaVersion': version,
    'inventory': {'itemIds': game.inventory.itemIds.toList()..sort()},
    'loadout': {'weaponId': game.loadout.weaponId},
    'intel': {'reports': game.intel.reports.map(_encodeReport).toList()},
    'progress': _encodeProgress(game.progress),
    'lineage': _encodeLineage(game.lineage),
  });

  SaveLoadResult decode(String? raw) {
    if (raw == null) return SaveLoadResult(SaveLoadStatus.empty, _fresh());
    try {
      var document = jsonDecode(raw) as JsonMap;
      final stored = document['schemaVersion'] as int;
      if (stored > version) {
        return SaveLoadResult(SaveLoadStatus.unsupportedVersion, _fresh());
      }
      if (stored < 1) throw const FormatException('invalid schema version');
      for (var from = stored; from < version; from++) {
        final migrate = migrations[from];
        if (migrate == null) {
          throw FormatException('no migration from version $from');
        }
        document = migrate(document);
      }
      return SaveLoadResult(SaveLoadStatus.loaded, _decodeGame(document));
    } on FormatException {
      return SaveLoadResult(SaveLoadStatus.corrupted, _fresh());
    } on TypeError {
      return SaveLoadResult(SaveLoadStatus.corrupted, _fresh());
    }
  }

  static SaveGame _fresh() => SaveGame.initial();

  // Encoding.

  static JsonMap _encodeLineage(BossLineage lineage) => {
    'baseId': lineage.base.id,
    'generations': lineage.generations.map(_encodeGeneration).toList(),
  };

  static JsonMap _encodeGeneration(BossGeneration generation) => {
    'basedOnReport': generation.basedOnReport,
    'steps': [
      for (final step in generation.steps)
        {
          'mutation': switch (step.mutation) {
            ArmorUpgrade() => 'armorUpgrade',
            ExtraPlate() => 'extraPlate',
            CannonSplit() => 'cannonSplit',
            WeaponUpgrade() => 'weaponUpgrade',
            WeaponReinforcement() => 'weaponReinforcement',
            AddedWeapon() => 'addedWeapon',
          },
          'zone': step.mutation.zone.name,
          'zoneShare': step.zoneShare,
          if (step.mutation case WeaponUpgrade(:final faster)) 'faster': faster,
          if (step.mutation case AddedWeapon(:final weapon))
            'weapon': weapon.name,
        },
    ],
  };

  static JsonMap _encodeReport(IntelReport report) => {
    'sequence': report.sequence,
    'bossId': report.bossId,
    'weakPointFocus': report.profile.weakPointFocus,
    'zoneShares': {
      for (final MapEntry(key: zone, value: share)
          in report.profile.zoneShares.entries)
        zone.name: share,
    },
    'weapons': [
      for (final w in report.profile.weapons.values)
        {
          'type': w.type.name,
          'shots': w.shots,
          'damage': w.damage,
          'damageShare': w.damageShare,
          'level': w.level.name,
        },
    ],
    'destroyedWeapons': report.profile.destroyedWeaponIds,
  };

  static JsonMap _encodeProgress(PlayerProgress progress) => {
    'battlesFought': progress.battlesFought,
    'foughtBossIds': progress.foughtBossIds.toList()..sort(),
    'defeatedBossIds': progress.defeatedBossIds.toList()..sort(),
    'lastBattle': switch (progress.lastBattle) {
      null => null,
      final record => _encodeRecord(record),
    },
  };

  static JsonMap _encodeRecord(BattleRecord record) => {
    'bossId': record.bossId,
    'outcome': record.outcome?.name,
    'duration': record.duration,
    'stats': {
      'weapons': [
        for (final MapEntry(key: type, value: usage)
            in record.stats.weapons.entries)
          {
            'type': type.name,
            'shots': usage.shots,
            'hits': usage.hits,
            'damage': usage.damage,
          },
      ],
      'coreDamage': record.stats.coreDamage,
      'coreDamageWhileExposed': record.stats.coreDamageWhileExposed,
      'zoneDamage': {
        for (final MapEntry(key: zone, value: damage)
            in record.stats.zoneDamage.entries)
          zone.name: damage,
      },
      'destroyedWeapons': record.stats.destroyedWeaponIds,
    },
    'destroyedComponentIds': record.destroyedComponentIds,
    'collectedItemIds': record.collectedItemIds,
    'observerFled': record.observerFled,
    'intelTransmitted': record.intelTransmitted,
  };

  // Decoding. Missing or mistyped fields throw and mark the save corrupted;
  // unknown content ids are skipped.

  static SaveGame _decodeGame(JsonMap document) {
    final inventory = Inventory({
      WeaponCatalog.blaster.id,
      for (final id in _strings((document['inventory'] as JsonMap)['itemIds']))
        if (WeaponCatalog.byId(id) != null) id,
    });
    final weaponId = (document['loadout'] as JsonMap)['weaponId'] as String;
    final loadout =
        Loadout.starter().equipWeapon(weaponId, inventory: inventory) ??
        Loadout.starter();
    final reports = (document['intel'] as JsonMap)['reports'] as List;
    final lineage = _decodeLineage(document['lineage'] as JsonMap);
    return SaveGame(
      inventory: inventory,
      loadout: loadout,
      intel: BossIntel(
        List.unmodifiable([
          for (final report in reports)
            _decodeReport(report as JsonMap, lineage),
        ]),
      ),
      progress: _decodeProgress(document['progress'] as JsonMap, lineage),
      lineage: lineage,
    );
  }

  static BossLineage _decodeLineage(JsonMap json) {
    final base = BossCatalog.byId(json['baseId'] as String);
    if (base == null) throw const FormatException('unknown base boss');
    final generations = [
      for (final generation in (json['generations'] as List).cast<JsonMap>())
        BossGeneration(
          basedOnReport: generation['basedOnReport'] as int?,
          steps: List.unmodifiable([
            for (final step in (generation['steps'] as List).cast<JsonMap>())
              ?_decodeStep(step),
          ]),
        ),
    ];
    if (generations.isEmpty) throw const FormatException('empty lineage');
    return BossLineage(base: base, generations: List.unmodifiable(generations));
  }

  static EvolutionStep? _decodeStep(JsonMap json) {
    final zone = _zone(json['zone']);
    if (zone == null) return null;
    final BossMutation? mutation = switch (json['mutation']) {
      'armorUpgrade' => ArmorUpgrade(zone),
      'extraPlate' => ExtraPlate(zone),
      'cannonSplit' => CannonSplit(zone),
      'weaponUpgrade' => WeaponUpgrade(zone, faster: json['faster'] == true),
      'weaponReinforcement' => WeaponReinforcement(zone),
      'addedWeapon' => switch (BossWeapon.values.asNameMap()[json['weapon']]) {
        final weapon? => AddedWeapon(zone, weapon),
        null => null,
      },
      _ => null,
    };
    if (mutation == null) return null;
    return EvolutionStep(
      mutation: mutation,
      zoneShare: (json['zoneShare'] as num).toDouble(),
    );
  }

  static IntelReport _decodeReport(JsonMap json, BossLineage lineage) =>
      IntelReport(
        sequence: json['sequence'] as int,
        bossId: switch (json['bossId'] as String?) {
          final id? when lineage.contains(id) => id,
          _ => null,
        },
        profile: WeaponExposureProfile(
          weakPointFocus: (json['weakPointFocus'] as num?)?.toDouble(),
          zoneShares: Map.unmodifiable({
            for (final MapEntry(:key, :value)
                in (json['zoneShares'] as JsonMap).entries)
              ?_zone(key): (value as num).toDouble(),
          }),
          destroyedWeaponIds: List.unmodifiable(
            _optionalStrings(json['destroyedWeapons']),
          ),
          weapons: {
            for (final exposure
                in (json['weapons'] as List)
                    .cast<JsonMap>()
                    .map(_decodeExposure)
                    .nonNulls)
              exposure.type: exposure,
          },
        ),
      );

  static WeaponExposure? _decodeExposure(JsonMap json) {
    final type = _weaponType(json['type']);
    if (type == null) return null;
    return WeaponExposure(
      type: type,
      shots: json['shots'] as int,
      damage: json['damage'] as int,
      damageShare: (json['damageShare'] as num).toDouble(),
      level: _enum(ExposureLevel.values, json['level'])!,
    );
  }

  static PlayerProgress _decodeProgress(JsonMap json, BossLineage lineage) {
    final lastBattle = json['lastBattle'] as JsonMap?;
    return PlayerProgress(
      battlesFought: json['battlesFought'] as int,
      foughtBossIds: _knownBossIds(json['foughtBossIds'], lineage),
      defeatedBossIds: _knownBossIds(json['defeatedBossIds'], lineage),
      lastBattle: lastBattle == null
          ? null
          : _decodeRecord(lastBattle, lineage),
    );
  }

  static BattleRecord? _decodeRecord(JsonMap json, BossLineage lineage) {
    final bossId = json['bossId'] as String;
    if (!lineage.contains(bossId)) return null;
    final stats = json['stats'] as JsonMap;
    return BattleRecord(
      bossId: bossId,
      outcome: _enum(BattleOutcome.values, json['outcome']),
      duration: (json['duration'] as num).toDouble(),
      stats: CombatStats(
        weapons: Map.unmodifiable({
          for (final w in (stats['weapons'] as List).cast<JsonMap>())
            ?_weaponType(w['type']): WeaponUsage(
              shots: w['shots'] as int,
              hits: w['hits'] as int,
              damage: w['damage'] as int,
            ),
        }),
        coreDamage: stats['coreDamage'] as int,
        coreDamageWhileExposed: stats['coreDamageWhileExposed'] as int,
        zoneDamage: Map.unmodifiable({
          for (final MapEntry(:key, :value)
              in (stats['zoneDamage'] as JsonMap).entries)
            ?_zone(key): value as int,
        }),
        destroyedWeaponIds: List.unmodifiable(
          _optionalStrings(stats['destroyedWeapons']),
        ),
      ),
      destroyedComponentIds: List.unmodifiable(
        _strings(json['destroyedComponentIds']),
      ),
      collectedItemIds: List.unmodifiable(_strings(json['collectedItemIds'])),
      observerFled: json['observerFled'] as bool,
      intelTransmitted: json['intelTransmitted'] as bool,
    );
  }

  static List<String> _strings(Object? json) => (json as List).cast<String>();

  /// Like [_strings], but a missing field is an empty list. Saves written
  /// before destroyed weapons were tracked omit it, and a migration reads
  /// them before the field is added.
  static List<String> _optionalStrings(Object? json) =>
      json == null ? const [] : _strings(json);

  static Set<String> _knownBossIds(Object? json, BossLineage lineage) =>
      Set.unmodifiable({
        for (final id in _strings(json))
          if (lineage.contains(id)) id,
      });

  static WeaponType? _weaponType(Object? name) =>
      _enum(WeaponType.values, name);

  static BossZone? _zone(Object? name) => _enum(BossZone.values, name);

  static T? _enum<T extends Enum>(List<T> values, Object? name) =>
      name == null ? null : values.asNameMap()[name as String];
}
