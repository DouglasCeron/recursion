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
| 8 | Layered boss structures that cover inner parts | Pending |
| 9 | Player focus by zone; the next boss reinforces the focused zone | Pending |
| 10 | Battle HUD that scales with many boss parts | Pending |
| 11 | Missile and Laser content | Pending |

## Requirements

- Flutter 3.44 (Dart 3.12) or newer on the stable channel.
- An Android emulator/device or an iOS simulator/device.

## Running

```sh
flutter pub get
flutter run                    # opens the main menu
flutter run --route /campaign  # opens the campaign map
flutter run --route /battle    # jumps straight into the Sentinel battle
flutter run --route "/battle?boss=boss.warden"    # straight into the Warden
flutter run --route "/briefing?boss=boss.warden"  # the Warden briefing
```

Controls: drag anywhere on the screen to move the ship; weapons fire
automatically.

Suggested first session: open Campaign and fight the Sentinel (destroy its
cannon and touch the falling Heavy Cannon to collect it), equip it in
Inventory, then pick the Warden on the map and read its briefing. Destroy the
observer drone on the left edge if you do not want the enemy to learn from
that battle.

## Campaign

- The main menu has Campaign, Inventory and Reset progress (asks for
  confirmation, then erases items, progress and enemy intel).
- The campaign map shows every boss as a numbered point on one path, in
  `BossCatalog.all` order, joined by lines. Each point is locked,
  available, fought (not defeated yet) or defeated (check mark).
- A boss unlocks once the previous one has been fought, whatever the
  outcome; the line to it lights up. Defeated bosses can be replayed.
- Adaptive bosses open their briefing first; others go straight to battle.

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
| Core | 400 | Destroying it defeats the boss. Takes ×2 damage while exposed. |
| Armor | 100 | Wide plate under the core; shields it from shots coming from below. |
| Cannon | 100 | Fires aimed shots. Destroying it changes the boss's behavior. |

- **Attacks:** first attack after 1.5 s. With the cannon: one aimed shot every
  1.2 s (15 damage). Without the cannon: a 5-shot downward fan (80° spread)
  every 2 s (8 damage each), and the boss drifts faster (0.6 → 1.1 rad/s).
- **Core vulnerability window:** 8 s cycles, closed for 5 s then exposed for
  3 s (first exposure at 5 s). Only core hits during the window get the ×2
  bonus; outside it the core takes normal damage.
- **Escape:** when the boss's total integrity (sum of all parts, 600 max)
  drops to 25% (150) or below, it announces the escape (HUD countdown and
  flashing parts) and leaves 5 s later unless the core is destroyed first.
  The escape is announced at most once.
- **Ship:** 100 hull. After taking damage it is invulnerable for 0.75 s.
  Hull at zero loses the battle.

Battle outcomes: `victory` (core destroyed), `defeat` (ship destroyed) and
`bossEscaped`.

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
   per-weapon-type shots, hits and damage, plus core damage dealt while the
   core was exposed. Nothing else (no inventory, no positions).
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
- Metrics are aggregated in memory during the battle; nothing is written per
  shot.

## Second boss: Warden (adaptive)

Point 2 of the campaign, unlocked after the first Sentinel battle, whatever
its outcome. It opens a briefing screen first.

| Part | Integrity | Rule |
|---|---|---|
| Core | 360 | Destroying it defeats the boss. Shielded while any cannon works. |
| Left / right cannon | 120 each | Fire aimed shots in turns (0.9 s, 12 damage). |

- **Shield:** blocks all core damage. Destroying a cannon drops it for
  **3 s**; destroying both drops it for good and switches the attack to a
  7-shot burst (100° spread, every 1.6 s, 8 damage each).
- The core still uses the 8 s vulnerability window (×2 while exposed), but
  it is only exposed when the shield is down.
- Escape follows the same rule as the Sentinel (25% total integrity, 5 s).

Only the Warden adapts, and only from the **latest intel report** (never from
the inventory):

| Observed | Countermeasure |
|---|---|
| Heavy Cannon medium / high | Impact plating: −20% / −40% damage from it |
| Blaster medium / high | Deflector screen: −15% / −30% damage from it |
| Weak point exploited | Core exposure shortened from 3 s to 2 s |

- Reductions never exceed **40%**, and a fully **exposed core always takes
  full (×2) damage**, so every build can still win.
- Low exposure, unused or merely owned weapons are never countered. Without
  any intel, the Warden fights with its default setup.
- The briefing lists each countermeasure and its reason. In battle, adapted
  parts get a cyan outline, the core shows a shield ring while shielded, and
  the HUD shows the active reductions and the shield-down countdown.
- The combat domain only sees neutral `BossModifiers`; the rules that build
  them live in `boss_evolution` (`AdaptationRules`).

## Saving

Inventory, equipped weapon, enemy intel and progress (battles fought, bosses
fought and defeated, last battle record) survive an app restart.

- Stored as one JSON document with a `schemaVersion` (currently 2) in
  `shared_preferences`, behind the `SaveRepository` interface
  (`lib/features/save_game/`). Tests use `InMemorySaveRepository`, which goes
  through the same JSON codec.
- The save is loaded once before the first frame. It is written when
  persisted state changes: collecting an item, equipping a weapon, receiving
  intel or finishing a battle. Never per frame.
- Bad data never crashes the game: a corrupted save, or one written by a
  newer schema version, starts a new game and is replaced on the next write.
  Unknown item, boss or weapon ids are dropped, and an equipped weapon that
  is no longer owned falls back to the Blaster.
- Schema changes go through `SaveGameCodec.migrations`, one step per version.
  `migrations[1]` upgrades v1 to v2 by adding the defeated bosses: v1 only
  knew the last battle, so its boss counts as defeated if that battle was a
  victory.
- Features do not know about saving: each controller starts from an
  `initial...Provider` that the app overrides with the restored save.

## Known limitations

- Prototype content only: two bosses and two weapons (Missile and Laser
  types exist in the domain but have no content yet).
- Only one save slot.
- Flame rendering is verified manually; automated tests cover the rules, the
  battle flow, the providers and the menu and map screens, not what is drawn.
- The battle HUD is tight with three boss part bars and can overlap the top
  of the Warden.

## Tests

- `test/unit/` — domain rules (damage, boss parts, vulnerability window,
  escape rule, boss behavior, drops, observer, battle record, exposure
  profile, intel, adaptation rules, Warden shield and modifiers, boss
  unlocks, ship movement/firing/hull, battle state, inventory and loadout,
  save codec and versioning, shared preferences adapter).
- `test/integration/` — full boss battles (victory and escape) played through
  `BattleSession`, drop collection wired to the inventory, observer
  transmissions reaching (or not reaching) the enemy intel, different weapon
  usage producing different Warden setups, and an app restart restoring the
  save, all through Riverpod without rendering.
- `test/widget/` — main menu, campaign map states and navigation, and the
  reset confirmation.
