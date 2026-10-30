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
| 2 | Modular boss (cannon, armor, core), vulnerability window, flagged escape | Pending |
| 3 | Component drops, in-battle collection, inventory and loadout | Pending |
| 4 | Observer drone, weapon exposure profile, intel transmission | Pending |
| 5 | Second, adaptive boss driven by transmitted intel | Pending |
| 6 | Local persistence (versioned JSON), validation and docs | Pending |

## Requirements

- Flutter 3.44 (Dart 3.12) or newer on the stable channel.
- An Android emulator/device or an iOS simulator/device.

## Running

```sh
flutter pub get
flutter run                    # opens the main menu
flutter run --route /battle    # jumps straight into the training battle
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
- A target reports its destruction exactly once; later hits are ignored.
- The arena uses a fixed logical resolution of 360×640 units, scaled to the
  device screen.

## Tests

- `test/unit/` — domain rules (damage, targets, ship movement/firing, battle
  state).
- `test/integration/` — a full battle played through `BattleSession` without
  rendering.
- `test/widget/` — app smoke test.
