# Architecture

How the macOS port of *Invasiones* is put together today. The game logic is a Swift translation of the original C# game ([luciavmf/invasiones](https://github.com/luciavmf/invasiones), `Juego/Invasiones/fuente/`), which stays the reference for behaviour.

Planned changes to this structure are tracked in issue [#3](https://github.com/luciavmf/invasiones-macos/issues/3).

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
| `Level/` | `Episode`, `Level`, `AI`, `Command`, `Objective`, `MapObject`, `Obstacle`, `ObjectTable` |
| `Level/Players/` | `Player` and its subclasses `ArgentineTeam`, `EnemyTeam` |
| `Level/Units/` | `Unit`, `Group` |
| `Map/` | `Map`, `Tileset`, `Tile`, `Camera`, `TilesetID`, `PathFinder/` |
| `Rendering/`, `Sprites/` | `Video`, `Surface`, `GameFont`, `Anchor`, `Sprite`, `Animation`, `AnimObject` |
| `GUI/` | `Button`, `Menu`, `ConfirmationMenu`, `Hud`, `Tips`, `Ring`, `Frame` |
| `Events/` | `Mouse`, `Keyboard` |
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

- **loading** reads the level, the map and both teams' units, and sets the static `MapObject.map` and `MapObject.camera` that units and map objects read (`ArgentineTeam` sets `Group.map`).
- **showIntro** shows the battle's intro pages (`StringID.introPages`).
- **playing** updates the map (camera scroll), both teams, the HUD, the objectives and the obstacles; it checks whether the player has lost.
- **showObjectives** shows the current objective over the paused game.
- **won / lost** show the result and a confirmation menu.

`Episode` both runs this flow and draws every state's screen.

## Teams, groups and units

- `Player` holds a team's units, groups, the selected unit or group, and the current objective. `updateUnits()` moves every unit, collects units selected by a drag rectangle (at most `Player.maxSelectedUnits`, 6), resolves collisions and removes dead units.
- `ArgentineTeam` adds the player's controls: it reads `Mouse` directly to select units, drag-select, give move, attack and heal orders, form groups and change the cursor.
- `EnemyTeam` places the British units, and `AI` gives their groups orders from the level file. Units without a group patrol around their starting point.
- `Group` moves several units together behind a commander.
- `Unit` (a `MapObject`) has stats read from `unidades/*.csv` and a state machine: `idle`, `moving`, `pursuingUnit`, `attacking`, `dying`, `dead`, `patrolling`, `healing`. It also draws itself, its health bar and its selection, and tests whether the mouse is over it.

## Map and pathfinding

- `Map` loads a Tiled `.tmx` map and its `.tsx` tilesets. Besides the drawable layers it keeps `physicalTilesLayer`, a grid at twice the map resolution holding each cell's `TilesetID`. Grass and dirt are walkable; `invalidateTile` marks cells as trees to block them.
- `PathFinder` runs A* on that grid through the `WalkableGrid` protocol (10 per straight step, 14 per diagonal, no corner cutting, 4.5 s timeout).
- `Camera` is the visible part of the map; `Map.update()` scrolls it when the mouse is near the screen edge.

## Rendering

`Video` wraps SpriteKit with an SDL-like API: `draw`, `write`, `fillRect`… with `Anchor` positioning and `GameColor`. It uses C# coordinates (top-left origin) and converts to SpriteKit's bottom-left origin. Everything is redrawn every frame.

## Input

`GameScene` turns `NSEvent`s into the `Mouse` and `Keyboard` singletons. `Mouse.update()` tracks the drag rectangle; game code reads the pressed buttons, position and rectangle wherever it needs them (mostly `ArgentineTeam`, `Menu` and `Button`).

## Resources

`ResourceManager.shared` loads what `data/res.json` lists and caches it: images, fonts, sounds, unit templates, soldier sprites and standalone animations. Resources are identified by enums (`ImageID`, `SoundID`, `AnimationID`…) whose raw values are positions in `res.json`; `GameText` loads `strings_<language>.json` by `StringID`.

## Shared state

Several parts of the game are reached through globals rather than passed in:

| Global | Used by |
|---|---|
| `MapObject.map`, `MapObject.camera` (static, set by `Episode`), `Group.map` (static, set by `ArgentineTeam`) | units, groups, obstacles, animations |
| `Mouse.shared`, `Keyboard.shared` | `ArgentineTeam`, GUI, `Map`, `Episode` |
| `ResourceManager.shared` | about 60 call sites |
| `Sound.shared`, `PathFinder.shared` | default parameters of `Unit` (tests pass fakes) |

## Tests

`InvasionesTests` (Swift Testing) runs inside the app. It covers the pathfinder, `Unit` movement with fakes, `StateMachine`, `GameText`, `Command`, `Objective`, `Camera` and that the resource enums match `res.json`. Battle rules, selection and orders aren't covered yet (see #3).
