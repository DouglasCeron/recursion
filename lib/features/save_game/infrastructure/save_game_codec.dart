import 'dart:convert';

import '../../boss_evolution/domain/boss_intel.dart';
import '../../boss_evolution/domain/weapon_exposure_profile.dart';
import '../../combat/domain/content/boss_catalog.dart';
import '../../combat/domain/entities/battle_record.dart';
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

  static const currentVersion = 1;

  /// Keyed by the version they upgrade from: `migrations[1]` turns a v1
  /// document into a v2 one.
  static const defaultMigrations = <int, SaveMigration>{};

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
      foughtBossIds: Set.unmodifiable({
        for (final id in _strings(json['foughtBossIds']))
          if (BossCatalog.byId(id) != null) id,
      }),
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

  static WeaponType? _weaponType(Object? name) =>
      _enum(WeaponType.values, name);

  static T? _enum<T extends Enum>(List<T> values, Object? name) =>
      name == null ? null : values.asNameMap()[name as String];
}
