# Recursion

Prototype of a static-arena space shooter for Android and iOS, built with
Flutter + Flame. Bosses are made of destructible parts, and an enemy observer
drone gathers intel so later bosses adapt to the strategies the player
actually used.

## Status

The proof of concept is built in stages:

| Stage | Scope | Status |
|---|---|---|
| 1 | Arena, ship movement, auto-fire, simple target, collisions | Done |
| 2 | Modular boss (cannon, armor, core), vulnerability window, flagged escape | Done |
| 3 | Component drops, in-battle collection, inventory and loadout | Done |
| 4 | Observer drone, weapon exposure profile, intel transmission | Done |
| 5 | Second, adaptive boss driven by transmitted intel | Done |
| 6 | Local persistence (versioned JSON), validation and docs | Done |

After the proof of concept:

| Step | Scope | Status |
|---|---|---|
| 7 | Campaign map, reset progress, save schema v2 (defeated bosses) | Done |
| 8 | Layered boss structures that cover inner parts | Done |
| 9 | Player focus by zone; the next boss reinforces the focused zone | Done |
| 10 | Battle HUD that scales with many boss parts | Done |
| 11 | Boss 2 becomes the Sentinel Mk II, evolved from the Sentinel's damage history | Done |
| 12 | Endless boss lineage: each boss evolves from the previous one (armor levels, extra plates) | Done |
| 13 | Damage shown as part colors instead of integrity bars | Planned |
| 14 | Weapon mutations: extra cannons where the boss lost one | Planned |
| 15 | Enemy laser and missile as evolutions after two cannons | Planned |
| 16 | Richer observer (ship position, destruction order) | Planned |

## Requirements

- Flutter 3.44 (Dart 3.12) or newer on the stable channel.
- An Android emulator/device or an iOS simulator/device.

## Running

```sh
flutter pub get
flutter run                    # opens the main menu
flutter run --route /campaign  # opens the campaign map
flutter run --route /battle    # jumps straight into the Sentinel battle
flutter run --route "/battle?boss=boss.sentinel.gen2"    # the second boss
flutter run --route "/briefing?boss=boss.sentinel.gen2"  # its briefing
```

Controls: drag anywhere on the screen to move the ship; weapons fire
automatically.

Suggested first session: open Campaign and fight the Sentinel (destroy its
cannon and touch the falling Heavy Cannon to collect it), equip it in
Inventory, then pick the Sentinel Mk II on the map and read its briefing: its
armor evolved where you hit the Sentinel the most. Destroy the observer
drone on the left edge if you do not want the enemy to learn from that
battle.

## Campaign

- The main menu has Campaign, Inventory and Reset progress (asks for
  confirmation, then erases items, progress and enemy intel).
- The campaign is endless. The map shows every boss of the lineage as a
  numbered point on one path, joined by lines, then one locked `???` point:
  the next boss does not exist until the latest one has been fought.
- Each point is available, fought (not defeated yet) or defeated (check
  mark). Every boss can be replayed.
- Evolved bosses open their briefing first; the Sentinel goes straight to
  battle.

## Checks and builds

```sh
dart format lib test
flutter analyze
flutter test
flutter build ios --simulator --debug   # iOS simulator build
flutter build apk --debug               # Android debug APK
```

## Architecture

Feature-oriented folders under `lib/features/<feature>/` with these layers:

- `domain/` — pure Dart rules and state (no Flutter, Flame or persistence
  imports). `BattleState` is the authoritative battle state.
- `application/` — use-case coordination, e.g. `BattleSession`, which forwards
  input and collisions to the domain and publishes `BattleEvent`s.
- `presentation/` — Flutter screens/HUD (Riverpod) and Flame components under
  `presentation/flame/`. Flame components only render, move visually and
  report collisions; they never decide damage.
- `infrastructure/` — persistence adapters (`save_game` feature).

Shared code lives in `lib/core/`, app wiring (bootstrap, routing, theme) in
`lib/app/`.

Combat rules worth knowing:

- Every projectile gets an id from the domain. A projectile is resolved at
  most once, so duplicate collision callbacks cannot deal damage twice.
- A boss part reports its destruction exactly once; later hits on it are
  ignored and the projectile keeps flying.
- The arena uses a fixed logical resolution of 360×640 units, scaled to the
  device screen.

## First boss: Sentinel

Defined in `lib/features/combat/domain/content/boss_catalog.dart`.

| Part | Integrity | Rule |
|---|---|---|
| Core | 400 | Covered by the armor. Destroying it defeats the boss. Takes ×2 damage while exposed. |
| Armor | 100 | Wide plate under the core. |
| Left / right wing | 70 each | Hull flanking the armor; they cover nothing and only soak shots. |
| Cannon | 100 | Fires aimed shots. Destroying it changes the boss's behavior. |

