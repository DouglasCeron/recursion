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
| 5 | Second, adaptive boss driven by transmitted intel | Pending |
| 6 | Local persistence (versioned JSON), validation and docs | Pending |

## Requirements

- Flutter 3.44 (Dart 3.12) or newer on the stable channel.
- An Android emulator/device or an iOS simulator/device.

## Running

```sh
flutter pub get
flutter run                    # opens the main menu
flutter run --route /battle    # jumps straight into the boss battle
```

Controls: drag anywhere on the screen to move the ship; weapons fire
automatically.

## Checks

```sh
dart format lib test
flutter analyze
flutter test
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
- `infrastructure/` — persistence adapters (added in stage 6).

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
- Inventory and loadout currently live in memory only; they reset when the
  app restarts until persistence lands in stage 6.

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
  shot. Intel currently lives in memory and resets on restart until stage 6.

## Tests

- `test/unit/` — domain rules (damage, boss parts, vulnerability window,
  escape rule, boss behavior, drops, observer, battle record, exposure
  profile, intel, ship movement/firing/hull, battle state, inventory and
  loadout).
- `test/integration/` — full boss battles (victory and escape) played through
  `BattleSession`, drop collection wired to the inventory, and observer
  transmissions reaching (or not reaching) the enemy intel through Riverpod,
  all without rendering.
- `test/widget/` — app smoke test.
