import 'dart:convert';

import '../../boss_evolution/domain/boss_intel.dart';
import '../../boss_evolution/domain/weapon_exposure_profile.dart';
import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/battle_record.dart';
import '../../combat/domain/entities/boss_definition.dart';
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
/// Unknown content ids (items, bosses, weapon types) are dropped on load, so
/// removing content from the game never breaks an existing save.
class SaveGameCodec {
  const SaveGameCodec({
    this.version = currentVersion,
    this.migrations = defaultMigrations,
  });

  static const currentVersion = 3;

  /// Keyed by the version they upgrade from: `migrations[1]` turns a v1
  /// document into a v2 one.
  static const defaultMigrations = <int, SaveMigration>{
    1: _addDefeatedBosses,
    2: _addZoneDamage,
  };

  /// v3 tracks damage per boss zone. Older reports and battles did not
  /// record it, so they start with none (and never trigger a reinforcement).
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

  static JsonMap _encodeReport(IntelReport report) => {
    'sequence': report.sequence,
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
    },
    'destroyedComponentIds': record.destroyedComponentIds,
    'collectedItemIds': record.collectedItemIds,
    'observerDestroyed': record.observerDestroyed,
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
    return SaveGame(
      inventory: inventory,
      loadout: loadout,
      intel: BossIntel(
        List.unmodifiable([
          for (final report in reports) _decodeReport(report as JsonMap),
        ]),
      ),
      progress: _decodeProgress(document['progress'] as JsonMap),
    );
  }

  static IntelReport _decodeReport(JsonMap json) => IntelReport(
    sequence: json['sequence'] as int,
    profile: WeaponExposureProfile(
      weakPointFocus: (json['weakPointFocus'] as num?)?.toDouble(),
      zoneShares: Map.unmodifiable({
        for (final MapEntry(:key, :value)
            in (json['zoneShares'] as JsonMap).entries)
          ?_zone(key): (value as num).toDouble(),
      }),
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

  static PlayerProgress _decodeProgress(JsonMap json) {
    final lastBattle = json['lastBattle'] as JsonMap?;
    return PlayerProgress(
      battlesFought: json['battlesFought'] as int,
      foughtBossIds: _knownBossIds(json['foughtBossIds']),
      defeatedBossIds: _knownBossIds(json['defeatedBossIds']),
      lastBattle: lastBattle == null ? null : _decodeRecord(lastBattle),
    );
  }

  static BattleRecord? _decodeRecord(JsonMap json) {
    final bossId = json['bossId'] as String;
    if (BossCatalog.byId(bossId) == null) return null;
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
      ),
      destroyedComponentIds: List.unmodifiable(
        _strings(json['destroyedComponentIds']),
      ),
      collectedItemIds: List.unmodifiable(_strings(json['collectedItemIds'])),
      observerDestroyed: json['observerDestroyed'] as bool,
      intelTransmitted: json['intelTransmitted'] as bool,
    );
  }

  static List<String> _strings(Object? json) => (json as List).cast<String>();

  static Set<String> _knownBossIds(Object? json) => Set.unmodifiable({
    for (final id in _strings(json))
      if (BossCatalog.byId(id) != null) id,
  });

  static WeaponType? _weaponType(Object? name) =>
      _enum(WeaponType.values, name);

  static BossZone? _zone(Object? name) => _enum(BossZone.values, name);

  static T? _enum<T extends Enum>(List<T> values, Object? name) =>
      name == null ? null : values.asNameMap()[name as String];
}