- **Attacks:** first attack after 1.5 s. With the cannon: one aimed shot every
  1.2 s (15 damage). Without the cannon: a 5-shot downward fan (80° spread)
  every 2 s (8 damage each), and the boss drifts faster (0.6 → 1.1 rad/s).
- **Core vulnerability window:** 8 s cycles, closed for 5 s then exposed for
  3 s (first exposure at 5 s). Only core hits during the window get the ×2
  bonus; outside it the core takes normal damage.
- **Escape:** when the core drops to 30% of its integrity (120 of 400) or
  below, the boss announces the escape (HUD countdown and
  flashing parts) and leaves 5 s later unless the core is destroyed first.
  The escape is announced at most once.
- **Ship:** 100 hull. After taking damage it is invulnerable for 0.75 s.
  Hull at zero loses the battle.

Battle outcomes: `victory` (core destroyed), `defeat` (ship destroyed) and
`bossEscaped`.

## Layered structures

- A part can be covered by outer parts (`coveredBy`). While any cover
  stands, a hit on the inner part is taken by the outermost cover still
  standing, so the damage and the hit event go to that cover. Once the
  covers are gone, the inner part takes hits normally.
- This rule lives in the domain, so it does not depend on which hitbox Flame
  reports first.
- Covered parts are drawn darker and their integrity bar is grey. Outer layers
  are drawn on top of what they cover.
- Hull (`BossComponentKind.hull`) is plain outer plating: it protects, never
  attacks and never drops anything.
- Every part belongs to a zone by its horizontal offset from the boss
  center: left, center (within 20 units) or right.

### Battle HUD

- The top of the screen shows only the boss name, its pattern, one bar with
  the total integrity of every part, and the evolutions it carries.
- Each part has its own thin integrity bar drawn in the arena, just above it;
  it disappears when the part is destroyed. This scales with any number of
  parts.
- Banners (shield down, escape countdown, core exposed, drop to grab) sit at
  the bottom, above the ship hull bar, so they never cover the boss.

## Drops, inventory and loadout

- Destroying the Sentinel's cannon drops the **Heavy Cannon** (35 damage,
  0.6 s between shots) where the cannon was. The armor and core drop nothing.
- A drop drifts down the arena and must be **touched by the ship** to be
  collected. Destroying the part never grants the item by itself.
- A drop is lost if it is not collected within **8 s**, or when the battle
  ends for any reason (victory, defeat or escape). A drop can be collected at
  most once.
- Collected items are added to the inventory immediately. The weapon to use
  is chosen in the Inventory screen before a battle; it cannot be swapped
  mid-battle.

## Observer drone and enemy intel

Three separate concepts:

1. **`BattleRecord`** — internal summary of what really happened (outcome,
   duration, per-weapon shots/hits/damage, core damage, destroyed parts,
   collected items). Always complete.
2. **Observer transmission** — what the enemy drone recorded while alive:
   per-weapon-type shots, hits and damage, damage per boss zone, plus core
   damage dealt while the core was exposed. Nothing else (no inventory, no
   positions).
3. **`BossIntel`** — the reports the enemy faction actually received. It only
   grows; reports from earlier battles are never erased.

Rules:

- The drone hovers along the left edge with **60 integrity**. It does not
  attack and can be destroyed by any player weapon.
- It transmits **when the battle ends, if it is still alive**, whatever the
  outcome (victory, defeat or escape). Destroying it means the enemy gets no
  new intel from that battle.
- Each transmission becomes a `WeaponExposureProfile`. Each weapon type that
  was fired gets a level from its share of the total damage dealt:
  **low < 15% ≤ medium ≤ 50% < high**. Weapons that were never fired are not
  in the profile, so owning a weapon never exposes it.
- **Weak point focus** is the share of core damage dealt while the core was
  exposed; at **50% or more** the profile flags the player as exploiting the
  weak point.
- **Zone focus** is the share of damage dealt to boss parts that landed in
  each zone (left, center, right). A part belongs to the center zone if its
  center is at most 20 units from the boss center. The zone is the one of the
  part that actually took the hit (the outer cover, when one absorbed it).
  Hits on the observer do not count.
- Metrics are aggregated in memory during the battle; nothing is written per
  shot.

## Boss lineage (evolution)

Only the first boss, the Sentinel, is written by hand. Every later boss is
generated: it is the previous boss plus a few **mutations** chosen from how
you fought it. There is no fixed list of bosses: a player who keeps hitting
the left side can reach boss 5 with only the left side upgraded.

- **Lineage** (`BossLineage`): the base boss plus one generation per boss.
  A generation stores only its mutations; a boss is rebuilt by applying every
  generation up to it, so it is identical every time it is fought. Bosses
  are named `Sentinel`, `Sentinel Mk II`, `Mk III`... with ids
  `boss.sentinel`, `boss.sentinel.gen2`, `boss.sentinel.gen3`...
