# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS port of a Windows C# RTS (real-time strategy) game, translated to Swift using SpriteKit for rendering. The original C# source lives in the separate repo https://github.com/luciavmf/invasiones under `Juego/Invasiones/fuente/` (clone it next to this repo, e.g. `../invasiones/Juego/Invasiones/fuente/`) and is the authoritative reference for game logic and documentation.

## Documentation

- `docs/architecture.md` — how the game is structured today. Update it when a change alters that structure.
- `docs/specs/` — the rules of specific areas (e.g. `selection-and-orders.md`), as the game behaves today. Update a spec when its rules change.
- Plans for larger changes live in their GitHub issue (e.g. #3), not in the repo.

## Build & Run

- Open `Invasiones/Invasiones.xcodeproj` in Xcode
- Build: `xcodebuild -scheme Invasiones -project Invasiones/Invasiones.xcodeproj`
- Run: Cmd+R in Xcode
- Tests: `xcodebuild test -scheme Invasiones -project Invasiones/Invasiones.xcodeproj`

Debug builds show FPS/node count and run in windowed mode. Release builds run fullscreen.

## Architecture

### Frame Loop

```
GameScene.update(_:)       [SpriteKit callback, 20 FPS]
  → GameFrame.update()     [dispatches to state machine]
  → StateMachine.update()  [handles pending transitions, calls current state]
  → State.update()         [current state logic]
  → State.draw(Video)      [current state rendering]
  → Video.clear()          [removes all SKNodes for next frame]
```

### State Machine

`StateMachine` (`StateMachine/`) manages top-level game states:
- `LogoState` → `MainMenuState` → `GameState` → `ExitState`
- States implement `start()`, `update()`, `draw()`, `exit()`
- `setNextState()` queues a transition; it executes at the start of the next `update()` call
- `setState()` switches immediately without calling `exit()`/`start()` — used only for the initial state
- `LogoState.start()` is **never called** — the first state is set via `setState()`, bypassing `start()`. Init code must go in `GameFrame.startGame()`

### Active Battle: `GameState` → `Episode`

`Episode` (`Level/`) owns the complete battle session:

```
Episode
├── BattleFlow      [states, intro/objectives pages, game over, cheats]
├── BattleView      [draws the battle; IntroScreen, ObjectivesScreen, WonScreen, LostScreen draw over it]
├── Level           [objective tracker, loads nivel_N.xml]
├── Map             [isometric TMX tile map, multi-layer]
├── ArgentineTeam   [player forces]
│   └── Groups → Units
├── EnemyTeam       [AI forces]
│   └── Groups → Units
└── AI              [enemy decision-making]
```

Battle lifecycle: `loading → showIntro → playing ⇄ showObjectives → won/lost`. `BattleFlow` holds these states and transitions without drawing (rules in `docs/specs/battle-flow.md`); `Episode` loads and updates the battle; the types in `Level/Screens/` draw it.

### Unit System

`Unit` has `UnitStats` (health, attack, resistance, visibility, aim, range, speed) and states: `idle`, `moving`, `dying`, `attacking`, `pursuingUnit`, `dead`, `patrolling`, `healing`.

`Group` wraps a squad of units. `Command` is a single order. `Objective` is a stack of commands.

**Combat notes** (full rules, matching the C# original and its quirks, in `docs/specs/combat.md`):
- Damage is always `attackPoints` — no accuracy roll. `aim` is loaded from CSV but was never used in the original C# attack logic.
- Enemy units without a group (`AI`) are set to `PATROLLING` on load and wander randomly between `RANDOM_PATRULLA_MIN=8` and `RANDOM_PATRULLA_MAX=16` tiles from their spawn position.
- Counter-attack (`contraAtacar` → `Unit.counterAttack`): when a unit enters `attacking`, it notifies the target, which fights back if it is idle and in range.
- Drag selection: dragging a rectangle selects at most **6** units (`Player.maxSelectedUnits`, as in the C# original); more than one becomes a `Group` that moves together.
- Player input: `PlayerInput` turns the mouse into `PlayerIntent`s, which `ArgentineTeam.handle(_:)` carries out. `ArgentineTeam` doesn't read `Mouse` itself.

### Rendering (`Video`)

`Video` wraps SpriteKit with an SDL-style API. It owns a `SKNode` canvas that is fully rebuilt each frame (all nodes removed in `clear()`, re-added in `draw()`). Coordinate origin is bottom-left `(0,0)` at `Video.width × Video.height` (1024×768).

Screen dimensions live on `Video` as `Video.width` / `Video.height` — do not add a separate constants file for these.

### GUI (`GUI/`)

GUI components use composition: each embeds `var frame: Frame` (defined in `GUI/Frame.swift`) instead of inheriting from a base class.

`Frame` is a plain struct holding `posX`, `posY`, `width`, `height` and a `mutating setPosition(x:y:anchor:)` helper. Styling (font, image, label) lives on each component individually.

Components: `Button` (struct), `Menu` (class), `ConfirmationMenu` (class), `Tips` (class), `Hud`.

Input from `NSEvent` flows through `GameScene` into `Mouse` and `Keyboard` singletons.

### Pathfinding

`PathFinder` runs A* on the physical tile grid (2× map resolution). 4.5-second timeout for long calculations. Costs: 10 orthogonal, 14 diagonal. Diagonal steps are only allowed when both adjacent straight tiles are walkable.

- The game uses `PathFinder.shared`; `Map.load` registers itself via `loadMap(_:)`.
- Walkability comes from the `WalkableGrid` protocol (`Map` conforms). It is queried live, because `Map.invalidateTile` blocks tiles during a level — do not copy the grid.
- The grid is held weakly, and the timeout clock is injectable (`PathFinder(now:)`).

### Testing

Unit tests (`InvasionesTests`, Swift Testing) run inside the app (`TEST_HOST`). Test suites touching game types need `@MainActor` (the app target defaults to MainActor isolation).

- `TestSupport.swift` has `TestGrid` (walkability from strings, `.` = walkable), `FakeSound`, `FakeClock`, `FakePointer` (a mouse), `FakeInputMap` (the tile under the pointer), `FakeSprite` (for `UnitView`), `FakeLevel` and `FakeKeyboard` (for `BattleFlow`), and `GameUnit` (Foundation also declares `Unit`, so use `GameUnit` in tests).
- `Unit` takes its `PathFinder`, `SoundPlayer` and `ResourceManager` as init parameters defaulting to `.shared`; pass fakes (or a fresh `ResourceManager()`) in tests. Follow the same pattern when making other classes testable.

### Resources

`ResourceManager` (`static let shared`) loads and caches all assets listed in `data/res.json`. The battle receives it as a `resources` parameter defaulting to `.shared` (`Episode`, `Map`, `Level`, `Command`, the teams, `PlayerInput`, `Unit`, `BattleView` and the screens); tests create their own `ResourceManager()` instead of loading into the shared one. It provides:
- Images → `Surface` (wraps `SKTexture`)
- Fonts → `GameFont`
- Sprites → `Sprite` (collection of `Animation` objects)
- Animation metadata → `Animation` (sprite sheet controller)
- Unit stats → `UnitStats` (parsed from `unidades/*.csv`; Spanish keys)

Resources are identified by typed enums (`StringID`, `SoundID`, `ImageID`, `FontFamily`, `UnitType`, `SpriteID`, `AnimationID`, `TilesetID`, `TileKind`). Except `StringID` (raw value = JSON key) and `TileKind`, their raw values are positions in the lists of `data/res.json`, so reordering that file means reordering the enum; `ResourceIDTests` checks they match.

`GameText` loads localised strings from `data/strings_es.json` / `strings_en.json` / `strings_de.json` (by `Language.current`).

### res.json Parsing — Critical Gotcha

`res.json` uses **Spanish keys** that must match the property names of the `Decodable` model (`ResJSON` in `ResourceManager.swift`) exactly:
- `fuentes`, `imagenes`, `unidades`, `anims`, `sprites`
- `escenarios` → `tilesets`, `mapas`; `sonidos` → `sfx`

Renaming these properties (or the keys) breaks loading at runtime with a decoding error, not at compile time. Level files (`nivel/*.xml`) and tilesets (`escenarios/*.tsx`) also use Spanish element, attribute and property names (`<batalla>`, `<objetivo>`, `cantidad`, `PATRICIO`…) that the XML parsers match as strings.

## Swiftify Progress

The codebase has been progressively Swiftified from the C# port style. Completed:
1. `m_` prefix removal from all private properties
2. Singleton pattern: `static let shared = Foo()` (was lazy `private static var instance`)
3. Setter methods → `didSet` observers (Tileset, Menu)
4. `NSObject` removed from `ResourceManager` (conformance was unused)
5. Column-alignment padding spaces removed throughout
6. Argument labels added to game-logic functions (removing `_` suppression)
7. C# XML doc comments restored as Swift `///` comments in English
8. `Int16` → `Int` throughout (`Tile`, `Tileset`, `Map`, `PathFinder`, `Obstacle`, `Player`, `ArgentineTeam`, `EnemyTeam`)
9. `GUIBox` abstract class → `Frame` struct (composition; each GUI component embeds `var frame: Frame`)
10. `Button` converted from class to struct
11. Remaining Spanish identifiers renamed (`IA` → `AI`, `NivelXMLDelegate` → `LevelXMLDelegate`, `StateMachiche/` → `StateMachine/`)
12. Simple setters → properties (`Sound.isMuted`, `Video.color`/`font`/`fontColor`, `Group.ai`, `Mouse.cursor`, `Unit.objectiveCommand`, `Surface.alpha`)
13. `State` is a protocol (missing `start`/`update`/`draw`/`exit` fails at compile time); each state declares only the members it uses
14. All classes are `final` except `MapObject` and `Player`, which have subclasses
15. `Anchor` OptionSet instead of `Int` anchor flags; `GameColor` struct instead of `Int` colours
16. Optionals instead of `-1` sentinels; enums compared directly instead of through `.rawValue`
17. `Res` integer constants → typed resource IDs (`StringID`, `SoundID`, `ImageID`, …)

In progress / not yet done:
- `throws` instead of `Bool` returns
- `struct` for other value types

## Conventions

**Language:** All code, comments, and identifiers are in English. `res.json` and the other data files remain in Spanish — do not translate their keys, element or attribute names.

**Key vocabulary (C# → Swift):**
| C# (Spanish) | Swift (English) |
|---|---|
| `Unidad` | `Unit` |
| `Grupo` | `Group` |
| `Mapa` | `Map` |
| `Orden` | `Command` |
| `Objetivo` | `Objective` |
| `Bando` | Team (Argentine/Enemy) |
| `Nivel` | `Level` |
| `Episodio` | `Episode` |
| `Estado` | `State` |
| `MaquinaDeEstados` | `StateMachine` |
| `Superficie` | `Surface` |
| `Fuente` | `GameFont` |
| `Texto` | `GameText` |

**Singletons:** accessed via `Foo.shared` (e.g., `ResourceManager.shared`, `Log.shared`, `PathFinder.shared`).

**SourceKit false positives:** Xcode's indexer frequently shows "Cannot find type X in scope" errors after edits. These are **always** false positives in this project — a clean `xcodebuild` produces zero errors. Do not act on SourceKit diagnostics without verifying with a real build.

## Web Port

A complete TypeScript/PixiJS port lives at https://github.com/luciavmf/invasiones-web. It mirrors this codebase 1-to-1 with these differences:

- Rendering: PixiJS v8 instead of SpriteKit. `Video` wraps a `PIXI.Container` canvas rebuilt each frame.
- Coordinate origin: top-left (Y down), matching C#/SDL — no Y-flip needed unlike SpriteKit.
- Same data files: `data/res.json` and `data/strings_*.json`.
- All loading is async (`fetch` + `DOMParser` / `PIXI.Assets`).
- No `Log`, `GameError`, `Utils`, `AppDelegate`, `ViewController`, or `GameScene` — browser equivalents used directly.
- `erasableSyntaxOnly` TypeScript config: no `enum`, uses `const` objects + type aliases.
- Episode loading uses an `asyncBusy` guard because `update()` is fire-and-forget in the PixiJS ticker.
- `Animation.clone()` creates an independent `Surface` (same GPU texture source, independent clip state) so cloned units don't share animation clip state.

## Data Files (`data/`)

| Path | Purpose |
|---|---|
| `res.json` | Resource manifest (all asset paths, sprite/animation definitions) |
| `strings_es.json` / `strings_en.json` / `strings_de.json` | Localised text strings and tips |
| `nivel/nivel_N.xml` | Level definitions (objectives, units, starting orders) |
| `unidades/*.csv` | Unit type stats and sprite name |
| `imagenes/` | PNG sprites and UI assets |
| `fuentes/` | TTF font files |
| `escenarios/` | Tiled maps (`.tmx`) and tilesets (`.tsx`) |
| `sonidos/` | Sound effects |
