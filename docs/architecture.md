# Architecture

How the macOS port of *Invasiones* is put together today. The game logic is a Swift translation of the original C# game ([luciavmf/invasiones](https://github.com/luciavmf/invasiones), `Juego/Invasiones/fuente/`), which stays the reference for behaviour.

Planned changes to this structure are tracked in issue [#3](https://github.com/luciavmf/invasiones-macos/issues/3). The rules of specific areas are described in [`docs/specs/`](specs/).

## Overview

```
GameScene (SpriteKit, 20 FPS)
└── GameFrame ── StateMachine
                  ├── LogoState, MainMenuState, HelpState, CreditsState, OptionsState, ExitState
                  └── GameState
                      └── Episode                  one battle session
                          ├── Level                objectives per battle (nivel/nivel_N.xml)
                          ├── Map + Camera         isometric TMX map, scrolling viewport
                          ├── ObjectTable          map objects indexed by physical tile, for drawing and hit-tests
                          ├── ArgentineTeam        the player's side (Player subclass)
                          │   └── Group → Unit
                          ├── EnemyTeam            the computer's side (Player subclass)
                          │   └── Group → Unit, driven by AI
                          ├── Obstacles            buildings, trees… (MapObject subclasses)
                          └── Hud                  bottom panel, unit details, tips
```

| Folder | Contents |
|---|---|
| `StateMachine/`, `States/` | Top-level screens and the machine that switches between them |
| `Level/` | `Episode`, `Battlefield`, `Level`, `AI`, `Command`, `Objective`, `MapObject`, `Obstacle`, `ObjectTable` |
| `Level/Players/` | `Player` and its subclasses `ArgentineTeam`, `EnemyTeam`; `PlayerInput`, `PlayerIntent` |
| `Level/Units/` | `Unit`, `Group` |
| `Map/` | `Map`, `Tileset`, `Tile`, `Camera`, `TilesetID`, line of sight, `PathFinder/` |
| `Rendering/`, `Sprites/` | `Video`, `Surface`, `GameFont`, `Anchor`, `Sprite`, `Animation`, `AnimObject` |
| `GUI/` | `Button`, `Menu`, `ConfirmationMenu`, `Hud`, `Tips`, `Frame` |
| `Events/` | `Mouse`, `Keyboard`, `PointerDevice` |
| `Audio/` | `Sound`, `SoundID` |
| `Resources/` | `ResourceManager`, `GameText`, resource ID enums, `Utils` |

## Frame loop

Each SpriteKit frame:

1. `GameScene.update(_:)` calls `GameFrame.update()`.
2. `StateMachine.update()` runs any queued transition (`exit()` on the old state, `start()` on the new one), then `update()` on the current state.
3. The current state's `draw(_:)` draws into `Video`.
4. `Video.clear()` removes every node; the next frame rebuilds the scene from scratch.

The first state is set with `setState`, which skips `start()`, so start-up code lives in `GameFrame.startGame()`.

## A battle: `Episode`

`Episode` runs one battle session through these states:

```
loading → showIntro → playing ⇄ showObjectives → won / lost
```

- **loading** creates the map, the camera and a `Battlefield` holding both, then reads the level, the obstacles and both teams' units. Everything placed on the map receives the `Battlefield` when it's created.
- **showIntro** shows the battle's intro pages (`StringID.introPages`).
- **playing** updates the map (camera scroll), both teams, the HUD, the objectives and the obstacles; it checks whether the player has lost.
- **showObjectives** shows the current objective over the paused game.
- **won / lost** show the result and a confirmation menu.

`Episode` both runs this flow and draws every state's screen.

## Teams, groups and units

- `Player` holds a team's units, groups, the selected unit or group, and the current objective. `updateUnits()` moves every unit, resolves collisions and triggers attacks on visible enemies; dead units are removed afterwards.
- `ArgentineTeam` is the player's side. `handle(_:)` carries out `PlayerIntent`s: selecting units (a drag selects at most `Player.maxSelectedUnits`, 6, and forms a group), deselecting, and move, attack and heal orders. See [Input](#input) and [`specs/selection-and-orders.md`](specs/selection-and-orders.md).
- `EnemyTeam` places the British units, and `AI` gives their groups orders from the level file. Units without a group patrol around their starting point.
- `Group` moves several units together behind a commander.
- `Unit` (a `MapObject`) has stats read from `unidades/*.csv` and a state machine: `idle`, `moving`, `pursuingUnit`, `attacking`, `dying`, `dead`, `patrolling`, `healing`. It also draws itself, its health bar and its selection, and tests whether the mouse is over it.

## Map and pathfinding

- `Map` loads a Tiled `.tmx` map and its `.tsx` tilesets. Besides the drawable layers it keeps `physicalTilesLayer`, a grid at twice the map resolution holding each cell's `TilesetID`. Grass and dirt are walkable; `invalidateTile` marks cells as trees to block them.
- `PathFinder` runs A* on that grid through the `WalkableGrid` protocol (10 per straight step, 14 per diagonal, no corner cutting, 4.5 s timeout).
- `getLineOfSightPosition` (an extension on `WalkableGrid`) walks from a target toward a unit and returns the first walkable tile; healing uses it to stop next to an infirmary.
- `Camera` is the visible part of the map; `Map.update()` scrolls it when the mouse is near the screen edge.

## Battlefield

`Battlefield` is a small struct holding the battle's map and camera. `Episode` creates it; `Player.battlefield` hands it to the units and objects a team places, and `Level` to the fire animations it creates. Map objects see the map only through the `BattleMap` protocol (walkability and tile size), so tests can place units on a `TestGrid`. Unit templates in `ResourceManager` have no battlefield, since they're only copied.

## Rendering

`Video` wraps SpriteKit with an SDL-like API: `draw`, `write`, `fillRect`… with `Anchor` positioning and `GameColor`. It uses C# coordinates (top-left origin) and converts to SpriteKit's bottom-left origin. Everything is redrawn every frame.

## Input

`GameScene` turns `NSEvent`s into the `Mouse` and `Keyboard` singletons. `Mouse.update()` tracks the drag rectangle.

In battle, `PlayerInput` reads the mouse for the player's team, each frame:

1. A drag that ended becomes a *select in rectangle* intent, handled before the units update.
2. After the units update, clicks become intents: *select* a unit, *deselect*, or an order (*move*, *attack*, *heal*) depending on what is under the pointer. Handled clicks are released so they aren't read twice.
3. The cursor is picked from the selection and what is under the pointer.

`PlayerInput` reads a `PointerDevice` (`Mouse` conforms) and asks the map through `InputMap` (`Map` conforms), so tests use fakes for both.

Elsewhere, code reads the mouse directly: the menus and buttons, `Map` (edge scrolling) and `Episode` (the drag rectangle it draws).

## Resources

`ResourceManager.shared` loads what `data/res.json` lists and caches it: images, fonts, sounds, unit templates, soldier sprites and standalone animations. Resources are identified by enums (`ImageID`, `SoundID`, `AnimationID`…) whose raw values are positions in `res.json`; `GameText` loads `strings_<language>.json` by `StringID`.

## Shared state

Several parts of the game are reached through globals rather than passed in:

| Global | Used by |
|---|---|
| `Mouse.shared`, `Keyboard.shared` | GUI, `Map`, `Episode`; default parameter of `ArgentineTeam` (passed to `PlayerInput`) |
| `ResourceManager.shared` | about 60 call sites |
| `Sound.shared`, `PathFinder.shared` | default parameters of `Unit` (tests pass fakes) |

## Tests

`InvasionesTests` (Swift Testing) runs inside the app. It covers the pathfinder, line of sight, map objects and units on a hand-made `Battlefield` (`TestGrid` is a `BattleMap`), selection and orders (`PlayerInput` with `FakePointer` and `FakeInputMap`, `ArgentineTeam.handle(_:)`), infirmary lookup on the first level's map, `StateMachine`, `GameText`, `Command`, `Objective`, `Camera` and that the resource enums match `res.json`. Combat isn't covered yet (see #3).