- **When it grows:** finishing a battle against the **latest** boss (victory,
  defeat or escape) generates the next one. Replaying an older boss never
  changes the lineage.
- **What it learns from:** the report the observer transmitted from that
  battle. If the observer was destroyed, the next boss is born unchanged.
  The inventory is never used.
- **Director** (`EvolutionDirector`, deterministic): every zone that took at
  least **30%** of the damage dealt to boss parts is a candidate. Mutations
  are ranked by that share (armor upgrade first, then extra plate) and
  applied while valid, up to **3 per generation**. The same boss and report
  always give the same evolution.

**Mutations** (`lib/features/combat/domain/entities/boss_mutation.dart`):

- **Armor upgrade:** every armor and hull part of the zone gains one armor
  level, up to level 3. Each level adds half of the part's level-1
  integrity (armor 100 → 150 → 200, wing 70 → 105 → 140). The core and
  weapons are never upgraded, so the escape threshold does not change.
- **Extra plate:** one armor plate (80 integrity) just below the zone,
  spanning its parts. It covers every part of the zone that had no cover, so
  it has to break first. One per zone; later armor upgrades raise it too.
- Evolved parts get an orange outline in battle and one inner line per
  armor level above 1. The HUD lists the evolutions the boss carries, and
  the briefing explains each new mutation with the share of damage that
  caused it.

Combat still supports mechanics no catalog boss uses yet: per-weapon damage
multipliers, a shortened core window, and a core shield powered by cannons.
They are covered by tests with a test-only boss (`test/support/`) and are
available to future bosses.

## Saving

Inventory, equipped weapon, enemy intel, progress (battles fought, bosses
fought and defeated, last battle record) and the boss lineage survive an app
restart.

- Stored as one JSON document with a `schemaVersion` (currently 5) in
  `shared_preferences`, behind the `SaveRepository` interface
  (`lib/features/save_game/`). Tests use `InMemorySaveRepository`, which goes
  through the same JSON codec.
- The save is loaded once before the first frame. It is written when
  persisted state changes: collecting an item, equipping a weapon, receiving
  intel or finishing a battle. Never per frame.
- Bad data never crashes the game: a corrupted save, or one written by a
  newer schema version, starts a new game and is replaced on the next write.
  Unknown item, weapon, zone or mutation ids, and bosses outside the saved
  lineage, are dropped. An equipped weapon that is no longer owned falls
  back to the Blaster.
- Schema changes go through `SaveGameCodec.migrations`, one step per version.
  `migrations[1]` upgrades v1 to v2 by adding the defeated bosses: v1 only
  knew the last battle, so its boss counts as defeated if that battle was a
  victory. `migrations[2]` upgrades v2 to v3 by adding damage per zone: older
  reports and battles get none, so they never drive an evolution.
  `migrations[3]` upgrades v3 to v4 by adding the boss each report came from:
  older reports cannot be attributed, so no boss evolves from them.
  `migrations[4]` upgrades v4 to v5 by adding the lineage: v4 had two fixed
  bosses, the Sentinel and the Mk II (`boss.sentinel_mk2`, renamed to
  `boss.sentinel.gen2`). Each one that was fought gets its next generation,
  evolved from its latest report.
- Features do not know about saving: each controller starts from an
  `initial...Provider` that the app overrides with the restored save.

## Known limitations

- Prototype content only: one base boss, two mutation kinds and two player
  weapons (Missile and Laser types exist in the domain but have no content
  yet; enemy lasers and missiles are planned as evolutions).
- The Sentinel concentrates most of its integrity in the center (670 of 740),
  so a battle that ends in victory or escape almost always evolves the
  center. The sides only evolve after battles that spend a lot of fire on a
  wing.
- Mutations only add armor for now; the boss's weapons and attacks do not
  evolve yet.
- Only one save slot.
- Flame rendering is verified manually; automated tests cover the rules, the
  battle flow, the providers and the menu and map screens, not what is drawn.
- Part integrity bars sit just above each part, so a bar can overlap the part
  right above it (e.g. the armor bar touches the core).

## Tests

- `test/unit/` — domain rules (damage, boss parts, vulnerability window,
  escape rule, boss behavior, drops, observer, battle record, exposure
  profile, intel, zone damage, boss mutations, lineage and evolution
  director, core shield and modifiers, campaign progress, ship
  movement/firing/hull, battle state, inventory and loadout,
  save codec and versioning, shared preferences adapter).
- `test/integration/` — full boss battles (victory and escape) played through
  `BattleSession`, drop collection wired to the inventory, observer
  transmissions reaching (or not reaching) the enemy intel, a center-focused Sentinel battle evolving the Mk II's center (and the
  Blaster still beating it), evolutions accumulating into the Mk III, older
  bosses not growing the lineage, and an app restart restoring the save and
  the lineage, all through Riverpod without rendering.
- `test/widget/` — main menu, campaign map states and navigation, and the
  reset confirmation.
