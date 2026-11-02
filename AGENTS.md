# Invasiones Agent Guide

## Active Project

This repository is the macOS Swift/SpriteKit port of Invasiones.
Start with [`CLAUDE.md`](CLAUDE.md) for the game architecture, coding conventions, resource-loading rules, and porting notes. Those instructions apply regardless of which coding agent is used.

The original C# game lives in the separate repo [luciavmf/invasiones](https://github.com/luciavmf/invasiones), under `Juego/Invasiones/fuente/`. Treat it as the authoritative behavioral reference when porting or checking gameplay logic, but do not modify it unless the task explicitly targets the legacy Windows version.

## Build and Test

Run these commands from the repository root:

```sh
xcodebuild -scheme Invasiones -project Invasiones/Invasiones.xcodeproj build
xcodebuild -scheme Invasiones -project Invasiones/Invasiones.xcodeproj test
```

Use the smallest relevant test target while developing; run the appropriate build or test command before handoff. Do not trust SourceKit "Cannot find type … in scope" messages by themselves: confirm them with `xcodebuild` first.

## Working Conventions

- Write Swift code, comments, and identifiers in English, following the existing style.
- Preserve the Spanish names used by the XML data format. In particular, changing names such as `<unidad>` or `<animacion>` breaks resource loading without a compiler error.
- Keep gameplay changes aligned with the C# reference unless the task deliberately changes behavior.
- Prefer focused edits. Do not reformat unrelated Swift files or modify generated Xcode user data.
- Avoid editing binary assetsunless they are explicitly in scope.
- When adding source files, ensure they are included in the Xcode project or target as required by the current project structure.

## Repository Layout

- `Invasiones/`: Swift application and test targets.
- `Invasiones/data/`: port resources, maps, strings, and asset metadata.
- `ci/`: export options for the signed CI build.

## Handoff

Before reporting a task complete, inspect the diff, state which validation command ran and its result, and call out anything that could not be verified locally.
